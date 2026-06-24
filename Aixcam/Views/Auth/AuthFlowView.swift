import SwiftUI

enum AuthRoute: Equatable {
    case home
    case signup
    case login
}

struct AuthFlowView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var route: AuthRoute = .home

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackgroundGradient()

                ScrollView {
                    VStack(spacing: 28) {
                        AuthHeaderView(route: $route)

                        switch route {
                        case .home:
                            LandingView(route: $route)
                        case .signup:
                            SignUpView(route: $route)
                        case .login:
                            LoginView(route: $route)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationBarHidden(true)
            .onChange(of: route) {
                authViewModel.resetStatus()
            }
        }
    }
}

private struct AuthHeaderView: View {
    @Binding var route: AuthRoute

    var body: some View {
        HStack(spacing: 12) {
            Button {
                route = .home
            } label: {
                HStack(spacing: 12) {
                    AixcamIconView(size: 48)
                    Text("Aixcam")
                        .font(.headline.weight(.bold))
                }
            }
            .buttonStyle(.plain)

            Spacer()

            Button("Login") {
                route = .login
            }
            .buttonStyle(.bordered)

            Button("Join") {
                route = .signup
            }
            .buttonStyle(.borderedProminent)
            .tint(DesignTokens.Colors.accent)
        }
    }
}

struct LandingView: View {
    @Binding var route: AuthRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 16) {
                PillText("Livestream. Monetize. Grow.")

                Text("Your creator business, built for fans from day one.")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.72)
                    .lineSpacing(-4)

                Text("Launch premium livestreams, memberships, virtual gifts, AI-powered fan experiences, and content drops from one polished Aixcam workspace.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .lineSpacing(4)
            }

            VStack(spacing: 12) {
                Button {
                    route = .signup
                } label: {
                    Label("Create your account", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(DesignTokens.Colors.accent)

                Button {
                    route = .login
                } label: {
                    Label("I already have an account", systemImage: "person.crop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            FeatureCard()
        }
    }
}

private struct FeatureCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AixcamIconView(size: 128)

            Text("Designed for high-touch fan communities.")
                .font(.title2.weight(.bold))

            Text("Bring onboarding, membership access, creator tools, and premium fan engagement together in a responsive mobile experience.")
                .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                .lineSpacing(3)

            HStack(spacing: 10) {
                MetricView(value: "24/7", label: "Creator access")
                MetricView(value: "1:1", label: "Fan moments")
                MetricView(value: "AI", label: "Assisted growth")
            }
        }
        .padding(22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusLarge, style: .continuous)
                .stroke(DesignTokens.Colors.glassStroke(for: colorScheme), lineWidth: 1)
        }
    }
}

private struct MetricView: View {
    @Environment(\.colorScheme) private var colorScheme
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.headline.weight(.black))
            Text(label)
                .font(.caption)
                .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(DesignTokens.Colors.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    AuthFlowView()
        .environmentObject(AuthViewModel())
}
