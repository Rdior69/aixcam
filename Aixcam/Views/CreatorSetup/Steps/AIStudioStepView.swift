import SwiftUI

struct AIStudioStepView: View {
    @ObservedObject var viewModel: CreatorSetupViewModel
    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedEnhancement: AIEnhancementType?

    var body: some View {
        VStack(spacing: 20) {
            GlassCard(
                title: "AI Studio",
                subtitle: "Enhance your content with built-in AI tools"
            ) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
                    ForEach(AIEnhancementType.allCases) { enhancement in
                        AIEnhancementCard(
                            enhancement: enhancement,
                            isSelected: selectedEnhancement == enhancement,
                            isProcessing: viewModel.mediaItems.contains {
                                viewModel.aiStudio.isProcessing($0.id)
                            }
                        ) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedEnhancement = selectedEnhancement == enhancement ? nil : enhancement
                            }
                        }
                    }
                }
            }

            if let enhancement = selectedEnhancement {
                applySection(for: enhancement)
            }

            if viewModel.mediaItems.isEmpty {
                EmptyStateView(
                    icon: "wand.and.stars",
                    title: "Upload content first",
                    message: "Go back to Content Creation to upload media, then return here to enhance it with AI"
                )
            } else {
                mediaSelectionList
            }
        }
    }

    private func applySection(for enhancement: AIEnhancementType) -> some View {
        GlassCard(title: "Apply \(enhancement.rawValue)") {
            VStack(spacing: 12) {
                Text(enhancement.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if enhancement == .batchEditing {
                    Button {
                        Task {
                            await viewModel.batchApplyAIEnhancement(
                                enhancement,
                                to: Array(viewModel.selectedMediaIds)
                            )
                        }
                    } label: {
                        Label("Batch apply to \(viewModel.selectedMediaIds.count) items", systemImage: "square.stack.3d.up.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(DesignTokens.Colors.accent)
                    .disabled(viewModel.selectedMediaIds.isEmpty)
                } else {
                    Text("Select media below, then tap Apply")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var mediaSelectionList: some View {
        GlassCard(title: "Your Media", subtitle: "Select items to enhance") {
            ForEach(viewModel.mediaItems) { item in
                HStack(spacing: 12) {
                    Button {
                        if viewModel.selectedMediaIds.contains(item.id) {
                            viewModel.selectedMediaIds.remove(item.id)
                        } else {
                            viewModel.selectedMediaIds.insert(item.id)
                        }
                    } label: {
                        Image(systemName: viewModel.selectedMediaIds.contains(item.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(DesignTokens.Colors.accent)
                    }
                    .buttonStyle(.plain)

                    Image(systemName: item.mediaType.icon)
                        .foregroundStyle(DesignTokens.Colors.accent)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.subheadline.weight(.medium))
                        if !item.aiEnhancements.isEmpty {
                            Text(item.aiEnhancements.map(\.type.rawValue).joined(separator: ", "))
                                .font(.caption2)
                                .foregroundStyle(DesignTokens.Colors.accent)
                        }
                    }

                    Spacer()

                    if viewModel.aiStudio.isProcessing(item.id) {
                        ProgressView()
                    } else if let enhancement = selectedEnhancement, enhancement != .batchEditing {
                        Button("Apply") {
                            Task { await viewModel.applyAIEnhancement(enhancement, to: item.id) }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    if let caption = viewModel.aiStudio.generatedCaptions[item.id] {
                        Image(systemName: "text.bubble.fill")
                            .foregroundStyle(.green)
                            .help(caption)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

private struct AIEnhancementCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let enhancement: AIEnhancementType
    let isSelected: Bool
    let isProcessing: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    Image(systemName: enhancement.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : DesignTokens.Colors.accent)

                    if isProcessing && isSelected {
                        ProgressView()
                            .tint(.white)
                    }
                }
                .frame(width: 48, height: 48)
                .background(
                    isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.accent.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: 12)
                )

                Text(enhancement.rawValue)
                    .font(.caption.weight(.semibold))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(DesignTokens.Colors.cardFill(for: colorScheme), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isSelected ? DesignTokens.Colors.accent : DesignTokens.Colors.glassStroke(for: colorScheme), lineWidth: isSelected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(enhancement.rawValue)\(isSelected ? ", selected" : "")")
    }
}
