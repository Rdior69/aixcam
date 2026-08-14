import SwiftUI

struct OnboardingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            atmosphereBlurs

            VStack(spacing: 0) {
                Spacer()

                brandMark
                    .padding(.bottom, 48)

                VStack(spacing: 14) {
                    NavigationLink {
                        SignInView()
                    } label: {
                        Text("Sign In")
                            .font(.headline)
                            .foregroundStyle(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white, in: Capsule())
                    }

                    NavigationLink {
                        SignUpView()
                    } label: {
                        Text("Create Account")
                            .font(.headline)
                            .foregroundStyle(.white.opacity(0.9))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white.opacity(0.1), in: Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.2), lineWidth: 1))
                    }
                }
                .padding(.horizontal, 32)

                Spacer()

                Text("By continuing you agree to our Terms & Privacy Policy.")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.3))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                    .padding(.bottom, 32)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private var atmosphereBlurs: some View {
        ZStack {
            Circle()
                .fill(Color.cyan.opacity(0.20))
                .frame(width: 340, height: 340)
                .blur(radius: 80)
                .offset(x: -140, y: -260)

            Circle()
                .fill(Color.pink.opacity(0.18))
                .frame(width: 320, height: 320)
                .blur(radius: 75)
                .offset(x: 150, y: 260)
        }
        .ignoresSafeArea()
    }

    private var brandMark: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.cyan.opacity(0.25), .pink.opacity(0.25)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "video.badge.waveform.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan, .pink],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            VStack(spacing: 8) {
                Text("AIxcam")
                    .font(.largeTitle.weight(.bold))
                    .foregroundStyle(.white)

                Text("Go live in seconds.")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.6))
            }
        }
    }
}

#Preview {
    NavigationStack {
        OnboardingView()
    }
    .environment(AppRouter())
}
