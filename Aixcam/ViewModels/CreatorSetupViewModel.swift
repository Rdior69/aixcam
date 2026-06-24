import Combine
import Foundation
import SwiftUI

@MainActor
final class CreatorSetupViewModel: ObservableObject {
    @Published var currentStep: CreatorSetupStep = .profileInformation
    @Published var profile: CreatorProfile
    @Published var mediaItems: [CreatorMediaItem] = []
    @Published var albums: [ContentAlbum] = []
    @Published var analytics: CreatorAnalytics = .preview
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var profilePhotoData: Data?
    @Published var coverPhotoData: Data?
    @Published var selectedMediaIds: Set<UUID> = []
    @Published var draggedMediaId: UUID?

    let aiStudio = AIStudioService()

    private let member: Member
    private var saveTask: Task<Void, Never>?

    init(member: Member) {
        self.member = member
        self.profile = CreatorProfile(
            memberId: member.id,
            displayName: member.name,
            username: member.name
                .lowercased()
                .replacingOccurrences(of: " ", with: "")
                .filter { $0.isLetter || $0.isNumber },
            customProfileURL: member.name
                .lowercased()
                .replacingOccurrences(of: " ", with: "-")
                .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        )

        if member.currentSetupStep > 0,
           let step = CreatorSetupStep(rawValue: member.currentSetupStep) {
            currentStep = step
        }
    }

    func loadExistingData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if let existing = try await CreatorServices.profile.loadProfile(memberId: member.id) {
                profile = existing
            }
            mediaItems = try await CreatorServices.content.loadMedia(memberId: member.id)
            albums = try await CreatorServices.content.loadAlbums(memberId: member.id)
            analytics = try await CreatorServices.analytics.loadAnalytics(creatorId: profile.id)

            if let path = profile.profilePhotoPath,
               let url = CreatorServices.storage.localURL(for: path),
               let data = try? Data(contentsOf: url) {
                profilePhotoData = data
            }
            if let path = profile.coverPhotoPath,
               let url = CreatorServices.storage.localURL(for: path),
               let data = try? Data(contentsOf: url) {
                coverPhotoData = data
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func goToNextStep(authViewModel: AuthViewModel) {
        guard validateCurrentStep() else { return }

        Task {
            await saveProgress()
            authViewModel.updateSetupStep(currentStep.rawValue)

            if let next = currentStep.next {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
                    currentStep = next
                }
            }
        }
    }

