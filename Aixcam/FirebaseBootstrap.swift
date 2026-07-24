import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

/// Detects whether Firebase can be activated safely, and configures it only when
/// a real `GoogleService-Info.plist` is present in the app bundle.
enum FirebaseBootstrap {
    /// True when the app bundle contains `GoogleService-Info.plist`.
    static func hasGoogleServiceInfoPlist(in bundle: Bundle = .main) -> Bool {
        bundle.path(forResource: "GoogleService-Info", ofType: "plist") != nil
    }

    /// Configures Firebase only when the plist is present. Never calls
    /// `FirebaseApp.configure()` without it (that would crash).
    @discardableResult
    static func configureIfPossible(bundle: Bundle = .main) -> Bool {
        guard hasGoogleServiceInfoPlist(in: bundle) else {
            return false
        }

        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        return FirebaseApp.app() != nil
        #else
        return false
        #endif
    }

    /// Runtime readiness used by `CreatorBackendFactory`.
    static var isReadyForFirebaseBackend: Bool {
        #if canImport(FirebaseCore)
        return hasGoogleServiceInfoPlist() && FirebaseApp.app() != nil
        #else
        return false
        #endif
    }

    /// Which backend the factory will select right now.
    static var activeBackendKind: CreatorBackendKind {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseStorage) && canImport(FirebaseFunctions) && canImport(FirebaseCore)
        if isReadyForFirebaseBackend {
            return .firebase
        }
        #endif
        return .local
    }
}

enum CreatorBackendKind: String, Equatable {
    case local
    case firebase
}

/// Maps Firebase Auth-style `NSError` codes without requiring the Firebase SDK
/// at compile time (used by tests and by the Firebase backend when linked).
enum FirebaseAuthErrorMapper {
    static let authErrorDomain = "FIRAuthErrorDomain"

    static func map(_ error: Error) -> CreatorBackendError? {
        let nsError = error as NSError
        guard nsError.domain == authErrorDomain else {
            return nil
        }

        switch nsError.code {
        case 17007: // emailAlreadyInUse
            return .duplicateEmail
        case 17008: // invalidEmail
            return .invalidInput("Enter a valid email address.")
        case 17009: // wrongPassword
            return .invalidCredentials
        case 17010: // tooManyRequests
            return .invalidInput("Too many attempts. Try again later.")
        case 17011: // userNotFound
            return .invalidCredentials
        case 17026: // weakPassword
            return .invalidInput("Use a password with at least 8 characters.")
        case 17020: // networkError
            return .invalidInput("Network error. Check your connection and try again.")
        default:
            return .unknown
        }
    }

    static func mapOrUnknown(_ error: Error) -> CreatorBackendError {
        map(error) ?? .unknown
    }
}
