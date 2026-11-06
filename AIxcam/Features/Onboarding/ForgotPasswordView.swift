import OSLog
import SwiftUI

struct ForgotPasswordView: View {
    @Environment(AppRouter.self) private var appRouter
    @Environment(\.dismiss) private var dismiss

    /// Prefilled from the sign-in form so people don't retype it.
    @State var email: String = ""

    @State private var isLoading = false
    @State private var didSend = false
    @State private var error: AppError?

    private var canSubmit: Bool {
        AuthValidation.isValidEmail(email) && !isLoading
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            atmosphereBlurs

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 28) {
                    if didSend {
                        confirmation
                    } else {
                        form
                    }
                }
                .padding(.horizontal, 32)

                Spacer()
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

    // MARK: — Form

    private var form: some View {
        VStack(spacing: 28) {
            VStack(spacing: 8) {
                Text("Reset password")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text("Enter your email and we'll send you a link to set a new password.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.55))
                    .multilineTextAlignment(.center)
            }

            AuthTextField(
                placeholder: "Email",
                text: $email,
                keyboardType: .emailAddress,
                isSecure: false
            )
            .textContentType(.emailAddress)
            .submitLabel(.send)
            .onSubmit { if canSubmit { Task { await send() } } }
            .accessibilityLabel("Email address")

            if let error {
                ErrorBanner(error)
            }

            Button {
                Task { await send() }
            } label: {
                if isLoading {
                    ProgressView()
                        .tint(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    Text("Send Reset Link")
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
    }

    // MARK: — Confirmation

    /// Shown for any valid address, registered or not — see
    /// `AppRouter.sendPasswordReset` for why we don't distinguish.
    private var confirmation: some View {
        VStack(spacing: 20) {
            Image(systemName: "envelope.badge.fill")
                .font(.system(size: 52, weight: .semibold))
                .foregroundStyle(
                    LinearGradient(colors: [.cyan, .pink],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .accessibilityHidden(true)

            Text("Check your inbox")
                .font(.title.weight(.bold))
                .foregroundStyle(.white)

            Text("If an account exists for \(email), a reset link is on its way. It expires in one hour.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
                .multilineTextAlignment(.center)

            Button("Back to Sign In") {
                dismiss()
            }
            .font(.headline)
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.white, in: Capsule())
            .padding(.top, 8)

            Button("Send it again") {
                didSend = false
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var atmosphereBlurs: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.16))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 130, y: -250)

            Circle()
                .fill(Color.pink.opacity(0.16))
                .frame(width: 280, height: 280)
                .blur(radius: 65)
                .offset(x: -130, y: 250)
        }
        .ignoresSafeArea()
    }

    private func send() async {
        error = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await appRouter.sendPasswordReset(
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            didSend = true
        } catch let failure {
            AppLog.auth.error("password reset failed: \(String(reflecting: failure), privacy: .public)")
            error = AppError.presentable(failure)
        }
    }
}

#Preview {
    NavigationStack {
        ForgotPasswordView(email: "viewer@example.com")
    }
    .environment(AppRouter())
}
