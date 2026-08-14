import SwiftUI

struct SignUpView: View {
    @Environment(AppRouter.self) private var appRouter
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

    private var passwordMismatch: Bool {
        !confirmPassword.isEmpty && password != confirmPassword
    }

    private var canSubmit: Bool {
        !email.isEmpty && !password.isEmpty && password == confirmPassword && !isLoading
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

                        AuthTextField(
                            placeholder: "Password",
                            text: $password,
                            keyboardType: .default,
                            isSecure: true
                        )

                        AuthTextField(
                            placeholder: "Confirm Password",
                            text: $confirmPassword,
                            keyboardType: .default,
                            isSecure: true
                        )
                        .overlay(alignment: .trailing) {
                            if passwordMismatch {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.red.opacity(0.8))
                                    .padding(.trailing, 16)
                            }
                        }
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
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

                Text("By creating an account you agree to our Terms & Privacy Policy.")
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
            .padding(.top, 56)
            .padding(.leading, 20)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Create account")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)

            Text("Start streaming to your audience.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
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
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await appRouter.signUp(
                email: email.trimmingCharacters(in: .whitespaces),
                password: password
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        SignUpView()
    }
    .environment(AppRouter())
}
