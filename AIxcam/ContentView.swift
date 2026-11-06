import FirebaseAuth
import SwiftUI

struct ContentView: View {
    @Environment(AppRouter.self) private var appRouter
    @State private var profileService = ViewerProfileService()
    // Owned here so the StoreKit transaction listener starts once, at app
    // level, rather than being recreated each time a tip sheet is presented.
    @State private var paymentService = PaymentService()

    var body: some View {
        Group {
            if appRouter.isAuthenticated {
                authenticatedContent
            } else {
                NavigationStack {
                    OnboardingView()
                }
            }
        }
        .environment(profileService)
        .environment(paymentService)
        // The StoreKit listener has to be running before any purchase can
        // occur, and `PaymentService.init` deliberately does no work so it can
        // be constructed in a test. `start()` is idempotent.
        .task {
            paymentService.start()
        }
        // Reload on every auth transition: signing out and back in as someone
        // else must not leave the previous person's profile or verification
        // status on screen.
        .task(id: appRouter.currentUser?.uid) {
            guard appRouter.isAuthenticated else {
                profileService.reset()
                return
            }
            await profileService.load()
        }
    }

    /// Signed in, but the profile still gates entry to the app: a viewer with no
    /// display name or unconfirmed age can't be shown to creators, and the 18+
    /// check has to happen before any content is reachable.
    @ViewBuilder
    private var authenticatedContent: some View {
        if let profile = profileService.profile {
            if profile.isComplete {
                MainTabView()
            } else {
                NavigationStack {
                    ViewerProfileEditView(mode: .setup)
                }
                .preferredColorScheme(.dark)
            }
        } else if let failure = profileService.loadFailure {
            profileLoadFailure(failure)
        } else {
            loadingScreen
        }
    }

    private var loadingScreen: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ProgressView()
                .tint(.white)
        }
    }

    /// Reports why the profile didn't load. The reason is spelled out rather
    /// than assumed to be the network: a rules rejection can't be retried away,
    /// and sending someone to check their Wi-Fi over one wastes their time.
    private func profileLoadFailure(_ failure: ViewerProfileLoadFailure) -> some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: failure.systemImage)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .accessibilityHidden(true)

                Text(failure.message)
                    .font(.headline)
                    .foregroundStyle(.white)

                Text(failure.guidance)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)

                if failure.isRetryable {
                    Button("Retry") {
                        Task { await profileService.load() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.white, in: Capsule())
                    .padding(.top, 8)
                }

                Button("Sign Out") {
                    appRouter.signOut()
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
                .padding(.top, failure.isRetryable ? 0 : 8)
            }
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
}
