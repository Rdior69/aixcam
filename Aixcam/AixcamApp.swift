import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct AixcamApp: App {
    @StateObject private var sessionManager: SessionManager

    init() {
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
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
