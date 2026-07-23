import SwiftUI

@main
struct AixcamApp: App {
    @StateObject private var sessionManager: SessionManager

    init() {
        // Only configures Firebase when GoogleService-Info.plist is in the bundle.
        // Otherwise the app stays on the local Keychain-backed backend.
        _ = FirebaseBootstrap.configureIfPossible()
        let authViewModel = AuthViewModel(restoreSessionOnInit: false)
        _sessionManager = StateObject(wrappedValue: SessionManager(authViewModel: authViewModel))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionManager)
                .environmentObject(sessionManager.authViewModel)
        }
    }
}
