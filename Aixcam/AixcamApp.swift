import SwiftUI

@main
struct AixcamApp: App {
    @StateObject private var sessionManager: SessionManager
    @StateObject private var appLock: AppLockController

    init() {
        // Only configures Firebase when GoogleService-Info.plist is in the bundle.
        // Otherwise the app stays on the local Keychain-backed backend.
        _ = FirebaseBootstrap.configureIfPossible()
        let authViewModel = AuthViewModel(restoreSessionOnInit: false)
        _sessionManager = StateObject(wrappedValue: SessionManager(authViewModel: authViewModel))
        _appLock = StateObject(wrappedValue: AppLockController())
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(sessionManager)
                .environmentObject(sessionManager.authViewModel)
                .environmentObject(appLock)
        }
    }
}
