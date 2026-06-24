import Foundation
import SwiftUI

enum SubscriptionTierKind {
    case free
    case premium
    case vip
}

struct ThemeColorChoice: Identifiable, Equatable {
    let id: String
    let name: String

    static let all: [ThemeColorChoice] = [
        ThemeColorChoice(id: "#14b8a6", name: "Teal"),
        ThemeColorChoice(id: "#f97316", name: "Orange"),
        ThemeColorChoice(id: "#ec4899", name: "Pink"),
        ThemeColorChoice(id: "#8b5cf6", name: "Purple"),
        ThemeColorChoice(id: "#3b82f6", name: "Blue"),
        ThemeColorChoice(id: "#22c55e", name: "Green")
    ]
}

@MainActor
final class CreatorSetupViewModel: ObservableObject {
    @Published var draft: CreatorOnboardingDraft
    @Published var currentStep: CreatorOnboardingStep = .profile
    @Published var isLoading = false
    @Published var isSaving = false
    @Published var isPublishing = false
    @Published var bannerMessage = ""
    @Published var errorMessage = ""
    @Published var publishedProfile: PublishedCreatorProfile?

    @Published var pendingWebsite = ""
    @Published var pendingSocialHandle = ""
    @Published var pendingSocialPlatform: SocialPlatform = .instagram
    @Published var pendingCategory = ""
    @Published var pendingAlbumTitle = ""
    @Published var pendingAlbumDescription = ""
    @Published var pendingBenefit = ""
    @Published var pendingMediaTitle = ""

    let user: AppUser
    let themeColors = ThemeColorChoice.all

    private let backendService: CreatorBackendServicing
    private var draftObserverTask: Task<Void, Never>?

    init(user: AppUser, backendService: CreatorBackendServicing = CreatorBackendFactory.makeService()) {
        self.user = user
        self.backendService = backendService
        self.draft = CreatorOnboardingDraft(user: user)
    }

    deinit {
        draftObserverTask?.cancel()
    }

    var progressValue: Double {
        Double(currentStep.rawValue + 1) / Double(CreatorOnboardingStep.allCases.count)
    }

    var canMoveForward: Bool {
        switch currentStep {
        case .profile:
            return draft.profile.displayName.isEmpty == false
                && draft.profile.username.isEmpty == false
                && draft.profile.aboutMe.isEmpty == false
        case .branding:
            return draft.branding.customProfilePath.isEmpty == false
        case .content:
            return draft.content.mediaItems.isEmpty == false
        case .subscriptions, .aiStudio, .dashboard, .publish:
            return true
        }
    }

