import AVFoundation
import HaishinKit
import Observation

// Defined outside CameraManager so Equatable synthesis is not actor-isolated.
enum CameraPosition: Equatable {
    case front
    case back

    var avPosition: AVCaptureDevice.Position {
        self == .front ? .front : .back
    }

    mutating func toggle() {
        self = self == .front ? .back : .front
    }

    var captureDevice: AVCaptureDevice? {
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: avPosition)
    }
}

/// Manages camera capture, encoding, and RTMP publishing via HaishinKit 2.x.
///
/// Architecture: MediaMixer owns the AVCaptureSession and routes frames to
/// both the MTHKView preview and the RTMPStream for publishing.
/// SessionBuilderFactory creates sessions; RTMPSessionFactory must be registered
/// at app startup (see AIxcamApp.init).
@Observable
@MainActor
final class CameraManager {

    // MARK: — Observable state

    private(set) var isSessionRunning = false
    private(set) var isMuted = false
    private(set) var currentPosition: CameraPosition = .back
    private(set) var zoomFactor: CGFloat = 1.0
    private(set) var maxZoomFactor: CGFloat = 1.01
    private(set) var isPublishing = false
    private(set) var errorMessage: String?

    // MARK: — HaishinKit 2.x

    @ObservationIgnored let mixer = MediaMixer()
    @ObservationIgnored private var session: (any Session)?
    @ObservationIgnored private var previewOutput: (any MediaMixerOutput)?
    @ObservationIgnored private var isMixerReady = false

    // MARK: — Init

    init() {}

    // MARK: — Session lifecycle

    func startSession() {
        Task { await startSessionAsync() }
    }

    private func startSessionAsync() async {
        // W-5: Configure AVAudioSession for live broadcast before attaching audio.
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .videoRecording,
                                         options: [.allowBluetoothHFP, .defaultToSpeaker])
            try audioSession.setActive(true)
        } catch {
            errorMessage = "Audio session setup failed: \(error.localizedDescription)"
        }

        guard let camera = currentPosition.captureDevice else {
            errorMessage = "Camera unavailable on this device."
            return
        }
        do {
            try await mixer.attachVideo(camera)
        } catch {
            errorMessage = error.localizedDescription
            return
        }
        try? await mixer.attachAudio(AVCaptureDevice.default(for: .audio))
        await mixer.startRunning()
        isSessionRunning = true
        isMuted = false
        zoomFactor = 1.0
        updateMaxZoom(for: camera)
        isMixerReady = true
        if let previewOutput {
            await mixer.addOutput(previewOutput)
        }
    }

    func stopSession() {
        Task { await stopSessionAsync() }
    }

    private func stopSessionAsync() async {
        await mixer.stopRunning()
        try? await mixer.attachVideo(nil)
        try? await mixer.attachAudio(nil)
        isSessionRunning = false
        isMixerReady = false
    }

    // MARK: — Camera controls

    func flipCamera() {
        currentPosition.toggle()
        guard let device = currentPosition.captureDevice else {
            currentPosition.toggle()
            errorMessage = "Camera unavailable for that position."
            return
        }
        Task {
            do {
                try await mixer.attachVideo(device)
            } catch {
                currentPosition.toggle()
                errorMessage = error.localizedDescription
            }
        }
        zoomFactor = 1.0
        updateMaxZoom(for: device)
    }

    func toggleMute() {
        isMuted = !isMuted
        Task {
            if isMuted {
                try? await mixer.attachAudio(nil)
            } else {
                try? await mixer.attachAudio(AVCaptureDevice.default(for: .audio))
            }
        }
    }

    func setZoomFactor(_ value: CGFloat) {
        guard let device = currentPosition.captureDevice else { return }
        // W-4: lockForConfiguration can block; offload to background then report back.
        // Inner Task.detached avoids capturing self across actor boundaries (Swift 6 safe).
        Task {
            let result: Result<CGFloat, Error> = await Task.detached {
                do {
                    try device.lockForConfiguration()
                    let minZ = device.minAvailableVideoZoomFactor
                    let maxZ = Swift.min(device.maxAvailableVideoZoomFactor, 6.0)
                    let safeZ = Swift.min(Swift.max(value, minZ), maxZ)
                    device.videoZoomFactor = safeZ
                    device.unlockForConfiguration()
                    return .success(safeZ)
                } catch {
                    return .failure(error)
                }
            }.value
            switch result {
            case .success(let safeZ): self.zoomFactor = safeZ
            case .failure(let error): self.errorMessage = error.localizedDescription
            }
        }
    }

    func focus(at devicePoint: CGPoint) {
        guard let device = currentPosition.captureDevice else { return }
        // W-4: lockForConfiguration can block; run off the main actor.
        Task.detached {
            do {
                try device.lockForConfiguration()
                if device.isFocusPointOfInterestSupported {
                    device.focusPointOfInterest = devicePoint
                    device.focusMode = .continuousAutoFocus
                }
                if device.isExposurePointOfInterestSupported {
                    device.exposurePointOfInterest = devicePoint
                    device.exposureMode = .continuousAutoExposure
                }
                device.unlockForConfiguration()
            } catch { }
        }
    }

    func clearError() {
        errorMessage = nil
    }

    // MARK: — RTMP publishing

    func startPublishing(ingestURL: String) async throws {
        guard !isPublishing else { throw StreamingError.broadcastAlreadyActive }
        guard let url = URL(string: ingestURL) else { throw StreamingError.insecureIngestURL }
        // O-5: Await RTMP factory registration to eliminate the app-init race.
        await AIxcamApp.rtmpRegistration.value
        guard let newSession = try await SessionBuilderFactory.shared
            .make(url)
            .setMode(.publish)
            .build() else {
            throw StreamingError.infrastructureNotPrepared
        }
        await mixer.addOutput(newSession.stream)
        do {
            try await newSession.connect { }
        } catch {
            // Connect failed: detach the stream output and tear down the session
            // so a retry doesn't double-attach an orphaned output to the mixer.
            await mixer.removeOutput(newSession.stream)
            try? await newSession.close()
            throw error
        }
        session = newSession
        isPublishing = true
    }

    func stopPublishing() async throws {
        guard let session else { return }
        try await session.close()
        await mixer.removeOutput(session.stream)
        self.session = nil
        isPublishing = false
    }

    // MARK: — Private helpers

    private func updateMaxZoom(for device: AVCaptureDevice) {
        let raw = Swift.min(device.maxAvailableVideoZoomFactor, 6.0)
        maxZoomFactor = raw > 1.0 ? raw : 1.01
    }
}

// MARK: — Preview source for MTHKViewRepresentable

extension CameraManager: MTHKViewRepresentable.PreviewSource {
    nonisolated func connect(to view: MTHKView) {
        Task { @MainActor in
            self.previewOutput = view
            if self.isMixerReady {
                await self.mixer.addOutput(view)
            }
        }
    }
}

// MARK: — Camera errors

enum CameraError: LocalizedError {
    case cameraUnavailable(position: CameraPosition)
    case microphoneUnavailable

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable(let position):
            switch position {
            case .front: return "Front camera is unavailable on this device."
            case .back:  return "Back camera is unavailable on this device."
            }
        case .microphoneUnavailable:
            return "Microphone is unavailable on this device."
        }
    }
}
