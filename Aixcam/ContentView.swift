import SwiftUI

enum AuthRoute: Equatable {
    case home
    case signup
    case login
    case privacy
}

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @State private var route: AuthRoute = .home

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradient()

                ScrollView {
                    VStack(spacing: 28) {
                        HeaderView(route: $route, currentMember: authViewModel.currentMember)

                        if route == .privacy {
                            PrivacyDetailsView(route: $route)
                        } else if let currentMember = authViewModel.currentMember {
                            CreatorOnboardingView(member: currentMember)
                        } else {
                            switch route {
                            case .home:
                                LandingView(route: $route)
                            case .signup:
                                SignUpView(route: $route)
                            case .login:
                                LoginView(route: $route)
                            case .privacy:
                                EmptyView()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .onChange(of: route) {
                authViewModel.resetStatus()
            }
        }
    }
}

private struct HeaderView: View {
    @Binding var route: AuthRoute
    let currentMember: Member?

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
            .accessibilityHint("Returns to the Aixcam welcome screen.")

            Spacer()

            Button("Privacy") {
                route = .privacy
            }
            .buttonStyle(.bordered)
            .accessibilityHint("Shows how Aixcam stores prototype account data.")

            if currentMember == nil {
                Button("Login") {
                    route = .login
                }
                .buttonStyle(.bordered)
                .accessibilityHint("Opens the login form.")

                Button("Join") {
                    route = .signup
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .accessibilityHint("Opens the account creation form.")
            }
        }
    }
}

private struct LandingView: View {
    @Binding var route: AuthRoute

    var body: some View {
        VStack(alignment: .leading, spacing: 26) {
            VStack(alignment: .leading, spacing: 16) {
                PillText("Prototype member access")

                Text("A safer local account flow for Aixcam.")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.72)
                    .lineSpacing(-4)

                Text("Create a prototype member profile, sign in with the password you chose, and manage the local account stored on this device.")
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
                .accessibilityHint("Starts local Aixcam account creation.")

                Button {
                    route = .login
                } label: {
                    Label("I already have an account", systemImage: "person.crop.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityHint("Opens login for an existing local account.")
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
            subtitle: "Create a local prototype account protected with a password hash in the iOS Keychain."
        ) {
            TextField("Full name", text: $name)
                .textContentType(.name)
                .autocorrectionDisabled()
                .submitLabel(.next)

            TextField("Email address", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)

            Picker("Joining as", selection: $accountType) {
                ForEach(AccountType.allCases) { type in
                    Text(type.rawValue).tag(type)
                }
            }

            SecureField("Password", text: $password)
                .textContentType(.newPassword)
                .submitLabel(.done)

            Text("Aixcam stores your name, email, account type, and password hash in Keychain on this device. You can delete the account after signing in.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Privacy note. Aixcam stores your name, email, account type, and password hash in Keychain on this device. You can delete the account after signing in.")

            StatusBanner(status: authViewModel.status)

            Button {
                if authViewModel.signUp(
                    name: name,
                    email: email,
                    accountType: accountType,
                    password: password
                ) {
                    name = ""
                    email = ""
                    password = ""
                    accountType = .creator
                }
            } label: {
                Text("Create account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)
            .accessibilityHint("Creates a local account and signs you in.")

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
            subtitle: "Log in to your local prototype account with the password used at sign-up."
        ) {
            TextField("Email address", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)

            SecureField("Password", text: $password)
                .textContentType(.password)
                .submitLabel(.done)

            StatusBanner(status: authViewModel.status)

            Button {
                if authViewModel.login(email: email, password: password) {
                    email = ""
                    password = ""
                }
            } label: {
                Text("Log in")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)
            .accessibilityHint("Checks your password and opens the signed-in account view.")

            Button("New to Aixcam? Create an account") {
                route = .signup
            }
            .buttonStyle(.plain)
            .foregroundStyle(.teal)
        }
    }
}

private struct DashboardView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    let member: Member
    @Binding var route: AuthRoute

    var body: some View {
        AuthCard(
            title: "Signed in as \(member.name).",
            subtitle: "This prototype account is stored locally on this device."
        ) {
            VStack(alignment: .leading, spacing: 10) {
                DetailRow(label: "Email", value: member.email)
                DetailRow(label: "Account type", value: member.accountType.rawValue)
                DetailRow(label: "Created", value: member.createdAt.formatted(date: .abbreviated, time: .omitted))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            StatusBanner(status: authViewModel.status)

            Button {
                route = .privacy
            } label: {
                Label("View privacy details", systemImage: "lock.shield")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityHint("Explains local Keychain storage and account deletion.")

            Button {
                authViewModel.logout()
            } label: {
                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityHint("Ends the current Aixcam session.")

            Button(role: .destructive) {
                authViewModel.deleteCurrentAccount()
                route = .home
            } label: {
                Label("Delete account from this device", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .accessibilityHint("Deletes your local Aixcam account and saved credentials from Keychain.")
        }
    }
}

private struct PrivacyDetailsView: View {
    @Binding var route: AuthRoute

    var body: some View {
        AuthCard(
            title: "Privacy and account control.",
            subtitle: "Aixcam's current prototype keeps account data local to this device."
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Stores name, email, account type, and a salted password hash in Keychain.", systemImage: "key.fill")
                Label("Uses the account only to demonstrate local sign-up and login.", systemImage: "person.crop.circle.badge.checkmark")
                Label("Provides in-app account deletion after sign-in.", systemImage: "trash.fill")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)

            Button("Back to welcome") {
                route = .home
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)
            .accessibilityHint("Returns to the Aixcam welcome screen.")
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            Spacer()
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
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
                    .font(.largeTitle.weight(.black))
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

            Text("Start with safer prototype onboarding before adding production creator, membership, and fan engagement features.")
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            HStack(spacing: 10) {
                MetricView(value: "Keychain", label: "Local storage")
                MetricView(value: "Hash", label: "Password check")
                MetricView(value: "Delete", label: "Account control")
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
                .accessibilityLabel("Success. \(message)")
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .accessibilityLabel("Error. \(message)")
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

private struct BackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(red: 0.03, green: 0.04, blue: 0.08),
                Color(red: 0.05, green: 0.09, blue: 0.18),
                Color(red: 0.12, green: 0.09, blue: 0.22)
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

#Preview {
    ContentView()
        .environmentObject(AuthViewModel())
}
