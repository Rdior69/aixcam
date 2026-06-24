import Foundation

#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

enum CreatorMediaUploadError: LocalizedError {
    case firebaseUnavailable
    case invalidImageData

    var errorDescription: String? {
        switch self {
        case .firebaseUnavailable:
            return "Firebase Storage is not configured. Add GoogleService-Info.plist and link FirebaseStorage."
        case .invalidImageData:
            return "The selected image could not be uploaded."
        }
    }
}

protocol CreatorMediaUploadServicing {
    func uploadProfilePhoto(data: Data, profileID: String) async throws -> URL
    func uploadCoverImage(data: Data, profileID: String) async throws -> URL
}

final class FirebaseCreatorMediaService: CreatorMediaUploadServicing {
#if canImport(FirebaseStorage)
    private let storage: Storage

    init(storage: Storage = Storage.storage()) {
        self.storage = storage
    }
#else
    init() {}
#endif

    func uploadProfilePhoto(data: Data, profileID: String) async throws -> URL {
        try await upload(data: data, path: "creatorProfiles/\(profileID)/profilePhoto.jpg", contentType: "image/jpeg")
    }

    func uploadCoverImage(data: Data, profileID: String) async throws -> URL {
        try await upload(data: data, path: "creatorProfiles/\(profileID)/coverImage.jpg", contentType: "image/jpeg")
    }

    private func upload(data: Data, path: String, contentType: String) async throws -> URL {
#if canImport(FirebaseStorage)
        guard data.isEmpty == false else {
            throw CreatorMediaUploadError.invalidImageData
        }

        let metadata = StorageMetadata()
        metadata.contentType = contentType

        let reference = storage.reference(withPath: path)
        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL()
#else
        _ = data
        _ = path
        _ = contentType
        throw CreatorMediaUploadError.firebaseUnavailable
#endif
    }
}
