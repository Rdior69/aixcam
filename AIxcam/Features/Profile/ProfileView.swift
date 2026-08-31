import FirebaseAuth
import SwiftUI

struct ProfileView: View {
    @Environment(AppRouter.self) private var appRouter
    @Environment(ViewerProfileService.self) private var profileService
    @State private var isEditingName = false
    @State private var nameDraft = ""
    @State private var isSaving = false

    @AppStorage("idv_submittedDate") private var idvSubmittedDate = ""
    private var isVerified: Bool { !idvSubmittedDate.isEmpty }

    var body: some View {
        NavigationStack {
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

                    VStack(spacing: 10) {
                        nameSection

                        identitySummary

                        if let email = appRouter.currentUser?.email {
                            Text(email)
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.5))
                        }
                    }

                    Spacer()

                    settingsSection

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

    // MARK: - Settings Section

    /// Age · gender · pronouns, shown only for the fields that are filled in so a
    /// sparse profile doesn't render a row of separators with nothing between them.
    @ViewBuilder
    private var identitySummary: some View {
        let parts: [String] = {
            guard let profile = profileService.profile else { return [] }
            var values: [String] = []
            if let age = profile.age { values.append("\(age)") }
            if let gender = profile.genderLabel { values.append(gender) }
            if let pronouns = profile.pronounsLabel { values.append(pronouns) }
            return values
        }()

        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    private var settingsSection: some View {
        VStack(spacing: 10) {
            Text("Settings")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white.opacity(0.45))
                .textCase(.uppercase)
                .frame(maxWidth: .infinity, alignment: .leading)

            NavigationLink(destination: ViewerProfileEditView(mode: .edit)) {
                settingsRow(
                    systemImage: "person.text.rectangle.fill",
                    tint: .pink,
                    title: "Your Profile",
                    subtitle: profileSubtitle,
                    accent: .pink
                )
            }

            NavigationLink(destination: IDVerificationView()) {
                HStack(spacing: 14) {
                    Image(systemName: isVerified ? "checkmark.shield.fill" : "shield.lefthalf.filled")
                        .font(.title3)
                        .foregroundStyle(isVerified ? .green : .cyan)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("ID Verification")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                        Text(isVerified ? "Submitted · Under review" : "Required for live broadcasting")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    if !isVerified {
                        Text("Required")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.cyan.opacity(0.85), in: Capsule())
                    }

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(
                            isVerified ? Color.green.opacity(0.25) : Color.cyan.opacity(0.2),
                            lineWidth: 1
                        )
                )
            }
        }
    }

    /// Summarises how filled-in the profile is, so the row is a nudge rather than
    /// a dead label once someone has completed it.
    private var profileSubtitle: String {
        guard let profile = profileService.profile else { return "Loading…" }
        let tagCount = profile.turnOns.count + profile.fetishes.count
        if profile.aboutMe.isEmpty && tagCount == 0 {
            return "Add an about me and your interests"
        }
        if tagCount == 0 {
            return "Add your turn ons and fetishes"
        }
        return "\(tagCount) interest\(tagCount == 1 ? "" : "s") · About me \(profile.aboutMe.isEmpty ? "empty" : "set")"
    }

    private func settingsRow(
        systemImage: String,
        tint: Color,
        title: String,
        subtitle: String,
        accent: Color
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(tint)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.leading)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(accent.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - Name Section

    @ViewBuilder
    private var nameSection: some View {
        if isEditingName {
            VStack(spacing: 10) {
                TextField("Display name", text: $nameDraft)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white)
                    .tint(.pink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                HStack(spacing: 12) {
                    Button("Cancel") {
                        isEditingName = false
                        nameDraft = ""
                    }
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.6))

                    Button {
                        Task { await saveName() }
                    } label: {
                        if isSaving {
                            ProgressView().tint(.white)
                        } else {
                            Text("Save")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                    .background(Color.pink.opacity(0.8), in: Capsule())
                    .disabled(nameDraft.trimmingCharacters(in: .whitespaces).isEmpty || isSaving)
                }
            }
        } else {
            HStack(spacing: 8) {
                Text(appRouter.displayName)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)

                Button {
                    nameDraft = appRouter.displayName
                    isEditingName = true
                } label: {
                    Image(systemName: "pencil.circle")
                        .font(.title3)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    private func saveName() async {
        let name = nameDraft.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        isSaving = true
        await appRouter.updateDisplayName(name)
        isSaving = false
        isEditingName = false
        nameDraft = ""
    }
}

#Preview {
    ProfileView()
        .environment(AppRouter())
        .environment(ViewerProfileService())
}
