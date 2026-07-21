import SwiftUI

struct ContentView: View {
    var body: some View {
        UnauthenticatedRootView()
    }
}

struct UnauthenticatedRootView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var route: AuthRoute = .home

    var body: some View {
        NavigationStack {
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
            .navigationBarHidden(true)
            .onChange(of: route) {
                authViewModel.resetStatus()
            }
        }
    }
}

struct CreatorAuthenticatedRoot: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    let user: AppUser
    let needsSetup: Bool

    @State private var creatorSetupViewModel: CreatorSetupViewModel?
    @State private var showCreatorSetup = false
    @State private var authRoute: AuthRoute = .home

    var body: some View {
        CreatorHomeView(
            user: user,
            needsSetup: needsSetup,
            onEditSetup: {
                configureCreatorSetupViewModel(forceReload: true)
                showCreatorSetup = true
            },
            onSignOut: {
                showCreatorSetup = false
                authViewModel.signOut()
                authRoute = .home
            }
        )
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
        .fullScreenCover(isPresented: $showCreatorSetup) {
            NavigationStack {
                if let creatorSetupViewModel {
                    CreatorSetupWizardView(
                        viewModel: creatorSetupViewModel,
                        onPublished: {
                            authViewModel.markCreatorOnboardingPublished()
                            showCreatorSetup = false
                        },
                        onOpenCreatorHome: {
                            showCreatorSetup = false
                        },
                        onSignOut: {
                            showCreatorSetup = false
                            authViewModel.signOut()
                            authRoute = .home
                        }
                    )
                } else {
                    VStack(spacing: 16) {
                        ProgressView("Loading setup…")
                        Button("Back to Creator Home") {
                            showCreatorSetup = false
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.teal)
                    }
                    .task {
                        configureCreatorSetupViewModel(forceReload: true)
                    }
                }
            }
            .interactiveDismissDisabled(false)
        }
        .onChange(of: user.id) { _, _ in
            showCreatorSetup = false
            configureCreatorSetupViewModel(forceReload: true)
        }
        .task {
            configureCreatorSetupViewModel()
        }
    }

    private func configureCreatorSetupViewModel(forceReload: Bool = false) {
        guard user.accountType == .creator else {
            creatorSetupViewModel = nil
            return
        }
        if forceReload || creatorSetupViewModel?.user.id != user.id {
            creatorSetupViewModel = CreatorSetupViewModel(user: user)
        }
    }
}

enum AuthRoute: Equatable {
    case home
    case signup
    case login
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

                Text("Launch premium livestreams, memberships, AI studio workflows, and paid fan experiences from one polished Aixcam workspace.")
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
            title: "Create your Aixcam account.",
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
            title: "Welcome back to Aixcam.",
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

            Button("New to Aixcam? Create an account") {
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
            .accessibilityLabel("Aixcam app icon")
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

#Preview {
    let auth = AuthViewModel(restoreSessionOnInit: false)
    let session = SessionManager(authViewModel: auth)
    return RootView()
        .environmentObject(session)
        .environmentObject(auth)
}
