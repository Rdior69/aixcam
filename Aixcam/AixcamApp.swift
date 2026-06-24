import SwiftUI

@main
struct AixcamApp: App {
    @StateObject private var authViewModel = AuthViewModel()

    init() {
        FirebaseManager.configure()
    }

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environmentObject(authViewModel)
                .preferredColorScheme(nil)
        }
    }
}
