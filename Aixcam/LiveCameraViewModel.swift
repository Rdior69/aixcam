import AVFoundation
import Combine
import Foundation

enum LiveCameraAuthorization: Equatable {
    case notDetermined
    case authorized
    case denied
    case restricted
}

enum LiveStudioPhase: Equatable {
    case idle
    case preparing
    case live
    case ended
}

@MainActor
final class LiveCameraViewModel: ObservableObject {
    @Published private(set) var authorization: LiveCameraAuthorization = .notDetermined
    @Published private(set) var phase: LiveStudioPhase = .idle
    @Published private(set) var isSessionRunning = false
    @Published private(set) var usingFrontCamera = true
    @Published private(set) var isMuted = false
    @Published private(set) var elapsedSeconds = 0
    @Published private(set) var simulatedViewers = 0
    @Published var statusMessage = ""
    @Published var errorMessage = ""

    let title: String
    let sessionController: LiveCameraSessionController

    private var timerTask: Task<Void, Never>?
    private var viewerTask: Task<Void, Never>?

    init(creatorDisplayName: String) {
        title = "\(creatorDisplayName)’s live"
        sessionController = LiveCameraSessionController()
        refreshAuthorization()
    }

    var canGoLive: Bool {
        authorization == .authorized && (phase == .idle || phase == .ended)
    }

    var elapsedLabel: String {
        let minutes = elapsedSeconds / 60
        let seconds = elapsedSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func refreshAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorization = .authorized
        case .denied:
            authorization = .denied
        case .restricted:
            authorization = .restricted
        case .notDetermined:
            authorization = .notDetermined
        @unknown default:
            authorization = .denied
        }
    }

    func requestAccessAndPrepare() async {
        errorMessage = ""
        refreshAuthorization()
        if authorization == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            _ = await AVCaptureDevice.requestAccess(for: .audio)
            authorization = granted ? .authorized : .denied
        }

        guard authorization == .authorized else {
            errorMessage = "Camera access is required to go live."
            return
        }

        phase = .preparing
        do {
            try sessionController.configure(preferFrontCamera: usingFrontCamera)
            sessionController.start()
            isSessionRunning = true
            statusMessage = "Camera ready. Tap Go Live when you’re set."
            phase = .idle
        } catch {
            errorMessage = error.localizedDescription
            phase = .idle
            isSessionRunning = false
        }
    }

    func goLive() {
        guard authorization == .authorized else {
            errorMessage = "Allow camera access before going live."
            return
        }
        errorMessage = ""
        if isSessionRunning == false {
            Task {
                await requestAccessAndPrepare()
                startLiveBroadcast()
            }
            return
        }
        startLiveBroadcast()
    }

    func endLive() {
        phase = .ended
        statusMessage = "Live ended. You can go live again anytime."
        stopTickers()
        sessionController.stop()
        isSessionRunning = false
    }

    func toggleMute() {
        isMuted.toggle()
        sessionController.setAudioEnabled(isMuted == false)
        statusMessage = isMuted ? "Mic muted." : "Mic on."
    }

    func flipCamera() {
        usingFrontCamera.toggle()
        do {
            try sessionController.switchCamera(preferFrontCamera: usingFrontCamera)
            statusMessage = usingFrontCamera ? "Front camera" : "Rear camera"
        } catch {
            errorMessage = error.localizedDescription
            usingFrontCamera.toggle()
        }
    }

    func closeStudio() {
        stopTickers()
        sessionController.stop()
        isSessionRunning = false
        phase = .idle
    }

    private func startLiveBroadcast() {
        phase = .live
        elapsedSeconds = 0
        simulatedViewers = Int.random(in: 3...18)
        statusMessage = "You’re live on Aixcam."
        startTickers()
    }

    private func startTickers() {
        stopTickers()
        timerTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    guard let self, self.phase == .live else { return }
                    self.elapsedSeconds += 1
                }
            }
        }
        viewerTask = Task { [weak self] in
            while Task.isCancelled == false {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run {
                    guard let self, self.phase == .live else { return }
                    let delta = Int.random(in: -2...5)
                    self.simulatedViewers = max(0, self.simulatedViewers + delta)
                }
            }
        }
    }

    private func stopTickers() {
        timerTask?.cancel()
        viewerTask?.cancel()
        timerTask = nil
        viewerTask = nil
    }
}

enum LiveCameraSessionError: LocalizedError {
    case cameraUnavailable
    case cannotAddInput
    case cannotAddOutput

    var errorDescription: String? {
        switch self {
        case .cameraUnavailable:
            return "No camera is available on this device."
        case .cannotAddInput:
            return "Could not connect the camera input."
        case .cannotAddOutput:
            return "Could not configure camera preview output."
        }
    }
}

final class LiveCameraSessionController: NSObject {
    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(label: "com.aixcam.live.session")
    private var videoInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private let photoOutput = AVCapturePhotoOutput()

    func configure(preferFrontCamera: Bool) throws {
        session.beginConfiguration()
        session.sessionPreset = .high

        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }

        guard let camera = Self.camera(preferFront: preferFrontCamera) else {
            session.commitConfiguration()
            throw LiveCameraSessionError.cameraUnavailable
        }

        let videoDeviceInput = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(videoDeviceInput) else {
            session.commitConfiguration()
            throw LiveCameraSessionError.cannotAddInput
        }
        session.addInput(videoDeviceInput)
        videoInput = videoDeviceInput

        if let microphone = AVCaptureDevice.default(for: .audio) {
            let audioDeviceInput = try AVCaptureDeviceInput(device: microphone)
            if session.canAddInput(audioDeviceInput) {
                session.addInput(audioDeviceInput)
                audioInput = audioDeviceInput
            }
        }

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
    }

    func start() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning == false else { return }
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    func setAudioEnabled(_ enabled: Bool) {
        sessionQueue.async { [weak self] in
            self?.audioInput?.ports.forEach { port in
                port.isEnabled = enabled
            }
        }
    }

    func switchCamera(preferFrontCamera: Bool) throws {
        guard let currentInput = videoInput else {
            try configure(preferFrontCamera: preferFrontCamera)
            return
        }

        session.beginConfiguration()
        session.removeInput(currentInput)

        guard let camera = Self.camera(preferFront: preferFrontCamera) else {
            session.addInput(currentInput)
            session.commitConfiguration()
            throw LiveCameraSessionError.cameraUnavailable
        }

        let newInput = try AVCaptureDeviceInput(device: camera)
        guard session.canAddInput(newInput) else {
            session.addInput(currentInput)
            session.commitConfiguration()
            throw LiveCameraSessionError.cannotAddInput
        }
        session.addInput(newInput)
        videoInput = newInput
        session.commitConfiguration()
    }

    private static func camera(preferFront: Bool) -> AVCaptureDevice? {
        let position: AVCaptureDevice.Position = preferFront ? .front : .back
        if let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            return device
        }
        return AVCaptureDevice.default(for: .video)
    }
}
