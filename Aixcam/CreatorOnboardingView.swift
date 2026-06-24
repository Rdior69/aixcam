import PhotosUI
import SwiftUI
import UIKit

struct CreatorOnboardingView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel
    @StateObject private var viewModel: CreatorOnboardingViewModel

    init(member: Member, service: CreatorProfileServicing = FirebaseCreatorProfileService()) {
        _viewModel = StateObject(wrappedValue: CreatorOnboardingViewModel(member: member, service: service))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            onboardingHeader
            stepSelector
            if viewModel.selectedStep == .profileInfo {
                CreatorProfileInfoStepView(viewModel: viewModel)
            } else {
                CreatorOnboardingStepPlaceholder(step: viewModel.selectedStep)
            }
            actionBar
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        }
        .task {
            await viewModel.loadProfile()
        }
    }

    private var onboardingHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: "person.crop.square.badge.video")
                    .font(.title2)
                    .foregroundStyle(.teal)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Creator onboarding")
                        .font(.largeTitle.weight(.black))
                        .minimumScaleFactor(0.8)

                    Text(viewModel.profile.displayName)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            Text("Set up the foundation for your creator profile. Each section is a placeholder for this phase.")
                .font(.body)
                .foregroundStyle(.secondary)

            if let statusMessage = viewModel.statusMessage {
                Label(statusMessage, systemImage: "info.circle")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Creator onboarding status. \(statusMessage)")
            }
        }
    }

    private var stepSelector: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Setup steps")
                .font(.headline)

            ForEach(viewModel.steps) { step in
                Button {
                    viewModel.select(step)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: step.systemImage)
                            .frame(width: 24)
                        Text(step.title)
                        Spacer()
                        if viewModel.profile.completedSteps.contains(step) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                        } else if viewModel.selectedStep == step {
                            Image(systemName: "chevron.right.circle.fill")
                                .foregroundStyle(.teal)
                        }
                    }
                    .padding(12)
                    .background(stepBackground(for: step), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens the \(step.title) placeholder.")
            }
        }
    }

    private var actionBar: some View {
        VStack(spacing: 12) {
            if viewModel.selectedStep == .profileInfo {
                Button {
                    Task {
                        await viewModel.saveProfileInformationAndContinue()
                    }
                } label: {
                    if viewModel.isSaving {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Label("Continue to Photos", systemImage: "arrow.right")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
                .disabled(viewModel.isSaving)
            } else {
                HStack(spacing: 12) {
                    Button("Back") {
                        viewModel.moveToPreviousStep()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isFirstStep)

                    Button(viewModel.isLastStep ? "Review" : "Next") {
                        viewModel.moveToNextStep()
                    }
                    .buttonStyle(.bordered)
                    .disabled(viewModel.isLastStep)

                    Button {
                        Task {
                            await viewModel.markSelectedStepComplete()
                        }
                    } label: {
                        Label("Mark placeholder ready", systemImage: "checkmark")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.teal)
                    .disabled(viewModel.isSaving)
                }
            }

            Button {
                authViewModel.logout()
            } label: {
                Label("Log out", systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
    }

    private func stepBackground(for step: CreatorSetupStep) -> Color {
        if viewModel.selectedStep == step {
            return .teal.opacity(0.18)
        }

        return .white.opacity(0.08)
    }
}

private struct CreatorProfileInfoStepView: View {
    @ObservedObject var viewModel: CreatorOnboardingViewModel
    @State private var profilePhotoItem: PhotosPickerItem?
    @State private var coverImageItem: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("Profile Info", systemImage: CreatorSetupStep.profileInfo.systemImage)
                .font(.title2.weight(.bold))

            Form {
                Section("Images") {
                    CreatorImagePickerRow(
                        title: "Profile photo",
                        selectedData: viewModel.profileInfoForm.profilePhotoData,
                        existingURL: viewModel.profile.profilePhotoURL,
                        item: $profilePhotoItem
                    )

                    CreatorImagePickerRow(
                        title: "Cover/banner image",
                        selectedData: viewModel.profileInfoForm.coverImageData,
                        existingURL: viewModel.profile.coverImageURL,
                        item: $coverImageItem
                    )
                }

                Section("Identity") {
                    TextField("Display name", text: $viewModel.profileInfoForm.displayName)
                        .textContentType(.name)
                    TextField("Username", text: $viewModel.profileInfoForm.username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Location", text: $viewModel.profileInfoForm.location)
                }

                Section("About") {
                    TextEditor(text: $viewModel.profileInfoForm.aboutMe)
                        .frame(minHeight: 110)
                        .overlay(alignment: .topLeading) {
                            if viewModel.profileInfoForm.aboutMe.isEmpty {
                                Text("About Me description")
                                    .foregroundStyle(.secondary)
                                    .padding(.top, 8)
                                    .padding(.leading, 4)
                            }
                        }
                }

                Section("Links") {
                    TextField("Website link", text: $viewModel.profileInfoForm.websiteURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("Instagram link", text: $viewModel.profileInfoForm.instagramURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("TikTok link", text: $viewModel.profileInfoForm.tiktokURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                    TextField("X/Twitter link", text: $viewModel.profileInfoForm.xTwitterURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                }

                if viewModel.validationErrors.isEmpty == false {
                    Section("Required before continuing") {
                        ForEach(viewModel.validationErrors, id: \.self) { error in
                            Label(error, systemImage: "exclamationmark.triangle.fill")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .frame(minHeight: 640)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let errorMessage = viewModel.errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .accessibilityLabel("Profile info error. \(errorMessage)")
            }
        }
        .onChange(of: profilePhotoItem) { _, newItem in
            Task {
                await loadImageData(from: newItem, imageType: .profilePhoto)
            }
        }
        .onChange(of: coverImageItem) { _, newItem in
            Task {
                await loadImageData(from: newItem, imageType: .coverImage)
            }
        }
    }

    private func loadImageData(from item: PhotosPickerItem?, imageType: CreatorProfileImageType) async {
        guard let item else {
            return
        }

        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                viewModel.setProfileInfoError("We could not read the selected image.")
                return
            }

            switch imageType {
            case .profilePhoto:
                viewModel.setProfilePhoto(data: data)
            case .coverImage:
                viewModel.setCoverImage(data: data)
            }
        } catch {
            viewModel.setProfileInfoError("We could not load the selected image.")
        }
    }
}

private struct CreatorImagePickerRow: View {
    let title: String
    let selectedData: Data?
    let existingURL: String?
    @Binding var item: PhotosPickerItem?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            HStack(spacing: 14) {
                imagePreview

                PhotosPicker(selection: $item, matching: .images) {
                    Label("Choose image", systemImage: "photo")
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var imagePreview: some View {
        if let selectedData, let image = UIImage(data: selectedData) {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: 96, height: 72)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else if let existingURL, let url = URL(string: existingURL) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .scaledToFill()
                default:
                    placeholder
                }
            }
            .frame(width: 96, height: 72)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.white.opacity(0.12))
            .frame(width: 96, height: 72)
            .overlay {
                Image(systemName: "photo")
                    .foregroundStyle(.secondary)
            }
    }
}

private enum CreatorProfileImageType {
    case profilePhoto
    case coverImage
}

private struct CreatorOnboardingStepPlaceholder: View {
    let step: CreatorSetupStep

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label(step.title, systemImage: step.systemImage)
                .font(.title2.weight(.bold))

            Text(step.placeholderDescription)
                .foregroundStyle(.secondary)
                .lineSpacing(3)

            Text("Placeholder screen only. Data entry, uploads, subscriptions, AI tooling, dashboard metrics, and publishing logic will be added in later phases.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

#Preview {
    CreatorOnboardingView(member: Member(name: "Aix Creator", email: "creator@example.com", accountType: .creator))
        .environmentObject(AuthViewModel())
        .padding()
        .background(Color(red: 0.03, green: 0.04, blue: 0.08))
}