    func load() {
        guard isLoading == false else { return }
        isLoading = true
        bannerMessage = ""
        errorMessage = ""

        Task {
            do {
                if let existing = try await backendService.loadCreatorDraft(userID: user.id) {
                    draft = existing
                } else {
                    draft = CreatorOnboardingDraft(user: user)
                    try await backendService.saveCreatorDraft(userID: user.id, draft: draft)
                }
                attachRealtimeDraftObserver()
            } catch {
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }

    func nextStep() {
        guard canMoveForward else {
            errorMessage = "Complete required fields before continuing."
            return
        }
        guard let next = CreatorOnboardingStep(rawValue: currentStep.rawValue + 1) else {
            return
        }
        withAnimation(.smooth) {
            currentStep = next
        }
    }

    func previousStep() {
        guard let previous = CreatorOnboardingStep(rawValue: currentStep.rawValue - 1) else {
            return
        }
        withAnimation(.smooth) {
            currentStep = previous
        }
    }

    func saveProgress(message: String = "Draft saved.") {
        errorMessage = ""
        isSaving = true
        Task {
            do {
                try await backendService.saveCreatorDraft(userID: user.id, draft: draft)
                bannerMessage = message
            } catch {
                errorMessage = error.localizedDescription
            }
            isSaving = false
        }
    }

    func publish() {
        errorMessage = ""
        bannerMessage = ""
        isPublishing = true
        Task {
            do {
                let published = try await backendService.publishCreatorProfile(userID: user.id, draft: draft)
                publishedProfile = published
                draft.publishedProfileURL = published.publicURL
                bannerMessage = "Creator profile published at \(published.publicURL)"
            } catch {
                errorMessage = error.localizedDescription
            }
            isPublishing = false
        }
    }

    func uploadProfilePhoto(data: Data) {
        uploadAsset(data: data, mediaType: .photo) { [weak self] url in
            self?.draft.profile.profilePhotoURL = url
        }
    }

    func uploadBannerPhoto(data: Data) {
        uploadAsset(data: data, mediaType: .photo) { [weak self] url in
            self?.draft.profile.bannerPhotoURL = url
        }
    }

    func addMediaAsset(data: Data, type: CreatorMediaType, title: String, category: String) {
        uploadAsset(data: data, mediaType: type) { [weak self] url in
            guard let self else { return }
            let normalizedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            let fallbackTitle = type == .photo ? "Photo upload" : "Video upload"
            let mediaItem = CreatorMediaItem(
                title: normalizedTitle.isEmpty ? fallbackTitle : normalizedTitle,
                mediaType: type,
                assetURL: url,
                category: category
            )
            draft.content.mediaItems.append(mediaItem)
            saveProgress(message: "Media uploaded.")
        }
    }

    func moveMedia(from source: IndexSet, to destination: Int) {
        draft.content.mediaItems.move(fromOffsets: source, toOffset: destination)
        saveProgress(message: "Media order updated.")
    }

    func deleteMedia(at offsets: IndexSet) {
        draft.content.mediaItems.remove(atOffsets: offsets)
        saveProgress(message: "Media removed.")
    }

    func addWebsite() {
        let trimmed = pendingWebsite.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        draft.profile.websites.append(trimmed)
        pendingWebsite = ""
        saveProgress()
    }

    func removeWebsite(at offsets: IndexSet) {
        draft.profile.websites.remove(atOffsets: offsets)
        saveProgress()
    }

    func addSocialLink() {
        let trimmed = pendingSocialHandle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        draft.profile.socialLinks.append(
            SocialLink(platform: pendingSocialPlatform, handleOrURL: trimmed)
        )
        pendingSocialHandle = ""
        saveProgress()
    }

    func removeSocialLink(at offsets: IndexSet) {
        draft.profile.socialLinks.remove(atOffsets: offsets)
        saveProgress()
    }

    func addCategory() {
        let trimmed = pendingCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        draft.content.categories.append(trimmed)
        pendingCategory = ""
        saveProgress()
    }

    func addAlbum() {
        let title = pendingAlbumTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let description = pendingAlbumDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        guard title.isEmpty == false else { return }
        draft.content.albums.append(
            CreatorAlbum(title: title, description: description, mediaItemIDs: draft.content.mediaItems.map(\.id))
        )
        pendingAlbumTitle = ""
        pendingAlbumDescription = ""
        saveProgress(message: "Album created.")
    }

    func toggleTier(_ tierKind: SubscriptionTierKind, enabled: Bool) {
        switch tierKind {
        case .free:
            draft.subscriptions.freeTier.isEnabled = enabled
        case .premium:
            draft.subscriptions.premiumTier.isEnabled = enabled
        case .vip:
            draft.subscriptions.vipTier.isEnabled = enabled
        }
        saveProgress()
    }

    func addBenefit(to tierKind: SubscriptionTierKind) {
        let trimmed = pendingBenefit.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty == false else { return }
        switch tierKind {
        case .free:
            draft.subscriptions.freeTier.benefits.append(trimmed)
        case .premium:
            draft.subscriptions.premiumTier.benefits.append(trimmed)
        case .vip:
            draft.subscriptions.vipTier.benefits.append(trimmed)
        }
        pendingBenefit = ""
        saveProgress()
    }

    func removeBenefit(from tierKind: SubscriptionTierKind, at offsets: IndexSet) {
        switch tierKind {
        case .free:
            draft.subscriptions.freeTier.benefits.remove(atOffsets: offsets)
        case .premium:
            draft.subscriptions.premiumTier.benefits.remove(atOffsets: offsets)
        case .vip:
            draft.subscriptions.vipTier.benefits.remove(atOffsets: offsets)
        }
        saveProgress()
    }

    func generateCaptionSuggestion() {
        errorMessage = ""
        Task {
            do {
                let prompt = draft.profile.aboutMe.isEmpty ? draft.profile.displayName : draft.profile.aboutMe
                let suggestion = try await backendService.generateCaptionSuggestion(prompt: prompt)
                draft.aiStudio.latestCaptionSuggestion = suggestion
                saveProgress(message: "AI caption generated.")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func attachRealtimeDraftObserver() {
        draftObserverTask?.cancel()
        draftObserverTask = Task {
            for await remoteDraft in backendService.observeCreatorDraft(userID: user.id) {
                if remoteDraft != draft {
                    draft = remoteDraft
                }
            }
        }
    }

    private func uploadAsset(
        data: Data,
        mediaType: CreatorMediaType,
        onSuccess: @escaping (String) -> Void
    ) {
        errorMessage = ""
        Task {
            do {
                let url = try await backendService.uploadAsset(userID: user.id, data: data, mediaType: mediaType)
                onSuccess(url)
                saveProgress()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
