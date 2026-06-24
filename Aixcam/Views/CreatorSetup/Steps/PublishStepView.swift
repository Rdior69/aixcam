import SwiftUI

struct PublishStepView: View {
    @ObservedObject var viewModel: CreatorSetupViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var showPreview = false

    var body: some View {
        VStack(spacing: 20) {
            GlassCard(
                title: "Review & Publish",
                subtitle: "Review your creator profile before going live"
            ) {
                VStack(spacing: 16) {
                    reviewSection(title: "Profile", icon: "person.crop.circle") {
                        ReviewRow(label: "Display Name", value: viewModel.profile.displayName)
                        ReviewRow(label: "Username", value: "@\(viewModel.profile.username)")
                        ReviewRow(label: "Bio", value: viewModel.profile.biography)
                        if !viewModel.profile.location.isEmpty {
                            ReviewRow(label: "Location", value: viewModel.profile.location)
                        }
                        ReviewRow(label: "Profile Photo", value: viewModel.profilePhotoData != nil ? "Uploaded" : "Not set")
                        ReviewRow(label: "Cover Photo", value: viewModel.coverPhotoData != nil ? "Uploaded" : "Not set")
                    }

                    reviewSection(title: "Branding", icon: "paintpalette") {
                        ReviewRow(label: "Theme", value: viewModel.profile.branding.themeColorHex)
                        ReviewRow(label: "URL", value: viewModel.profile.fanPageURL)
                        ReviewRow(label: "Layout", value: viewModel.profile.branding.layoutStyle.rawValue)
                    }

                    reviewSection(title: "Content", icon: "photo.on.rectangle.angled") {
                        ReviewRow(label: "Media Items", value: "\(viewModel.mediaItems.count)")
                        ReviewRow(label: "Albums", value: "\(viewModel.albums.count)")
                        ReviewRow(label: "Categories", value: "\(Set(viewModel.mediaItems.map(\.category)).count)")
                    }

                    reviewSection(title: "Subscriptions", icon: "crown") {
                        ForEach(activeTiers) { tier in
                            ReviewRow(label: tier.name, value: tier.formattedPrice)
                        }
                    }

                    reviewSection(title: "AI Enhancements", icon: "wand.and.stars") {
                        let enhanced = viewModel.mediaItems.filter { !$0.aiEnhancements.isEmpty }.count
                        ReviewRow(label: "Enhanced Media", value: "\(enhanced) of \(viewModel.mediaItems.count)")
                    }

                    Button {
                        showPreview = true
                    } label: {
                        Label("Preview Public Fan Page", systemImage: "eye")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(DesignTokens.Colors.accent)
                }
            }

            VStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.largeTitle)
                    .foregroundStyle(DesignTokens.Colors.accent)

                Text("Ready to go live?")
                    .font(.headline.weight(.bold))

                Text("Your creator profile will be visible to fans on Aixcam. You can edit everything later from your dashboard.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
        .sheet(isPresented: $showPreview) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        FanPagePreviewCard(
                            profile: viewModel.profile,
                            profilePhotoData: viewModel.profilePhotoData,
                            coverPhotoData: viewModel.coverPhotoData
                        )

                        SubscriptionPreviewCard(configuration: viewModel.profile.subscriptionTiers)

                        if !viewModel.mediaItems.isEmpty {
                            GlassCard(title: "Content Gallery") {
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                                    ForEach(viewModel.mediaItems) { item in
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(DesignTokens.Colors.cardFill(for: colorScheme))
                                            .aspectRatio(1, contentMode: .fit)
                                            .overlay {
                                                Image(systemName: item.mediaType.icon)
                                                    .foregroundStyle(DesignTokens.Colors.accent)
                                            }
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                .background(AdaptiveBackgroundGradient())
                .navigationTitle("Fan Page Preview")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { showPreview = false }
                    }
                }
            }
        }
    }

    private var activeTiers: [SubscriptionTier] {
        [viewModel.profile.subscriptionTiers.freeTier,
         viewModel.profile.subscriptionTiers.premiumTier,
         viewModel.profile.subscriptionTiers.vipTier]
            .filter { $0.tierType == .free || $0.isEnabled }
    }

    @ViewBuilder
    private func reviewSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(DesignTokens.Colors.accent)

            content()
        }
        .padding(14)
        .background(DesignTokens.Colors.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct ReviewRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.weight(.medium))
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
    }
}
