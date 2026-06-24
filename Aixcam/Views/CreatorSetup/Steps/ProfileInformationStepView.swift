import SwiftUI

struct ProfileInformationStepView: View {
    @ObservedObject var viewModel: CreatorSetupViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GlassCard(
            title: "Profile Information",
            subtitle: "Help fans discover and connect with you"
        ) {
            VStack(spacing: 16) {
                ImagePickerButton(
                    title: "Upload cover photo",
                    systemImage: "photo.on.rectangle.angled",
                    imageData: viewModel.coverPhotoData,
                    aspectRatio: 2.5
                ) { data in
                    viewModel.coverPhotoData = data
                    viewModel.debouncedSave()
                }

                HStack(spacing: 16) {
                    ImagePickerButton(
                        title: "Profile photo",
                        systemImage: "person.crop.circle.badge.plus",
                        imageData: viewModel.profilePhotoData,
                        aspectRatio: 1
                    ) { data in
                        viewModel.profilePhotoData = data
                        viewModel.debouncedSave()
                    }
                    .frame(width: 120)

                    VStack(spacing: 12) {
                        TextField("Display name", text: $viewModel.profile.displayName)
                            .textContentType(.name)
                            .onChange(of: viewModel.profile.displayName) { viewModel.debouncedSave() }

                        HStack {
                            Text("@")
                                .foregroundStyle(.secondary)
                            TextField("username", text: Binding(
                                get: { viewModel.profile.username },
                                set: { viewModel.updateUsername($0) }
                            ))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("About Me")
                        .font(.subheadline.weight(.semibold))
                    TextEditor(text: $viewModel.profile.biography)
                        .frame(minHeight: 100)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(DesignTokens.Colors.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
                        .onChange(of: viewModel.profile.biography) { viewModel.debouncedSave() }
                }

                TextField("Location (optional)", text: $viewModel.profile.location)
                    .onChange(of: viewModel.profile.location) { viewModel.debouncedSave() }

                websiteLinksSection
                socialLinksSection
            }
        }
    }

    private var websiteLinksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Website Links")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Button {
                    viewModel.addWebsiteLink()
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Colors.accent)
            }

            if viewModel.profile.websiteLinks.isEmpty {
                Text("Add links to your website or portfolio")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach($viewModel.profile.websiteLinks) { $link in
                    HStack(spacing: 8) {
                        TextField("Title", text: $link.title)
                        TextField("URL", text: $link.url)
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                        Button {
                            viewModel.removeWebsiteLink(link)
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
        }
    }

    private var socialLinksSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Social Media")
                .font(.subheadline.weight(.semibold))

            ForEach($viewModel.profile.socialLinks) { $link in
                HStack(spacing: 10) {
                    Image(systemName: link.platform.icon)
                        .frame(width: 24)
                        .foregroundStyle(DesignTokens.Colors.accent)
                    Text(link.platform.rawValue)
                        .font(.caption.weight(.medium))
                        .frame(width: 70, alignment: .leading)
                    TextField("@handle", text: $link.handle)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .onChange(of: link.handle) { viewModel.debouncedSave() }
                }
            }
        }
    }
}
