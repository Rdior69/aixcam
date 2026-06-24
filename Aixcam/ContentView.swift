import SwiftUI

enum AuthRoute: Equatable {
    case home
    case signup
    case login
}

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var route: AuthRoute = .home
    @State private var creatorSetupViewModel: CreatorSetupViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradient()
                if let user = authViewModel.currentUser {
                    authenticatedRoot(user: user)
                } else {
                    ScrollView {
                        VStack(spacing: 28) {
                            HeaderView(route: $route)

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
            }
            .navigationBarHidden(true)
            .onChange(of: route) {
                authViewModel.resetStatus()
            }
            .onChange(of: authViewModel.currentUser?.id) { _, _ in
                configureCreatorSetupViewModel()
            }
            .task {
                configureCreatorSetupViewModel()
            }
        }
    }

    @ViewBuilder
    private func authenticatedRoot(user: AppUser) -> some View {
        if user.accountType == .creator {
            if authViewModel.shouldShowCreatorOnboarding, let creatorSetupViewModel {
                CreatorSetupWizardView(viewModel: creatorSetupViewModel) {
                    authViewModel.markCreatorOnboardingPublished()
                }
                .frame(maxWidth: 760)
            } else {
                CreatorDashboardHomeView(user: user) {
                    authViewModel.signOut()
                    route = .home
                }
                .frame(maxWidth: 760)
            }
        } else {
            NonCreatorAccountView(user: user) {
                authViewModel.signOut()
                route = .home
            }
            .frame(maxWidth: 760)
        }
    }

    private func configureCreatorSetupViewModel() {
        guard let user = authViewModel.currentUser, user.accountType == .creator else {
            creatorSetupViewModel = nil
            return
        }
        if creatorSetupViewModel?.user.id != user.id {
            creatorSetupViewModel = CreatorSetupViewModel(user: user)
        }
    }
}

private struct HeaderView: View {
    @Binding var route: AuthRoute

    var body: some View {
        HStack(spacing: 12) {
            Button {
                route = .home
            } label: {
                HStack(spacing: 12) {
                    AixcamIconView(size: 48)
                    Text("AIXLive")
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
            .tint(.teal)
        }
    }
}

private struct LandingView: View {
    @Binding var route: AuthRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 16) {
                PillText("Livestream. Monetize. Grow.")

                Text("Your creator business, built for fans from day one.")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.72)
                    .lineSpacing(-4)

                Text("Launch premium livestreams, memberships, AI studio workflows, and paid fan experiences from one polished AIXLive workspace.")
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
                .tint(.teal)

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

private struct SignUpView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var route: AuthRoute
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var accountType = AccountType.creator

    var body: some View {
        AuthCard(
            title: "Create your AIXLive account.",
            subtitle: "Sign up to unlock creator onboarding, fan subscriptions, premium content, and AI-powered production tools."
        ) {
            TextField("Full name", text: $name)
                .textContentType(.name)
                .autocorrectionDisabled()

            TextField("Email address", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            Picker("Joining as", selection: $accountType) {
                ForEach(AccountType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            SecureField("Password", text: $password)
                .textContentType(.newPassword)

            StatusBanner(status: authViewModel.status)

            Button {
                authViewModel.signUp(name: name, email: email, accountType: accountType, password: password)
            } label: {
                if authViewModel.isBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Create account")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)
            .disabled(authViewModel.isBusy)

            Button("Already signed up? Login") {
                route = .login
            }
            .buttonStyle(.plain)
            .foregroundStyle(.teal)
        }
    }
}

private struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var route: AuthRoute
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        AuthCard(
            title: "Welcome back to AIXLive.",
            subtitle: "Log in to continue your creator setup, media workflow, fan subscriptions, and growth analytics."
        ) {
            TextField("Email address", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            SecureField("Password", text: $password)
                .textContentType(.password)

            StatusBanner(status: authViewModel.status)

            Button {
                authViewModel.login(email: email, password: password)
            } label: {
                if authViewModel.isBusy {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Log in")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)
            .disabled(authViewModel.isBusy)

            Button("New to AIXLive? Create an account") {
                route = .signup
            }
            .buttonStyle(.plain)
            .foregroundStyle(.teal)
        }
    }
}

private struct AuthCard<Content: View>: View {
    let title: String
    let subtitle: String
    private let content: Content

    init(title: String, subtitle: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            AixcamIconView(size: 76)

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.largeTitle.weight(.heavy))
                    .minimumScaleFactor(0.82)

                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
            }

            VStack(spacing: 16) {
                content
            }
            .textFieldStyle(.roundedBorder)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
    }
}

private struct FeatureCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            AixcamIconView(size: 128)

            Text("Designed for high-touch fan communities.")
                .font(.title2.weight(.bold))

            Text("Bring onboarding, profile design, media publishing, and premium fan engagement together in one mobile-first experience.")
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            HStack(spacing: 10) {
                MetricView(value: "24/7", label: "Creator access")
                MetricView(value: "1:1", label: "Fan moments")
                MetricView(value: "AI", label: "Assisted growth")
            }
        }
        .padding(22)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct MetricView: View {
    let value: String
    let label: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.headline.weight(.black))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct StatusBanner: View {
    let status: AuthStatus

    var body: some View {
        switch status {
        case .idle:
            EmptyView()
        case .success(let message):
            Label(message, systemImage: "checkmark.circle.fill")
                .font(.subheadline)
                .foregroundStyle(.green)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct AixcamIconView: View {
    let size: CGFloat

    var body: some View {
        Image("AixcamIcon")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .padding(size * 0.08)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
            .shadow(color: .black.opacity(0.25), radius: size * 0.12, x: 0, y: size * 0.08)
            .accessibilityLabel("AIXLive app icon")
    }
}

private struct PillText: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.caption.weight(.black))
            .tracking(1.2)
            .foregroundStyle(.teal)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.teal.opacity(0.14), in: Capsule())
            .overlay {
                Capsule()
                    .stroke(.teal.opacity(0.35), lineWidth: 1)
            }
    }
}

private struct BackgroundGradient: View {
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
                .fill(.purple.opacity(0.28))
                .frame(width: 300, height: 300)
                .blur(radius: 90)
                .offset(x: 130, y: 20)
        }
        .ignoresSafeArea()
    }
}

private struct NonCreatorAccountView: View {
    let user: AppUser
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            Text("Welcome, \(user.name)")
                .font(.title2.weight(.bold))
            Text("This account is set as \(user.accountType.rawValue). Creator setup wizard opens automatically for creator accounts.")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Sign out", action: onSignOut)
                .buttonStyle(.bordered)
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(20)
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
