import OSLog
import SwiftUI

struct SignUpView: View {
    @Environment(AppRouter.self) private var appRouter
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var error: AppError?

    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    private var emailLooksInvalid: Bool {
        !email.isEmpty && !AuthValidation.isValidEmail(email)
    }

    private var passwordStrength: AuthValidation.PasswordStrength {
        AuthValidation.strength(of: password)
    }

    /// Validated locally so people get a specific message before the round trip
    /// instead of Firebase's generic error string.
    private var canSubmit: Bool {
        AuthValidation.isValidEmail(email)
        && AuthValidation.isAcceptablePassword(password)
        && password == confirmPassword
        && !isLoading
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            atmosphereBlurs

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    header

                    VStack(spacing: 14) {
                        AuthTextField(
                            placeholder: "Email",
                            text: $email,
                            keyboardType: .emailAddress,
                            isSecure: false
                        )
                        .textContentType(.emailAddress)
                        .accessibilityLabel("Email address")

                        if emailLooksInvalid {
                            fieldHint("That doesn't look like a valid email address.", isError: true)
                        }

                        AuthTextField(
                            placeholder: "Password",
                            text: $password,
                            keyboardType: .default,
                            isSecure: true
                        )
                        .textContentType(.newPassword)
                        .accessibilityLabel("Password")

                        if !password.isEmpty {
                            passwordStrengthMeter
                        }

                        AuthTextField(
                            placeholder: "Confirm Password",
                            text: $confirmPassword,
                            keyboardType: .default,
                            isSecure: true
                        )
                        .textContentType(.newPassword)
                        .accessibilityLabel("Confirm password")
                        .overlay(alignment: .trailing) {
                            if passwordMismatch {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red.opacity(0.8))
                                    .padding(.trailing, 16)
                                    .accessibilityLabel("Passwords do not match")
                            }
                        }

                        if passwordMismatch {
                            fieldHint("Passwords don't match.", isError: true)
                        }
                    }

                    if let error {
                        ErrorBanner(error)
                    }

                    Button {
                        Task { await signUp() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            Text("Create Account")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                    .background(Color.white.opacity(canSubmit ? 1.0 : 0.4), in: Capsule())
                    .disabled(!canSubmit)
                    .animation(.easeOut(duration: 0.12), value: canSubmit)
                }
                .padding(.horizontal, 32)

                Spacer()

                Text("AIxcam is for adults \(ViewerProfile.minimumAge)+. By creating an account you confirm you are of age and agree to our Terms & Privacy Policy.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .topLeading) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.1), in: Circle())
            }
            .accessibilityLabel("Back")
            .padding(.top, 56)
            .padding(.leading, 20)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Create account")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)

            Text("Watch live, or go live yourself.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    /// Strength is advisory — anything past the length floor can be submitted.
    /// See `AuthValidation.isAcceptablePassword`.
    private var passwordStrengthMeter: some View {
        let strength = passwordStrength
        let colour: Color = switch strength {
        case .tooShort: .red.opacity(0.8)
        case .weak:     .orange
        case .fair:     .yellow
        case .strong:   .green
        }

        return VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(colour)
                        .frame(width: geometry.size.width * strength.fill)
                }
            }
            .frame(height: 4)
            .animation(.easeOut(duration: 0.2), value: strength)

            Text(strength == .tooShort
                 ? "At least \(AuthValidation.minimumPasswordLength) characters."
                 : "Password strength: \(strength.label)")
                .font(.caption2)
                .foregroundStyle(colour.opacity(0.9))
        }
        .padding(.horizontal, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Password strength: \(strength.label)")
    }

    private func fieldHint(_ text: String, isError: Bool) -> some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(isError ? .red.opacity(0.85) : .white.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }

    private var atmosphereBlurs: some View {
        ZStack {
            Circle()
                .fill(Color.pink.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 140, y: -260)

            Circle()
                .fill(Color.cyan.opacity(0.16))
                .frame(width: 280, height: 280)
                .blur(radius: 65)
                .offset(x: -140, y: 240)
        }
        .ignoresSafeArea()
    }

    private func signUp() async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await appRouter.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        } catch let failure {
            AppLog.auth.error("sign up failed: \(String(reflecting: failure), privacy: .public)")
            error = AppError.presentable(failure)
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
    .environment(AppRouter())
}
