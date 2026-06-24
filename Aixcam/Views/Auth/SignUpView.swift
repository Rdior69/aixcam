import SwiftUI

struct SignUpView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var route: AuthRoute
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var accountType = AccountType.creator

    var body: some View {
        AuthCard(
            title: "Create your Aixcam account.",
            subtitle: "Sign up to unlock livestreams, fan subscriptions, creator tools, virtual gifting, premium drops, and AI-powered experiences."
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
                authViewModel.signUp(
                    name: name,
                    email: email,
                    accountType: accountType,
                    password: password
                )
            } label: {
                Text("Create account")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DesignTokens.Colors.accent)

            Button("Already signed up? Login") {
                route = .login
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignTokens.Colors.accent)
        }
    }
}

struct LoginView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @Binding var route: AuthRoute
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        AuthCard(
            title: "Welcome back to Aixcam.",
            subtitle: "Log in to manage livestreams, subscriptions, virtual gifts, premium content, fan messaging, and creator growth tools."
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
                Text("Log in")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(DesignTokens.Colors.accent)

            Button("New to Aixcam? Create an account") {
                route = .signup
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignTokens.Colors.accent)
        }
    }
}
