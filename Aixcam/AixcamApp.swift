import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

@main
struct AixcamApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        #if canImport(FirebaseCore)
        if FirebaseApp.app() == nil {
            FirebaseApp.configure()
        }
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
        }
    }
}
