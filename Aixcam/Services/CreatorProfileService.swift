import Foundation

protocol CreatorProfileRepository {
    func loadProfile(memberId: UUID) async throws -> CreatorProfile?
    func saveProfile(_ profile: CreatorProfile) async throws
    func publishProfile(_ profile: CreatorProfile) async throws
    func observeProfile(memberId: UUID, onChange: @escaping (CreatorProfile?) -> Void) -> Any?
}

protocol MediaStorageRepository {
    func uploadImage(data: Data, path: String) async throws -> String
    func uploadVideo(data: Data, path: String) async throws -> String
    func deleteFile(at path: String) async throws
    func localURL(for path: String) -> URL?
}

protocol CreatorContentRepository {
    func loadMedia(memberId: UUID) async throws -> [CreatorMediaItem]
    func saveMedia(_ items: [CreatorMediaItem], memberId: UUID) async throws
    func loadAlbums(memberId: UUID) async throws -> [ContentAlbum]
    func saveAlbums(_ albums: [ContentAlbum], memberId: UUID) async throws
}

protocol AnalyticsRepository {
    func loadAnalytics(creatorId: String) async throws -> CreatorAnalytics
}

// MARK: - Local Implementation (works without Firebase SDK)

final class LocalCreatorProfileRepository: CreatorProfileRepository {
    private let storageKey = "aixcam.creator.profiles"

    func loadProfile(memberId: UUID) async throws -> CreatorProfile? {
        let profiles = loadAllProfiles()
        return profiles.first { $0.memberId == memberId }
    }

    func saveProfile(_ profile: CreatorProfile) async throws {
        var profiles = loadAllProfiles()
        if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
            profiles[index] = profile
        } else {
            profiles.append(profile)
        }
        try persist(profiles)
    }

    func publishProfile(_ profile: CreatorProfile) async throws {
        var updated = profile
        updated.isPublished = true
        updated.updatedAt = Date()
        try await saveProfile(updated)
    }

    func observeProfile(memberId: UUID, onChange: @escaping (CreatorProfile?) -> Void) -> Any? {
        Task {
            let profile = try? await loadProfile(memberId: memberId)
            await MainActor.run { onChange(profile) }
        }
        return nil
    }

    private func loadAllProfiles() -> [CreatorProfile] {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([CreatorProfile].self, from: data)) ?? []
    }

    private func persist(_ profiles: [CreatorProfile]) throws {
        let data = try JSONEncoder().encode(profiles)
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}

final class LocalMediaStorageRepository: MediaStorageRepository {
    private var mediaDirectory: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("AixcamMedia", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func uploadImage(data: Data, path: String) async throws -> String {
        let fileURL = mediaDirectory.appendingPathComponent(path)
        let parent = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
        try data.write(to: fileURL)
        return path
    }

    func uploadVideo(data: Data, path: String) async throws -> String {
        try await uploadImage(data: data, path: path)
    }

    func deleteFile(at path: String) async throws {
        let fileURL = mediaDirectory.appendingPathComponent(path)
        try FileManager.default.removeItem(at: fileURL)
    }

    func localURL(for path: String) -> URL? {
        let fileURL = mediaDirectory.appendingPathComponent(path)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }
}

final class LocalCreatorContentRepository: CreatorContentRepository {
    private func mediaKey(_ memberId: UUID) -> String { "aixcam.media.\(memberId.uuidString)" }
    private func albumsKey(_ memberId: UUID) -> String { "aixcam.albums.\(memberId.uuidString)" }

    func loadMedia(memberId: UUID) async throws -> [CreatorMediaItem] {
        guard let data = UserDefaults.standard.data(forKey: mediaKey(memberId)) else { return [] }
        return (try? JSONDecoder().decode([CreatorMediaItem].self, from: data)) ?? []
    }

    func saveMedia(_ items: [CreatorMediaItem], memberId: UUID) async throws {
        let data = try JSONEncoder().encode(items)
        UserDefaults.standard.set(data, forKey: mediaKey(memberId))
    }

    func loadAlbums(memberId: UUID) async throws -> [ContentAlbum] {
        guard let data = UserDefaults.standard.data(forKey: albumsKey(memberId)) else { return [] }
        return (try? JSONDecoder().decode([ContentAlbum].self, from: data)) ?? []
    }

    func saveAlbums(_ albums: [ContentAlbum], memberId: UUID) async throws {
        let data = try JSONEncoder().encode(albums)
        UserDefaults.standard.set(data, forKey: albumsKey(memberId))
    }
}

final class LocalAnalyticsRepository: AnalyticsRepository {
    func loadAnalytics(creatorId: String) async throws -> CreatorAnalytics {
        .preview
    }
}

// MARK: - Service Factory

enum CreatorServices {
    static let profile: CreatorProfileRepository = LocalCreatorProfileRepository()
    static let storage: MediaStorageRepository = LocalMediaStorageRepository()
    static let content: CreatorContentRepository = LocalCreatorContentRepository()
    static let analytics: AnalyticsRepository = LocalAnalyticsRepository()
}

/*
 Firestore Schema:
 creators/{creatorId}
   - memberId, displayName, username, biography, location
   - websiteLinks[], socialLinks[]
   - profilePhotoURL, coverPhotoURL
   - branding: { themeColorHex, accentColorHex, fontStyle, layoutStyle }
   - subscriptionTiers: { freeTier, premiumTier, vipTier }
   - isPublished, customProfileURL
   - createdAt, updatedAt

 creators/{creatorId}/media/{mediaId}
   - title, mediaType, remoteURL, category, albumId, sortOrder

 creators/{creatorId}/albums/{albumId}
   - name, description, coverMediaId, sortOrder

 Storage Structure:
   creators/{creatorId}/profile/avatar.jpg
   creators/{creatorId}/profile/cover.jpg
   creators/{creatorId}/media/{mediaId}/original
   creators/{creatorId}/media/{mediaId}/thumbnail.jpg
*/
