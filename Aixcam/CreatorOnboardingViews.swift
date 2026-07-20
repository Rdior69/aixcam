import Charts
import PhotosUI
import SwiftUI

struct CreatorSetupWizardView: View {
    @ObservedObject var viewModel: CreatorSetupViewModel
    let onPublished: () -> Void

    @State private var selectedProfilePhoto: PhotosPickerItem?
    @State private var selectedBannerPhoto: PhotosPickerItem?
    @State private var selectedContentPhoto: PhotosPickerItem?
    @State private var selectedContentVideo: PhotosPickerItem?

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                stepHeader
                StepCard {
                    switch viewModel.currentStep {
                    case .profile:
                        ProfileInformationStepView(
                            draft: $viewModel.draft,
                            pendingWebsite: $viewModel.pendingWebsite,
                            pendingSocialHandle: $viewModel.pendingSocialHandle,
                            pendingSocialPlatform: $viewModel.pendingSocialPlatform,
                            profilePicker: $selectedProfilePhoto,
                            bannerPicker: $selectedBannerPhoto,
                            onAddWebsite: viewModel.addWebsite,
                            onRemoveWebsite: viewModel.removeWebsite,
                            onAddSocial: viewModel.addSocialLink,
                            onRemoveSocial: viewModel.removeSocialLink
                        )
                    case .branding:
                        CreatorBrandingStepView(draft: $viewModel.draft, themeColors: viewModel.themeColors)
                    case .content:
                        ContentCreationStepView(
                            draft: $viewModel.draft,
                            pendingMediaTitle: $viewModel.pendingMediaTitle,
                            pendingCategory: $viewModel.pendingCategory,
                            pendingAlbumTitle: $viewModel.pendingAlbumTitle,
                            pendingAlbumDescription: $viewModel.pendingAlbumDescription,
                            photoPicker: $selectedContentPhoto,
                            videoPicker: $selectedContentVideo,
                            onMoveMedia: viewModel.moveMedia,
                            onDeleteMedia: viewModel.deleteMedia,
                            onAddCategory: viewModel.addCategory,
                            onAddAlbum: viewModel.addAlbum
                        )
                    case .subscriptions:
                        FanSubscriptionsStepView(
                            draft: $viewModel.draft,
                            pendingBenefit: $viewModel.pendingBenefit,
                            onToggleTier: viewModel.toggleTier,
                            onAddBenefit: viewModel.addBenefit,
                            onRemoveBenefit: viewModel.removeBenefit
                        )
                    case .aiStudio:
                        AIStudioStepView(
                            draft: $viewModel.draft,
                            onGenerateCaption: viewModel.generateCaptionSuggestion
                        )
                    case .dashboard:
                        DashboardMetricsStepView(draft: viewModel.draft)
                    case .publish:
                        PublishStepView(draft: viewModel.draft, isPublishing: viewModel.isPublishing) {
                            viewModel.publish()
                        }
                    }
                }
                if viewModel.errorMessage.isEmpty == false {
                    MessagePill(text: viewModel.errorMessage, systemImage: "exclamationmark.triangle.fill", tint: .red)
                } else if viewModel.bannerMessage.isEmpty == false {
                    MessagePill(text: viewModel.bannerMessage, systemImage: "checkmark.circle.fill", tint: .green)
                }
                navigationActions
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 22)
        }
        .onChange(of: selectedProfilePhoto) { _, newItem in
            uploadSelection(item: newItem, as: .photo, with: viewModel.uploadProfilePhoto)
        }
        .onChange(of: selectedBannerPhoto) { _, newItem in
            uploadSelection(item: newItem, as: .photo, with: viewModel.uploadBannerPhoto)
        }
        .onChange(of: selectedContentPhoto) { _, newItem in
            addContentSelection(item: newItem, mediaType: .photo)
        }
        .onChange(of: selectedContentVideo) { _, newItem in
            addContentSelection(item: newItem, mediaType: .video)
        }
        .onChange(of: viewModel.publishedProfile?.publicURL) { _, _ in
            onPublished()
        }
        .task {
            viewModel.load()
        }
    }

    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Creator Setup Wizard")
                .font(.title.bold())
            Text(viewModel.currentStep.title)
                .font(.title3.weight(.semibold))
            Text(viewModel.currentStep.subtitle)
                .foregroundStyle(.secondary)
            ProgressView(value: viewModel.progressValue)
                .tint(Color(hex: viewModel.draft.branding.themeColorHex))
            Text("Step \(viewModel.currentStep.rawValue + 1) of \(CreatorOnboardingStep.allCases.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var navigationActions: some View {
        HStack(spacing: 12) {
            if viewModel.currentStep != .profile {
                Button("Back") {
                    viewModel.previousStep()
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            Button {
                viewModel.saveProgress()
            } label: {
                if viewModel.isSaving {
                    ProgressView()
                } else {
                    Text("Save")
                }
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isSaving)

            if viewModel.currentStep != .publish {
                Button("Continue") {
                    viewModel.nextStep()
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: viewModel.draft.branding.themeColorHex))
            }
        }
    }

    private func uploadSelection(
        item: PhotosPickerItem?,
        as mediaType: CreatorMediaType,
        with handler: @escaping (Data) -> Void
    ) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                if mediaType == .photo {
                    handler(data)
                }
            }
        }
    }

    private func addContentSelection(item: PhotosPickerItem?, mediaType: CreatorMediaType) {
        guard let item else { return }
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let category = viewModel.draft.content.categories.first ?? "General"
                viewModel.addMediaAsset(
                    data: data,
                    type: mediaType,
                    title: viewModel.pendingMediaTitle,
                    category: category
                )
                viewModel.pendingMediaTitle = ""
            }
        }
    }
}

