import SwiftUI

struct AppRootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                if authViewModel.needsCreatorSetup, let member = authViewModel.currentMember {
                    CreatorSetupWizardView(member: member)
                } else if authViewModel.currentMember?.accountType == .creator {
                    MainCreatorDashboardView()
                } else {
                    FanHomePlaceholderView()
                }
            } else {
                AuthFlowView()
            }
        }
        .animation(.easeInOut(duration: 0.35), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.35), value: authViewModel.needsCreatorSetup)
    }
}

private struct FanHomePlaceholderView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            AdaptiveBackgroundGradient()

            VStack(spacing: 24) {
                AixcamIconView(size: 96)

                Text("Welcome to Aixcam")
                    .font(.largeTitle.weight(.black))

                if let member = authViewModel.currentMember {
                    Text("Signed in as \(member.name) (\(member.accountType.rawValue))")
                        .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                }

                Button("Sign Out") {
                    authViewModel.logout()
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}
