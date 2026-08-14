import AVFoundation
import Foundation
import Observation

@Observable
final class CameraManager {
    enum CameraPosition {
        case front
        case back

        var avPosition: AVCaptureDevice.Position {
            switch self {
            case .front:
                return .front
            case .back:
                return .back
            }
        }

        mutating func toggle() {
            self = self == .front ? .back : .front
        }
    }

    private(set) var isSessionRunning = false
    private(set) var isMuted = false
    private(set) var currentPosition: CameraPosition = .front
    private(set) var zoomFactor: CGFloat = 1.0
    private(set) var maxZoomFactor: CGFloat = 1.0
    private(set) var errorMessage: String?

    @ObservationIgnored let session = AVCaptureSession()

    @ObservationIgnored private let sessionQueue = DispatchQueue(label: "com.aixcam.camera.session", qos: .userInitiated)
    @ObservationIgnored private var videoInput: AVCaptureDeviceInput?
    @ObservationIgnored private var audioInput: AVCaptureDeviceInput?
    @ObservationIgnored private var isConfigured = false

    func clearError() {
        errorMessage = nil
    }

    func configureIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                try self.configureSessionIfNeededOnQueue(preferredPosition: .front)
            } catch {
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func startSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                try self.configureSessionIfNeededOnQueue(preferredPosition: .front)
            } catch {
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
                return
            }

            guard !self.session.isRunning else { return }

            self.session.startRunning()
            Task { @MainActor in
                self.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }

            self.session.stopRunning()
            Task { @MainActor in
                self.isSessionRunning = false
            }
        }
    }

    func flipCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            do {
                try self.configureSessionIfNeededOnQueue(preferredPosition: .front)
            } catch {
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
                return
            }

            let current = self.videoInput?.device.position == .back ? CameraPosition.back : CameraPosition.front
            var nextPosition = current
            nextPosition.toggle()

            self.session.beginConfiguration()
            do {
                try self.configureVideoInput(position: nextPosition)
                self.session.commitConfiguration()

                let updatedPosition = nextPosition
                Task { @MainActor in
                    self.currentPosition = updatedPosition
                }
            } catch {
                self.session.commitConfiguration()
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func toggleMute() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            let shouldMute = self.audioInput != nil

            if shouldMute {
                if let audioInput = self.audioInput {
                    self.session.beginConfiguration()
                    self.session.removeInput(audioInput)
                    self.session.commitConfiguration()
                    self.audioInput = nil
                }
            } else {
                do {
                    self.session.beginConfiguration()
                    try self.configureAudioInput()
                    self.session.commitConfiguration()
                } catch {
                    self.session.commitConfiguration()
                    Task { @MainActor in
                        self.errorMessage = error.localizedDescription
                    }
                    return
                }
            }

            Task { @MainActor in
                self.isMuted = shouldMute
            }
        }
    }

    func setZoomFactor(_ requestedValue: CGFloat) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.videoInput?.device else { return }

            do {
                try device.lockForConfiguration()
                let minZoom = device.minAvailableVideoZoomFactor
                let maxZoom = min(device.maxAvailableVideoZoomFactor, 6.0)
                let safeZoom = min(max(requestedValue, minZoom), maxZoom)
                device.videoZoomFactor = safeZoom
                device.unlockForConfiguration()

                Task { @MainActor in
                    self.zoomFactor = safeZoom
                    self.maxZoomFactor = maxZoom
                }
            } catch {
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    func focus(at devicePoint: CGPoint) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard let device = self.videoInput?.device else { return }

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
            } catch {
                Task { @MainActor in
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func configureSessionIfNeededOnQueue(preferredPosition: CameraPosition) throws {
        guard !isConfigured else { return }

        session.beginConfiguration()
        session.sessionPreset = .high

        do {
            try configureVideoInput(position: preferredPosition)
            try configureAudioInput()
            session.commitConfiguration()
            isConfigured = true

            Task { @MainActor in
                self.currentPosition = preferredPosition
                self.isMuted = false
                self.zoomFactor = 1.0
                self.maxZoomFactor = min(self.videoInput?.device.maxAvailableVideoZoomFactor ?? 1.0, 6.0)
            }
        } catch {
            session.commitConfiguration()
            throw error
        }
    }

    private func configureVideoInput(position: CameraPosition) throws {
        if let existingVideoInput = videoInput {
            session.removeInput(existingVideoInput)
            videoInput = nil
        }

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position.avPosition) else {
            throw CameraError.cameraUnavailable(position: position)
        }

        let newVideoInput = try AVCaptureDeviceInput(device: device)

        guard session.canAddInput(newVideoInput) else {
            throw CameraError.cannotAddVideoInput
        }

        session.addInput(newVideoInput)
        videoInput = newVideoInput

        let maxZoom = min(device.maxAvailableVideoZoomFactor, 6.0)
        Task { @MainActor in
            self.zoomFactor = 1.0
            self.maxZoomFactor = maxZoom
        }
    }

    private func configureAudioInput() throws {
        if let existingAudioInput = audioInput {
            session.removeInput(existingAudioInput)
            audioInput = nil
        }

        guard let microphone = AVCaptureDevice.default(for: .audio) else {
            throw CameraError.microphoneUnavailable
        }

        let newAudioInput = try AVCaptureDeviceInput(device: microphone)

        guard session.canAddInput(newAudioInput) else {
            throw CameraError.cannotAddAudioInput
        }

        session.addInput(newAudioInput)
        audioInput = newAudioInput
    }
}

enum CameraError: LocalizedError {
    case cameraUnavailable(position: CameraManager.CameraPosition)
    case microphoneUnavailable
    case cannotAddVideoInput
    case cannotAddAudioInput

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable(let position):
            switch position {
            case .front:
                return "Front camera is unavailable on this device."
            case .back:
                return "Back camera is unavailable on this device."
            }
        case .microphoneUnavailable:
            return "Microphone is unavailable on this device."
        case .cannotAddVideoInput:
            return "Could not configure the camera input."
        case .cannotAddAudioInput:
            return "Could not configure the microphone input."
        }
    }
}
