import PhotosUI
import SwiftUI

struct ProfileInformationView: View {
    @ObservedObject var onboardingViewModel: CreatorOnboardingViewModel
    @StateObject private var viewModel: ProfileInformationViewModel

    init(
        onboardingViewModel: CreatorOnboardingViewModel,
        profileService: CreatorProfileServicing = FirebaseCreatorProfileService(),
        mediaService: CreatorMediaUploadServicing = FirebaseCreatorMediaService()
    ) {
        self.onboardingViewModel = onboardingViewModel
        _viewModel = StateObject(
            wrappedValue: ProfileInformationViewModel(
                profile: onboardingViewModel.profile,
                profileService: profileService,
                mediaService: mediaService
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                Label("Profile Information", systemImage: "person.text.rectangle")
                    .font(.title2.weight(.bold))

                Text("Tell fans who you are. Required fields are marked with an asterisk.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Form {
                Section("Images") {
                    imagePickerRow(
                        title: "Profile photo *",
                        subtitle: "Square photo shown on your creator profile.",
                        preview: viewModel.profilePhotoPreview,
                        fallbackSystemImage: "person.crop.circle.fill",
                        selection: $viewModel.profilePhotoItem,
                        validationMessage: viewModel.validationErrors[.profilePhoto]
                    )

                    imagePickerRow(
                        title: "Cover / banner image",
                        subtitle: "Wide banner displayed at the top of your profile.",
                        preview: viewModel.coverImagePreview,
                        fallbackSystemImage: "photo.on.rectangle.angled",
                        selection: $viewModel.coverImageItem,
                        validationMessage: nil
                    )
                }

                Section("Public profile") {
                    labeledField(
                        title: "Display name *",
                        text: $viewModel.displayName,
                        prompt: "Your creator name",
                        validationMessage: viewModel.validationErrors[.displayName]
                    )

                    labeledField(
                        title: "Username *",
                        text: $viewModel.username,
                        prompt: "yourname",
                        validationMessage: viewModel.validationErrors[.username],
                        autocapitalization: .never
                    )

                    VStack(alignment: .leading, spacing: 6) {
                        Text("About Me")
                            .font(.subheadline.weight(.semibold))
                        TextField("Share your story, niche, and what fans can expect.", text: $viewModel.aboutMe, axis: .vertical)
                            .lineLimit(3...6)
                    }

                    labeledField(
                        title: "Location",
                        text: $viewModel.location,
                        prompt: "City, country"
                    )
                }

                Section("Links") {
                    labeledField(
                        title: "Website",
                        text: $viewModel.websiteLink,
                        prompt: "https://your-site.com",
                        useURLKeyboard: true,
                        autocapitalization: .never
                    )

                    labeledField(
                        title: "Instagram",
                        text: $viewModel.instagramLink,
                        prompt: "https://instagram.com/you",
                        useURLKeyboard: true,
                        autocapitalization: .never
                    )

                    labeledField(
                        title: "TikTok",
                        text: $viewModel.tiktokLink,
                        prompt: "https://tiktok.com/@you",
                        useURLKeyboard: true,
                        autocapitalization: .never
                    )

                    labeledField(
                        title: "X / Twitter",
                        text: $viewModel.twitterLink,
                        prompt: "https://x.com/you",
                        useURLKeyboard: true,
                        autocapitalization: .never
                    )
                }
            }
            .formStyle(.grouped)
            .scrollContentBackground(.hidden)

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(.red.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }

            Button {
                Task {
                    if let updatedProfile = await viewModel.saveAndContinue(baseProfile: onboardingViewModel.profile) {
                        onboardingViewModel.applyProfileUpdate(updatedProfile)
                        onboardingViewModel.moveToNextStep()
                    }
                }
            } label: {
                HStack {
                    if viewModel.isSaving {
                        ProgressView()
                            .tint(.white)
                    }
                    Text(viewModel.isSaving ? "Saving profile..." : "Continue")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.teal)
            .disabled(viewModel.isSaving)
            .accessibilityHint("Validates your profile, uploads images, saves to Firestore, and moves to the next onboarding step.")
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .onChange(of: viewModel.profilePhotoItem) {
            Task { await viewModel.handleProfilePhotoSelection() }
        }
        .onChange(of: viewModel.coverImageItem) {
            Task { await viewModel.handleCoverImageSelection() }
        }
        .onChange(of: onboardingViewModel.profile) {
            viewModel.apply(profile: onboardingViewModel.profile)
        }
    }

    @ViewBuilder
    private func imagePickerRow(
        title: String,
        subtitle: String,
        preview: Image?,
        fallbackSystemImage: String,
        selection: Binding<PhotosPickerItem?>,
        validationMessage: String?
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                Group {
                    if let preview {
                        preview
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: fallbackSystemImage)
                            .font(.title)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 72, height: 72)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                PhotosPicker(selection: selection, matching: .images) {
                    Label("Choose image", systemImage: "photo.on.rectangle")
                }
                .buttonStyle(.bordered)
            }

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func labeledField(
        title: String,
        text: Binding<String>,
        prompt: String,
        validationMessage: String? = nil,
        useURLKeyboard: Bool = false,
        autocapitalization: TextInputAutocapitalization = .sentences
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            TextField(prompt, text: text)
                .keyboardType(useURLKeyboard ? .URL : .default)
                .textInputAutocapitalization(autocapitalization)
                .autocorrectionDisabled(useURLKeyboard || autocapitalization == .never)

            if let validationMessage {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
    }
}

#Preview {
    ProfileInformationView(
        onboardingViewModel: CreatorOnboardingViewModel(
            member: Member(name: "Aix Creator", email: "creator@example.com", accountType: .creator),
            service: PreviewCreatorProfileService()
        )
    )
    .padding()
    .background(Color(red: 0.03, green: 0.04, blue: 0.08))
}

private final class PreviewCreatorProfileService: CreatorProfileServicing {
    func fetchProfile(for id: String) async throws -> CreatorProfile? { nil }
    func saveProfile(_ profile: CreatorProfile) async throws {}
}
