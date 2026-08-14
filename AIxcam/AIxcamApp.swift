import FirebaseCore
import SwiftUI

@main
struct AIxcamApp: App {
    @State private var appRouter: AppRouter = AppRouter()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appRouter)
        }
    }
}
