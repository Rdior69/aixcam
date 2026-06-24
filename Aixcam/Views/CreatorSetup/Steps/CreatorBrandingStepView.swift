import SwiftUI

struct CreatorBrandingStepView: View {
    @ObservedObject var viewModel: CreatorSetupViewModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: 20) {
            GlassCard(
                title: "Creator Branding",
                subtitle: "Define your visual identity and fan page style"
            ) {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Theme Color")
                            .font(.subheadline.weight(.semibold))
                        ColorPickerGrid(
                            colors: CreatorSetupViewModel.themeColors,
                            selectedHex: $viewModel.profile.branding.themeColorHex
                        )
                        .onChange(of: viewModel.profile.branding.themeColorHex) { viewModel.debouncedSave() }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Accent Color")
                            .font(.subheadline.weight(.semibold))
                        ColorPickerGrid(
                            colors: CreatorSetupViewModel.themeColors.reversed(),
                            selectedHex: $viewModel.profile.branding.accentColorHex
                        )
                        .onChange(of: viewModel.profile.branding.accentColorHex) { viewModel.debouncedSave() }
                    }

                    Picker("Font Style", selection: $viewModel.profile.branding.fontStyle) {
                        ForEach(BrandFontStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .onChange(of: viewModel.profile.branding.fontStyle) { viewModel.debouncedSave() }

                    Picker("Layout Style", selection: $viewModel.profile.branding.layoutStyle) {
                        ForEach(BrandLayoutStyle.allCases) { style in
                            Text(style.rawValue).tag(style)
                        }
                    }
                    .onChange(of: viewModel.profile.branding.layoutStyle) { viewModel.debouncedSave() }

                    Toggle("Show subscriber count", isOn: $viewModel.profile.branding.showSubscriberCount)
                        .onChange(of: viewModel.profile.branding.showSubscriberCount) { viewModel.debouncedSave() }
                    Toggle("Show tip button", isOn: $viewModel.profile.branding.showTipButton)
                        .onChange(of: viewModel.profile.branding.showTipButton) { viewModel.debouncedSave() }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Custom Profile URL")
                            .font(.subheadline.weight(.semibold))
                        HStack {
                            Text("aixcam.app/@")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            TextField("your-name", text: $viewModel.profile.customProfileURL)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .onChange(of: viewModel.profile.customProfileURL) { viewModel.debouncedSave() }
                        }
                        .padding(12)
                        .background(DesignTokens.Colors.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
            }

            FanPagePreviewCard(
                profile: viewModel.profile,
                profilePhotoData: viewModel.profilePhotoData,
                coverPhotoData: viewModel.coverPhotoData
            )
        }
    }
}

struct FanPagePreviewCard: View {
    let profile: CreatorProfile
    let profilePhotoData: Data?
    let coverPhotoData: Data?
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Fan Page Preview")
                .font(.caption.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.accent)
                .padding(.bottom, 10)

            ZStack(alignment: .bottomLeading) {
                coverImage
                    .frame(height: 120)
                    .clipped()

                HStack(spacing: 12) {
                    profileImage
                        .frame(width: 64, height: 64)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(profile.branding.themeColor, lineWidth: 3))
                        .offset(y: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.displayName.isEmpty ? "Your Name" : profile.displayName)
                            .font(.headline.weight(.bold))
                        Text("@\(profile.username.isEmpty ? "username" : profile.username)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .offset(y: 32)

                    Spacer()
                }
                .padding(.horizontal, 16)
            }
            .padding(.bottom, 36)

            if !profile.biography.isEmpty {
                Text(profile.biography)
                    .font(.caption)
                    .foregroundStyle(DesignTokens.Colors.textSecondary(for: colorScheme))
                    .lineLimit(3)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            HStack(spacing: 8) {
                Button("Subscribe") {}
                    .buttonStyle(.borderedProminent)
                    .tint(profile.branding.themeColor)
                    .controlSize(.small)
                Button("Tip") {}
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .opacity(profile.branding.showTipButton ? 1 : 0)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            .disabled(true)
        }
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.cornerRadiusMedium, style: .continuous)
                .stroke(DesignTokens.Colors.glassStroke(for: colorScheme), lineWidth: 1)
        }
        .accessibilityLabel("Fan page preview for \(profile.displayName)")
    }

    @ViewBuilder
    private var coverImage: some View {
        if let data = coverPhotoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage).resizable().scaledToFill()
        } else {
            LinearGradient(
                colors: [profile.branding.themeColor, profile.branding.accentColor],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    @ViewBuilder
    private var profileImage: some View {
        if let data = profilePhotoData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage).resizable().scaledToFill()
        } else {
            Circle()
                .fill(profile.branding.themeColor.opacity(0.3))
                .overlay {
                    Image(systemName: "person.fill")
                        .font(.title2)
                        .foregroundStyle(profile.branding.themeColor)
                }
        }
    }
}
