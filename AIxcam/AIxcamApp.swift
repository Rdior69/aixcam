import FirebaseAuth
import FirebaseCore
import HaishinKit
import RTMPHaishinKit
import SwiftUI

@main
struct AIxcamApp: App {
    @State private var appRouter: AppRouter = AppRouter()

    // Stored so CameraManager can await completion before building the first session,
    // eliminating the race between app init and the user tapping Go Live.
    static let rtmpRegistration: Task<Void, Never> = Task {
        await SessionBuilderFactory.shared.register(RTMPSessionFactory())
    }

    /// Launch argument that forces a signed-out start. UI tests need a
    /// deterministic first screen, and Firebase persists the session in the
    /// keychain — without this a run lands on the main tab view whenever the
    /// device happens to already be signed in.
    static let signedOutLaunchArgument = "-uitest-signed-out"

    init() {
        FirebaseApp.configure()

        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains(AIxcamApp.signedOutLaunchArgument) {
            try? Auth.auth().signOut()
        }
        #endif

        _ = AIxcamApp.rtmpRegistration
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(appRouter)
        }
    }
}