    func goToPreviousStep() {
        guard let previous = currentStep.previous else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) {
            currentStep = previous
        }
    }

    func publish(authViewModel: AuthViewModel) async {
        guard validateCurrentStep() else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            try await uploadPhotosIfNeeded()
            try await CreatorServices.profile.publishProfile(profile)
            authViewModel.completeOnboarding()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func saveProgress() async {
        do {
            try await uploadPhotosIfNeeded()
            var updated = profile
            updated.updatedAt = Date()
            try await CreatorServices.profile.saveProfile(updated)
            try await CreatorServices.content.saveMedia(mediaItems, memberId: member.id)
            try await CreatorServices.content.saveAlbums(albums, memberId: member.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func debouncedSave() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            await saveProgress()
        }
    }

    // MARK: - Profile

    func updateUsername(_ value: String) {
        let sanitized = value.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "_" }
        profile.username = String(sanitized.prefix(30))
        if profile.customProfileURL.isEmpty {
            profile.customProfileURL = profile.username
        }
        debouncedSave()
    }

    func addWebsiteLink() {
        profile.websiteLinks.append(WebsiteLink())
        debouncedSave()
    }

    func removeWebsiteLink(_ link: WebsiteLink) {
        profile.websiteLinks.removeAll { $0.id == link.id }
        debouncedSave()
    }

    // MARK: - Content

    func addMedia(data: Data, type: MediaType) async {
        let id = UUID()
        let path = "\(member.id.uuidString)/media/\(id.uuidString).\(type == .video ? "mp4" : "jpg")"

        do {
            if type == .video {
                _ = try await CreatorServices.storage.uploadVideo(data: data, path: path)
            } else {
                _ = try await CreatorServices.storage.uploadImage(data: data, path: path)
            }

            let item = CreatorMediaItem(
                id: id,
                title: "New \(type.rawValue)",
                mediaType: type,
                localPath: path,
                sortOrder: mediaItems.count
            )
            mediaItems.append(item)
            try await CreatorServices.content.saveMedia(mediaItems, memberId: member.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteMedia(_ item: CreatorMediaItem) {
        mediaItems.removeAll { $0.id == item.id }
        if let path = item.localPath {
            Task { try? await CreatorServices.storage.deleteFile(at: path) }
        }
        debouncedSave()
    }

    func moveMedia(from source: IndexSet, to destination: Int) {
        mediaItems.move(fromOffsets: source, toOffset: destination)
        for (index, _) in mediaItems.enumerated() {
            mediaItems[index].sortOrder = index
        }
        debouncedSave()
    }

    func createAlbum(name: String) {
        let album = ContentAlbum(name: name, sortOrder: albums.count)
        albums.append(album)
        debouncedSave()
    }

    func assignToCategory(_ item: CreatorMediaItem, category: ContentCategory) {
        guard let index = mediaItems.firstIndex(where: { $0.id == item.id }) else { return }
        mediaItems[index].category = category
        debouncedSave()
    }

    func assignToAlbum(_ item: CreatorMediaItem, albumId: UUID?) {
        guard let index = mediaItems.firstIndex(where: { $0.id == item.id }) else { return }
        mediaItems[index].albumId = albumId
        debouncedSave()
    }

    // MARK: - AI Studio

    func applyAIEnhancement(_ type: AIEnhancementType, to mediaId: UUID) async {
        do {
            try await aiStudio.applyEnhancement(type, to: mediaId, mediaItems: &mediaItems)
            try await CreatorServices.content.saveMedia(mediaItems, memberId: member.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func batchApplyAIEnhancement(_ type: AIEnhancementType, to mediaIds: [UUID]) async {
        do {
            try await aiStudio.batchApply(type, to: mediaIds, mediaItems: &mediaItems)
            try await CreatorServices.content.saveMedia(mediaItems, memberId: member.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Validation

    func validateCurrentStep() -> Bool {
        errorMessage = nil

        switch currentStep {
        case .profileInformation:
            guard !profile.displayName.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Enter a display name."
                return false
            }
            guard profile.username.count >= 3 else {
                errorMessage = "Username must be at least 3 characters."
                return false
            }
            guard !profile.biography.trimmingCharacters(in: .whitespaces).isEmpty else {
                errorMessage = "Add a short bio to tell fans about yourself."
                return false
            }
        case .creatorBranding:
            guard !profile.customProfileURL.isEmpty else {
                errorMessage = "Choose a custom profile URL."
                return false
            }
        case .contentCreation:
            break
        case .fanSubscriptions:
            if profile.subscriptionTiers.premiumTier.isEnabled {
                guard profile.subscriptionTiers.premiumTier.monthlyPrice > 0 else {
                    errorMessage = "Set a price for the Premium tier."
                    return false
                }
            }
            if profile.subscriptionTiers.vipTier.isEnabled {
                guard profile.subscriptionTiers.vipTier.monthlyPrice > 0 else {
                    errorMessage = "Set a price for the VIP tier."
                    return false
                }
            }
        case .aiStudio, .creatorDashboard, .publish:
            break
        }

        return true
    }

    var canGoForward: Bool {
        switch currentStep {
        case .profileInformation:
            return !profile.displayName.isEmpty && profile.username.count >= 3 && !profile.biography.isEmpty
        case .creatorBranding:
            return !profile.customProfileURL.isEmpty
        default:
            return true
        }
    }

    // MARK: - Private

    private func uploadPhotosIfNeeded() async throws {
        if let data = profilePhotoData {
            let path = "\(member.id.uuidString)/profile/avatar.jpg"
            profile.profilePhotoPath = try await CreatorServices.storage.uploadImage(data: data, path: path)
        }
        if let data = coverPhotoData {
            let path = "\(member.id.uuidString)/profile/cover.jpg"
            profile.coverPhotoPath = try await CreatorServices.storage.uploadImage(data: data, path: path)
        }
    }

    static let themeColors = [
        "14B8A6", "06B6D4", "3B82F6", "8B5CF6", "A855F7",
        "EC4899", "F43F5E", "F97316", "EAB308", "22C55E",
        "6366F1", "0EA5E9"
    ]
}
