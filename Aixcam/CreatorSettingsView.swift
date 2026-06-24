import SwiftUI

struct CreatorSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel: CreatorSettingsViewModel
    @State private var isShowingDeleteConfirmation = false

    private let onEditProfile: () -> Void

    init(profile: CreatorProfile, onEditProfile: @escaping () -> Void) {
        _viewModel = StateObject(wrappedValue: CreatorSettingsViewModel(profile: profile))
        self.onEditProfile = onEditProfile
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header
                    profileSection
                    visibilitySection
                    notificationsSection
                    accountSection
                    dangerZoneSection
                }
                .padding(20)
                .frame(maxWidth: 720)
                .frame(maxWidth: .infinity)
            }
            .background(Color(red: 0.03, green: 0.04, blue: 0.08).ignoresSafeArea())
            .navigationTitle("Creator Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Delete your Aixcam account from this device?",
                isPresented: $isShowingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete account", role: .destructive) {
                    _ = authViewModel.deleteCurrentAccount()
                    dismiss()
                }

                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This removes the local prototype account and saved credentials from this device.")
            }
        }
    }

    private var header: some View {
        SettingsCard {
            HStack(spacing: 14) {
                Image(systemName: "gearshape.fill")
                    .font(.title2)
                    .foregroundStyle(.teal)
                    .frame(width: 44, height: 44)
                    .background(.teal.opacity(0.16), in: RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Creator Settings")
                        .font(.largeTitle.weight(.black))
                        .minimumScaleFactor(0.8)

                    Text(viewModel.profile.displayName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            if let statusMessage = viewModel.statusMessage {
                Label(statusMessage, systemImage: "checkmark.circle.fill")
                    .font(.footnote)
                    .foregroundStyle(.green)
            }
        }
    }

    private var profileSection: some View {
        SettingsCard(title: "Profile") {
            SettingsInfoRow(label: "Display name", value: viewModel.profile.displayName)
            SettingsInfoRow(label: "Username", value: viewModel.profile.username.isEmpty ? "Not set" : "@\(viewModel.profile.username)")
            SettingsInfoRow(label: "Status", value: viewModel.profileStatusText)

            Button {
                dismiss()
                onEditProfile()
            } label: {
                Label("Edit Profile Information", systemImage: "person.text.rectangle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
    }

    private var visibilitySection: some View {
        SettingsCard(title: "Visibility and Fans") {
            Toggle("Make creator profile public", isOn: $viewModel.settings.isProfilePublic)
            Toggle("Allow fan messages", isOn: $viewModel.settings.allowFanMessages)

            Text("Publishing controls stay local in this prototype until the creator profile flow is fully connected.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var notificationsSection: some View {
        SettingsCard(title: "Notifications") {
            Toggle("Email notifications", isOn: $viewModel.settings.emailNotificationsEnabled)
            Toggle("Push notifications", isOn: $viewModel.settings.pushNotificationsEnabled)
            Toggle("Creator tips and onboarding emails", isOn: $viewModel.settings.creatorTipsEnabled)

            Text(viewModel.notificationSummary)
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button {
                viewModel.saveLocalSettings()
            } label: {
                Label("Save Settings", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
        }
    }

    private var accountSection: some View {
        SettingsCard(title: "Account") {
            SettingsInfoRow(label: "Email", value: viewModel.profile.email)

            Button {
                authViewModel.logout()
                dismiss()
            } label: {
                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private var dangerZoneSection: some View {
        SettingsCard(title: "Danger Zone") {
            Text("Deleting removes this local prototype account from the device.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Button(role: .destructive) {
                isShowingDeleteConfirmation = true
            } label: {
                Label("Delete account from this device", systemImage: "trash")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String?
    private let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let title {
                Text(title)
                    .font(.headline)
            }

            content
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        }
    }
}

private struct SettingsInfoRow: View {
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

#Preview {
    CreatorSettingsView(
        profile: CreatorProfile(
            id: UUID().uuidString,
            ownerMemberId: UUID().uuidString,
            displayName: "Aix Creator",
            email: "creator@example.com",
            username: "aix_creator"
        ),
        onEditProfile: {}
    )
    .environmentObject(AuthViewModel())
}