private struct ProfileInformationStepView: View {
    @Binding var draft: CreatorOnboardingDraft
    @Binding var pendingWebsite: String
    @Binding var pendingSocialHandle: String
    @Binding var pendingSocialPlatform: SocialPlatform
    @Binding var profilePicker: PhotosPickerItem?
    @Binding var bannerPicker: PhotosPickerItem?
    let onAddWebsite: () -> Void
    let onRemoveWebsite: (IndexSet) -> Void
    let onAddSocial: () -> Void
    let onRemoveSocial: (IndexSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 1 - Profile Information")
                .font(.headline)

            PhotosPicker(selection: $profilePicker, matching: .images) {
                UploadRowLabel(title: "Profile photo upload", value: draft.profile.profilePhotoURL)
            }

            PhotosPicker(selection: $bannerPicker, matching: .images) {
                UploadRowLabel(title: "Cover/banner image upload", value: draft.profile.bannerPhotoURL)
            }

            Group {
                TextField("Display name", text: $draft.profile.displayName)
                TextField("Username", text: $draft.profile.username)
                    .textInputAutocapitalization(.never)
                TextField("About Me biography", text: $draft.profile.aboutMe, axis: .vertical)
                    .lineLimit(3...8)
                TextField("Location (optional)", text: $draft.profile.location)
            }
            .textFieldStyle(.roundedBorder)

            VStack(alignment: .leading, spacing: 8) {
                Text("Website links")
                    .font(.subheadline.weight(.semibold))
                HStack {
                    TextField("https://yourwebsite.com", text: $pendingWebsite)
                        .textFieldStyle(.roundedBorder)
                    Button("Add", action: onAddWebsite)
                        .buttonStyle(.bordered)
                }
                if draft.profile.websites.isEmpty {
                    EmptyStateLabel(text: "No websites added yet.")
                } else {
                    ForEach(draft.profile.websites, id: \.self) { link in
                        Text(link)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(6)
                }
                Button("Remove last website") {
                    guard draft.profile.websites.isEmpty == false else { return }
                    onRemoveWebsite(IndexSet(integer: draft.profile.websites.count - 1))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Social media links")
                    .font(.subheadline.weight(.semibold))
                Picker("Platform", selection: $pendingSocialPlatform) {
                    ForEach(SocialPlatform.allCases) { platform in
                        Text(platform.title).tag(platform)
                    }
                }
                .pickerStyle(.segmented)
                TextField("@handle or URL", text: $pendingSocialHandle)
                    .textFieldStyle(.roundedBorder)
                Button("Add social link", action: onAddSocial)
                    .buttonStyle(.bordered)

                if draft.profile.socialLinks.isEmpty {
                    EmptyStateLabel(text: "No social links added yet.")
                } else {
                    ForEach(draft.profile.socialLinks) { link in
                        HStack {
                            Text(link.platform.title)
                            Spacer()
                            Text(link.handleOrURL)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Remove last social link") {
                        guard draft.profile.socialLinks.isEmpty == false else { return }
                        onRemoveSocial(IndexSet(integer: draft.profile.socialLinks.count - 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct CreatorBrandingStepView: View {
    @Binding var draft: CreatorOnboardingDraft
    let themeColors: [ThemeColorChoice]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 2 - Creator Branding")
                .font(.headline)

            Text("Theme color selection")
                .font(.subheadline.weight(.semibold))

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 10) {
                ForEach(themeColors) { color in
                    Circle()
                        .fill(Color(hex: color.id))
                        .frame(width: 36, height: 36)
                        .overlay(
                            Circle().stroke(.white.opacity(draft.branding.themeColorHex == color.id ? 0.9 : 0), lineWidth: 2)
                        )
                        .onTapGesture {
                            draft.branding.themeColorHex = color.id
                        }
                        .accessibilityLabel(color.name)
                }
            }

            Picker("Profile customization", selection: $draft.branding.profileStyle) {
                ForEach(ProfileStyle.allCases) { style in
                    Text(style.title).tag(style)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Enable glassmorphism effects", isOn: $draft.branding.enableGlassmorphism)

            TextField("Custom profile URL", text: $draft.branding.customProfilePath)
                .textFieldStyle(.roundedBorder)
                .textInputAutocapitalization(.never)

            VStack(alignment: .leading, spacing: 8) {
                Text("Fan page appearance preview")
                    .font(.subheadline.weight(.semibold))
                RoundedRectangle(cornerRadius: 22)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hex: draft.branding.themeColorHex).opacity(0.8),
                                .black.opacity(0.65)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .overlay(alignment: .bottomLeading) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(draft.profile.displayName.isEmpty ? "Creator name" : draft.profile.displayName)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("@\(draft.profile.username.isEmpty ? "username" : draft.profile.username)")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(14)
                    }
                    .frame(height: 150)
            }
        }
    }
}

private struct ContentCreationStepView: View {
    @Binding var draft: CreatorOnboardingDraft
    @Binding var pendingMediaTitle: String
    @Binding var pendingCategory: String
    @Binding var pendingAlbumTitle: String
    @Binding var pendingAlbumDescription: String
    @Binding var photoPicker: PhotosPickerItem?
    @Binding var videoPicker: PhotosPickerItem?
    let onMoveMedia: (IndexSet, Int) -> Void
    let onDeleteMedia: (IndexSet) -> Void
    let onAddCategory: () -> Void
    let onAddAlbum: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step 3 - Content Creation")
                .font(.headline)

            TextField("Media title", text: $pendingMediaTitle)
                .textFieldStyle(.roundedBorder)

            HStack {
                PhotosPicker(selection: $photoPicker, matching: .images) {
                    Label("Upload photos", systemImage: "photo.fill")
                }
                .buttonStyle(.borderedProminent)

                PhotosPicker(selection: $videoPicker, matching: .videos) {
                    Label("Upload videos", systemImage: "video.fill")
                }
                .buttonStyle(.bordered)
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Organize content into categories")
                    .font(.subheadline.weight(.semibold))
                HStack {
                    TextField("New category", text: $pendingCategory)
                        .textFieldStyle(.roundedBorder)
                    Button("Add", action: onAddCategory)
                        .buttonStyle(.bordered)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(draft.content.categories, id: \.self) { category in
                            Text(category)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.white.opacity(0.12), in: Capsule())
                        }
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Drag-and-drop media management")
                    .font(.subheadline.weight(.semibold))
                if draft.content.mediaItems.isEmpty {
                    EmptyStateLabel(text: "Upload media to begin organizing content.")
                } else {
                    List {
                        ForEach(draft.content.mediaItems) { media in
                            HStack {
                                Image(systemName: media.mediaType == .photo ? "photo" : "video")
                                VStack(alignment: .leading) {
                                    Text(media.title).font(.subheadline.weight(.semibold))
                                    Text(media.category).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                        .onMove(perform: onMoveMedia)
                        .onDelete(perform: onDeleteMedia)
                    }
                    .environment(\.editMode, .constant(.active))
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Create albums")
                    .font(.subheadline.weight(.semibold))
                TextField("Album title", text: $pendingAlbumTitle)
                    .textFieldStyle(.roundedBorder)
                TextField("Album description", text: $pendingAlbumDescription)
                    .textFieldStyle(.roundedBorder)
                Button("Create album", action: onAddAlbum)
                    .buttonStyle(.bordered)
                if draft.content.albums.isEmpty {
                    EmptyStateLabel(text: "No albums yet.")
                } else {
                    ForEach(draft.content.albums) { album in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(album.title).font(.subheadline.weight(.semibold))
                            Text(album.description).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

private struct FanSubscriptionsStepView: View {
    @Binding var draft: CreatorOnboardingDraft
    @Binding var pendingBenefit: String
    let onToggleTier: (SubscriptionTierKind, Bool) -> Void
    let onAddBenefit: (SubscriptionTierKind) -> Void
    let onRemoveBenefit: (SubscriptionTierKind, IndexSet) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 4 - Fan Subscriptions")
                .font(.headline)

            TextField(
                "Monthly subscription pricing",
                value: $draft.subscriptions.monthlyBasePrice,
                format: .currency(code: "USD")
            )
            .textFieldStyle(.roundedBorder)

            subscriptionTierCard(title: "Free tier", tier: $draft.subscriptions.freeTier, kind: .free)
            subscriptionTierCard(title: "Premium tier", tier: $draft.subscriptions.premiumTier, kind: .premium)
            subscriptionTierCard(title: "VIP tier", tier: $draft.subscriptions.vipTier, kind: .vip)

            VStack(alignment: .leading, spacing: 8) {
                Text("Subscription preview page")
                    .font(.subheadline.weight(.semibold))
                RoundedRectangle(cornerRadius: 18)
                    .fill(.ultraThinMaterial)
                    .overlay {
                        HStack {
                            Label("$\(Int(draft.subscriptions.premiumTier.price))/mo", systemImage: "star.fill")
                            Spacer()
                            Label("$\(Int(draft.subscriptions.vipTier.price))/mo", systemImage: "crown.fill")
                        }
                        .padding(14)
                    }
                    .frame(height: 70)
            }
        }
    }

    private func subscriptionTierCard(
        title: String,
        tier: Binding<SubscriptionTier>,
        kind: SubscriptionTierKind
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(title, isOn: Binding(
                get: { tier.wrappedValue.isEnabled },
                set: { onToggleTier(kind, $0) }
            ))

            TextField("Price", value: tier.price, format: .currency(code: "USD"))
                .textFieldStyle(.roundedBorder)
                .disabled(tier.wrappedValue.isEnabled == false)

            TextField("Add benefit", text: $pendingBenefit)
                .textFieldStyle(.roundedBorder)
                .disabled(tier.wrappedValue.isEnabled == false)

            Button("Add benefit") {
                onAddBenefit(kind)
            }
            .buttonStyle(.bordered)
            .disabled(tier.wrappedValue.isEnabled == false)

            if tier.wrappedValue.benefits.isEmpty {
                EmptyStateLabel(text: "No benefits yet.")
            } else {
                ForEach(tier.wrappedValue.benefits, id: \.self) { benefit in
                    Text("• \(benefit)")
                        .font(.subheadline)
                }
                Button("Remove last benefit") {
                    guard tier.wrappedValue.benefits.isEmpty == false else { return }
                    onRemoveBenefit(kind, IndexSet(integer: tier.wrappedValue.benefits.count - 1))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct AIStudioStepView: View {
    @Binding var draft: CreatorOnboardingDraft
    let onGenerateCaption: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step 5 - AI Studio")
                .font(.headline)

            Group {
                Toggle("Background removal", isOn: $draft.aiStudio.backgroundRemovalEnabled)
                Toggle("AI image enhancement", isOn: $draft.aiStudio.enhancementEnabled)
                Toggle("AI filters", isOn: $draft.aiStudio.filtersEnabled)
                Toggle("AI caption generator", isOn: $draft.aiStudio.captionGeneratorEnabled)
                Toggle("AI thumbnail creator", isOn: $draft.aiStudio.thumbnailGeneratorEnabled)
                Toggle("AI image upscaling", isOn: $draft.aiStudio.upscalingEnabled)
                Toggle("Batch image editing", isOn: $draft.aiStudio.batchEditingEnabled)
            }

            Button("Generate AI caption", action: onGenerateCaption)
                .buttonStyle(.borderedProminent)
            if draft.aiStudio.latestCaptionSuggestion.isEmpty {
                EmptyStateLabel(text: "No caption generated yet.")
            } else {
                Text(draft.aiStudio.latestCaptionSuggestion)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }
}

private struct DashboardMetricsStepView: View {
    let draft: CreatorOnboardingDraft

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Step 6 - Creator Dashboard")
                .font(.headline)

            Text(draft.dashboard.isDemoData ? "Sample preview metrics — not live analytics." : "Live analytics preview.")
                .font(.footnote)
                .foregroundStyle(.secondary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                MetricCard(title: "Revenue", value: draft.dashboard.monthlyRevenue.formatted(.currency(code: "USD")))
                MetricCard(title: "Subscribers", value: "\(draft.dashboard.subscriberCount)")
                MetricCard(title: "Profile views", value: "\(draft.dashboard.profileViews)")
                MetricCard(title: "Engagement", value: "\(Int(draft.dashboard.engagementRate * 100))%")
            }

            Chart(draft.dashboard.earningsByMonth) { point in
                BarMark(
                    x: .value("Month", point.monthLabel),
                    y: .value("Revenue", point.value)
                )
                .foregroundStyle(.teal.gradient)
            }
            .frame(height: 180)
            .accessibilityLabel("Earnings reports")

            Chart(draft.dashboard.contentPerformance) { point in
                LineMark(
                    x: .value("Category", point.category),
                    y: .value("Score", point.score)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.purple)
            }
            .frame(height: 180)
            .accessibilityLabel("Content performance charts")
        }
    }
}

private struct PublishStepView: View {
    let draft: CreatorOnboardingDraft
    let isPublishing: Bool
    let onPublish: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Step 7 - Publish")
                .font(.headline)
            Text("Review all creator information")
                .foregroundStyle(.secondary)

            reviewRow("Display name", draft.profile.displayName)
            reviewRow("Username", "@\(draft.profile.username)")
            reviewRow("Custom URL", draft.branding.customProfilePath)
            reviewRow("Media uploads", "\(draft.content.mediaItems.count)")
            reviewRow("Albums", "\(draft.content.albums.count)")
            reviewRow("Free/Premium/VIP tiers", "Configured")
            reviewRow("AI Studio", "Enabled tools: \(enabledAIToolCount)")

            RoundedRectangle(cornerRadius: 16)
                .fill(.thinMaterial)
                .overlay(alignment: .leading) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Preview public fan page")
                            .font(.subheadline.weight(.semibold))
                        Text("https://aixcam.app/creator/\(draft.branding.customProfilePath)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(12)
                }
                .frame(height: 70)

            Button {
                onPublish()
            } label: {
                if isPublishing {
                    ProgressView()
                } else {
                    Text("Publish creator profile")
                }
            }
            .buttonStyle(.borderedProminent)
            .tint(.teal)
            .disabled(isPublishing)
        }
    }

    private var enabledAIToolCount: Int {
        let tools = [
            draft.aiStudio.backgroundRemovalEnabled,
            draft.aiStudio.enhancementEnabled,
            draft.aiStudio.filtersEnabled,
            draft.aiStudio.captionGeneratorEnabled,
            draft.aiStudio.thumbnailGeneratorEnabled,
            draft.aiStudio.upscalingEnabled,
            draft.aiStudio.batchEditingEnabled
        ]
        return tools.filter { $0 }.count
    }

    private func reviewRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value.isEmpty ? "-" : value)
                .fontWeight(.medium)
        }
    }
}

struct CreatorDashboardHomeView: View {
    let user: AppUser
    let onSignOut: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Creator Dashboard")
                    .font(.largeTitle.bold())
                Text("Welcome, \(user.name)")
                    .foregroundStyle(.secondary)

                StepCard {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Profile is live")
                            .font(.headline)
                        Text("Your creator page is published and visible to fans.")
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Sign out", action: onSignOut)
                    .buttonStyle(.bordered)
            }
            .padding(20)
        }
    }
}

private struct MetricCard: View {
    let title: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.weight(.bold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct UploadRowLabel: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Label(title, systemImage: "square.and.arrow.up")
            Spacer()
            if value.isEmpty {
                Text("Not uploaded")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            }
        }
    }
}

private struct EmptyStateLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

private struct MessagePill: View {
    let text: String
    let systemImage: String
    let tint: Color

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(tint)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct StepCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 1)
            }
    }
}

private extension Color {
    init(hex: String) {
        let normalized = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var intValue: UInt64 = 0
        Scanner(string: normalized).scanHexInt64(&intValue)
        let red = Double((intValue >> 16) & 0xff) / 255
        let green = Double((intValue >> 8) & 0xff) / 255
        let blue = Double(intValue & 0xff) / 255
        self.init(red: red, green: green, blue: blue)
    }
}
