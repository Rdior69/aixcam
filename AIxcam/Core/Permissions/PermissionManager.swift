import AVFoundation
import AVFAudio
import Foundation

enum PermissionManager {
    static func requestCameraAndMicrophoneAccess() async -> Bool {
        let cameraGranted = await requestCameraAccessIfNeeded()
        let microphoneGranted = await requestMicrophoneAccessIfNeeded()
        return cameraGranted && microphoneGranted
    }

    static func hasCameraAndMicrophoneAccess() -> Bool {
        let cameraAuthorized = AVCaptureDevice.authorizationStatus(for: .video) == .authorized
        let microphoneAuthorized = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        return cameraAuthorized && microphoneAuthorized
    }

    private static func requestCameraAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        default:
            return false
        }
    }

    private static func requestMicrophoneAccessIfNeeded() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }
}
