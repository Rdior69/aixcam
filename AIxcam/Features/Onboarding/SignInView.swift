import SwiftUI

struct SignInView: View {
    @Environment(AppRouter.self) private var appRouter
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var isLoading = false
    @State private var errorMessage: String?

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
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red.opacity(0.9))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 4)
                    }

                    Button {
                        Task { await signIn() }
                    } label: {
                        if isLoading {
                            ProgressView()
                                .tint(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            Text("Sign In")
                                .font(.headline)
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                    .background(Color.white.opacity(isLoading ? 0.7 : 1.0), in: Capsule())
                    .disabled(isLoading || email.isEmpty || password.isEmpty)
                    .animation(.easeOut(duration: 0.12), value: isLoading)
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
            .padding(.top, 56)
            .padding(.leading, 20)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("Welcome back")
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(.white)

            Text("Sign in to your creator account.")
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    private var atmosphereBlurs: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: -140, y: -260)

            Circle()
                .fill(Color.pink.opacity(0.16))
                .frame(width: 280, height: 280)
                .blur(radius: 65)
                .offset(x: 140, y: 240)
        }
        .ignoresSafeArea()
    }

    private func signIn() async {
        errorMessage = nil
        isLoading = true
        defer { isLoading = false }

        do {
            try await appRouter.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

#Preview {
    NavigationStack {
        SignInView()
    }
    .environment(AppRouter())
}
