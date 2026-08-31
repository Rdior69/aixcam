import FirebaseAuth
import SwiftUI

struct ContentView: View {
    @Environment(AppRouter.self) private var appRouter
    @State private var profileService = ViewerProfileService()
    @State private var verificationService = IdentityVerificationService()

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
        .environment(verificationService)
        // Reload on every auth transition: signing out and back in as someone
        // else must not leave the previous person's profile or verification
        // status on screen.
        .task(id: appRouter.currentUser?.uid) {
            guard appRouter.isAuthenticated else {
                verificationService.reset()
                return
            }
            await profileService.load()
            await verificationService.refresh()
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
        } else if profileService.loadFailed {
            profileLoadFailure
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

    private var profileLoadFailure: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 16) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .accessibilityHidden(true)

                Text("Couldn't load your profile")
                    .font(.headline)
                    .foregroundStyle(.white)

                Text("Check your connection and try again.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))

                Button("Retry") {
                    Task { await profileService.load() }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Color.white, in: Capsule())
                .padding(.top, 8)

                Button("Sign Out") {
                    appRouter.signOut()
                }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.5))
            }
            .padding(.horizontal, 40)
        }
    }
}

#Preview {
    ContentView()
        .environment(AppRouter())
}
