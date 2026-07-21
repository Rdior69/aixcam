import Foundation
import SwiftUI
import UIKit

@MainActor
final class CreatorHomeViewModel: ObservableObject {
    @Published private(set) var draft: CreatorOnboardingDraft?
    @Published private(set) var isLoading = false
    @Published var errorMessage = ""
    @Published var statusMessage = ""

    let user: AppUser
    private let backendService: CreatorBackendServicing

    init(
        user: AppUser,
        backendService: CreatorBackendServicing = CreatorBackendFactory.makeService()
    ) {
        self.user = user
        self.backendService = backendService
    }

    var displayName: String {
        let name = draft?.profile.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return name.isEmpty ? user.name : name
    }

    var username: String {
        let value = draft?.profile.username.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return value.isEmpty ? "creator" : value
    }

    var publicURL: String {
        if let published = draft?.publishedProfileURL, published.isEmpty == false {
            return published
        }
        let path = draft?.branding.customProfilePath.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let slugSource = path.isEmpty ? username : path
        let slug = CreatorProfileURL.sanitizeSlug(slugSource)
        guard slug.isEmpty == false else {
            return CreatorProfileURL.publicBase
        }
        return CreatorProfileURL.make(slug: slug)
    }

    var dashboard: CreatorDashboardSnapshot {
        draft?.dashboard ?? .empty
    }

    var mediaCount: Int {
        draft?.content.mediaItems.count ?? 0
    }

    var albumCount: Int {
        draft?.content.albums.count ?? 0
    }

    var categoryCount: Int {
        draft?.content.categories.count ?? 0
    }

    var enabledAIToolCount: Int {
        guard let ai = draft?.aiStudio else { return 0 }
        return [
            ai.backgroundRemovalEnabled,
            ai.enhancementEnabled,
            ai.filtersEnabled,
            ai.captionGeneratorEnabled,
            ai.thumbnailGeneratorEnabled,
            ai.upscalingEnabled,
            ai.batchEditingEnabled
        ].filter { $0 }.count
    }

    var membershipSummary: String {
        guard draft?.subscriptions != nil else {
            return "No tiers yet"
        }
        return "Free · Premium · VIP configured"
    }

    func load() {
        guard isLoading == false else { return }
        isLoading = true
        errorMessage = ""

        Task {
            do {
                if let loaded = try await backendService.loadCreatorDraft(userID: user.id) {
                    draft = loaded
                } else {
                    draft = CreatorOnboardingDraft(user: user)
                    errorMessage = "No published draft found yet. Edit setup to refresh your page."
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func copyPublicURL() {
        UIPasteboard.general.string = publicURL
        statusMessage = "Public page link copied."
        Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            if statusMessage == "Public page link copied." {
                statusMessage = ""
            }
        }
    }
}
