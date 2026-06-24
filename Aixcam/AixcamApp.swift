import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct AixcamApp: App {
    @StateObject private var authViewModel: AuthViewModel

    init() {
#if canImport(FirebaseCore)
        FirebaseApp.configure()
#endif
        _authViewModel = StateObject(wrappedValue: AuthViewModel())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}
