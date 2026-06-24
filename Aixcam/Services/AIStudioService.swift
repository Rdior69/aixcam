import Foundation

@MainActor
final class AIStudioService: ObservableObject {
    @Published private(set) var processingItems: Set<UUID> = []
    @Published private(set) var generatedCaptions: [UUID: String] = [:]

    func applyEnhancement(
        _ type: AIEnhancementType,
        to mediaId: UUID,
        mediaItems: inout [CreatorMediaItem]
    ) async throws {
        processingItems.insert(mediaId)
        defer { processingItems.remove(mediaId) }

        try await Task.sleep(nanoseconds: 1_500_000_000)

        guard let index = mediaItems.firstIndex(where: { $0.id == mediaId }) else {
            throw ServiceError.invalidData
        }

        let enhancement = AIEnhancement(type: type)
        mediaItems[index].aiEnhancements.append(enhancement)

        if type == .captionGeneration {
            generatedCaptions[mediaId] = generateCaption(for: mediaItems[index])
        }
    }

    func batchApply(
        _ type: AIEnhancementType,
        to mediaIds: [UUID],
        mediaItems: inout [CreatorMediaItem]
    ) async throws {
        for id in mediaIds {
            try await applyEnhancement(type, to: id, mediaItems: &mediaItems)
        }
    }

    func isProcessing(_ mediaId: UUID) -> Bool {
        processingItems.contains(mediaId)
    }

    private func generateCaption(for item: CreatorMediaItem) -> String {
        let captions = [
            "New drop just for my fans 🔥 #AixcamCreator",
            "Behind the scenes magic ✨ What do you think?",
            "Exclusive content you won't find anywhere else 💎",
            "Living my best creator life 🎬 Tap in!",
            "This one's special — made with love for my community ❤️"
        ]
        let index = abs(item.title.hashValue) % captions.count
        return captions[index]
    }
}
