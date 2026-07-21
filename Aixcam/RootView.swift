import SwiftUI

struct RootView: View {
    @EnvironmentObject private var sessionManager: SessionManager
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        ZStack {
            BackgroundCanvas()

            switch sessionManager.rootRoute {
            case .launching:
                LaunchScreenView()
                    .transition(.opacity)

            case .unauthenticated:
                UnauthenticatedRootView()
                    .transition(.opacity)

            case .creatorHome, .creatorNeedsOnboarding:
                if let user = authViewModel.currentUser {
                    CreatorAuthenticatedRoot(
                        user: user,
                        needsSetup: sessionManager.rootRoute == .creatorNeedsOnboarding
                    )
                    .transition(.opacity)
                } else {
                    LaunchScreenView()
                }

            case .subscriberHome, .subscriberNeedsOnboarding:
                if let user = authViewModel.currentUser {
                    SubscriberHomeView(
                        user: user,
                        needsOnboarding: sessionManager.rootRoute == .subscriberNeedsOnboarding,
                        onSignOut: { authViewModel.signOut() }
                    )
                    .transition(.opacity)
                } else {
                    LaunchScreenView()
                }

            case .accountBlocked(let status):
                if let user = authViewModel.currentUser {
                    AccountStatusView(
                        user: user,
                        status: status,
                        onSignOut: { authViewModel.signOut() }
                    )
                    .transition(.opacity)
                } else {
                    LaunchScreenView()
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: sessionManager.rootRoute)
        .task {
            await sessionManager.bootstrap()
        }
    }
}

/// Shared atmospheric background used by root routes.
struct BackgroundCanvas: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.03, green: 0.04, blue: 0.08),
                    Color(red: 0.05, green: 0.09, blue: 0.18),
                    Color(red: 0.12, green: 0.09, blue: 0.22)
                ]
                : [
                    Color(red: 0.93, green: 0.96, blue: 1.0),
                    Color(red: 0.89, green: 0.94, blue: 0.99),
                    Color(red: 0.95, green: 0.9, blue: 0.98)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .topLeading) {
            Circle()
                .fill(.teal.opacity(0.28))
                .frame(width: 280, height: 280)
                .blur(radius: 80)
                .offset(x: -110, y: -100)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(.purple.opacity(0.22))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 130, y: 20)
        }
        .ignoresSafeArea()
    }
}
