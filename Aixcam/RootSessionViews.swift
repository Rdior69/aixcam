import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.09, blue: 0.16),
                    Color(red: 0.08, green: 0.12, blue: 0.22),
                    Color(red: 0.12, green: 0.1, blue: 0.2)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 18) {
                Image("AixcamIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 96, height: 96)
                    .accessibilityHidden(true)

                Text("Aixcam")
                    .font(.largeTitle.weight(.heavy))
                    .foregroundStyle(.white)

                Text("Checking your session…")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.72))

                ProgressView()
                    .tint(.teal)
                    .padding(.top, 8)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Aixcam launching, checking your session")
        }
    }
}

struct AccountStatusView: View {
    let user: AppUser
    let status: AccountStatus
    let onSignOut: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "exclamationmark.shield.fill")
                .font(.system(size: 44))
                .foregroundStyle(.orange)

            Text(title)
                .font(.title2.weight(.bold))

            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Text("Signed in as \(user.email)")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button("Sign out", role: .destructive, action: onSignOut)
                .buttonStyle(.borderedProminent)
                .tint(.teal)
        }
        .padding(28)
        .frame(maxWidth: 520)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
    }

    private var title: String {
        switch status {
        case .suspended:
            return "Account suspended"
        case .restricted:
            return "Account restricted"
        case .active:
            return "Account status"
        }
    }

    private var message: String {
        switch status {
        case .suspended:
            return "This Aixcam account is suspended. Contact support if you believe this is a mistake."
        case .restricted:
            return "This Aixcam account is restricted and cannot use creator or subscriber features right now."
        case .active:
            return "Your account is active."
        }
    }
}

struct SubscriberHomeView: View {
    let user: AppUser
    let needsOnboarding: Bool
    let onSignOut: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Aixcam")
                            .font(.title3.weight(.heavy))
                        Text("Subscriber Home")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Sign out", role: .destructive, action: onSignOut)
                        .buttonStyle(.bordered)
                }

                Text("Welcome, \(user.name)")
                    .font(.largeTitle.weight(.bold))

                if needsOnboarding {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Finish subscriber setup")
                            .font(.headline)
                        Text("Subscriber onboarding arrives in a later phase. You can explore the home shell now.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Coming next")
                        .font(.headline)
                    Text("Discover creators, subscriptions, private sessions, and purchased highlights will land in later phases.")
                        .foregroundStyle(.secondary)
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
            .padding(20)
        }
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity)
    }
}
