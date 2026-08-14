import FirebaseAuth
import SwiftUI

struct ProfileView: View {
    @Environment(AppRouter.self) private var appRouter

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.cyan.opacity(0.7), .pink.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                VStack(spacing: 6) {
                    Text("Creator")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)

                    if let email = appRouter.currentUser?.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                Spacer()

                Button("Sign Out") {
                    appRouter.signOut()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 28)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.1), in: Capsule())
                .overlay(Capsule().stroke(Color.white.opacity(0.18), lineWidth: 1))
                .padding(.bottom, 40)
            }
            .padding(.horizontal, 32)
        }
    }
}

#Preview {
    ProfileView()
        .environment(AppRouter())
}
