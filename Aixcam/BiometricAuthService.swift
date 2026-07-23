import Foundation
import LocalAuthentication

protocol BiometricAuthenticating {
    var biometryDisplayName: String { get }
    var canUseBiometrics: Bool { get }
    func authenticate(reason: String) async throws
}

enum BiometricAuthError: LocalizedError, Equatable {
    case unavailable
    case failed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "Biometrics are unavailable on this device."
        case .failed(let message):
            return message
        case .cancelled:
            return "Authentication was cancelled."
        }
    }
}

final class BiometricAuthService: BiometricAuthenticating {
    private let contextFactory: () -> LAContext

    init(contextFactory: @escaping () -> LAContext = { LAContext() }) {
        self.contextFactory = contextFactory
    }

    var biometryDisplayName: String {
        let context = contextFactory()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return "Biometrics"
        }
        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        case .opticID:
            return "Optic ID"
        @unknown default:
            return "Biometrics"
        }
    }

    var canUseBiometrics: Bool {
        let context = contextFactory()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    func authenticate(reason: String) async throws {
        let context = contextFactory()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            throw BiometricAuthError.unavailable
        }

        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: reason
            )
            if success == false {
                throw BiometricAuthError.failed("Biometric authentication failed.")
            }
        } catch let authError as BiometricAuthError {
            throw authError
        } catch let laError as LAError {
            switch laError.code {
            case .userCancel, .appCancel, .systemCancel:
                throw BiometricAuthError.cancelled
            default:
                throw BiometricAuthError.failed(laError.localizedDescription)
            }
        } catch {
            throw BiometricAuthError.failed(error.localizedDescription)
        }
    }
}

/// Test double that never touches LocalAuthentication.
final class StubBiometricAuthService: BiometricAuthenticating {
    var biometryDisplayName: String
    var canUseBiometrics: Bool
    var shouldSucceed: Bool
    var authenticateCallCount = 0

    init(
        biometryDisplayName: String = "Face ID",
        canUseBiometrics: Bool = true,
        shouldSucceed: Bool = true
    ) {
        self.biometryDisplayName = biometryDisplayName
        self.canUseBiometrics = canUseBiometrics
        self.shouldSucceed = shouldSucceed
    }

    func authenticate(reason: String) async throws {
        authenticateCallCount += 1
        if shouldSucceed {
            return
        }
        throw BiometricAuthError.failed("Stub biometric failure")
    }
}
