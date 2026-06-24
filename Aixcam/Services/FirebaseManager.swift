import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

enum FirebaseManager {
    static var isConfigured: Bool {
        #if canImport(FirebaseCore)
        return Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil
        #else
        return false
        #endif
    }

    static func configure() {
        #if canImport(FirebaseCore)
        guard isConfigured else { return }
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }
}

enum ServiceError: LocalizedError {
    case notAuthenticated
    case profileNotFound
    case uploadFailed(String)
    case saveFailed(String)
    case networkUnavailable
    case invalidData

    var errorDescription: String? {
        switch self {
        case .notAuthenticated: "You must be signed in to continue."
        case .profileNotFound: "Creator profile not found."
        case .uploadFailed(let detail): "Upload failed: \(detail)"
        case .saveFailed(let detail): "Save failed: \(detail)"
        case .networkUnavailable: "Network unavailable. Changes saved locally."
        case .invalidData: "Invalid data provided."
        }
    }
}
