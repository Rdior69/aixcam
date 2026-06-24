import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif
#if canImport(FirebaseStorage)
import FirebaseStorage
#endif

protocol CreatorProfileServicing {
    func fetchProfile(for id: String) async throws -> CreatorProfile?
    func saveProfile(_ profile: CreatorProfile) async throws
    func uploadImage(data: Data, path: String, contentType: String) async throws -> URL?
}

final class FirebaseCreatorProfileService: CreatorProfileServicing {
#if canImport(FirebaseFirestore)
    private let collection: CollectionReference
#endif
#if canImport(FirebaseStorage)
    private let storageRoot: StorageReference
#endif

#if canImport(FirebaseFirestore) && canImport(FirebaseStorage)
    init(
        collection: CollectionReference = Firestore.firestore().collection("creatorProfiles"),
        storageRoot: StorageReference = Storage.storage().reference().child("creatorProfiles")
    ) {
        self.collection = collection
        self.storageRoot = storageRoot
    }
#elseif canImport(FirebaseFirestore)
    init(collection: CollectionReference = Firestore.firestore().collection("creatorProfiles")) {
        self.collection = collection
    }
#elseif canImport(FirebaseStorage)
    init(storageRoot: StorageReference = Storage.storage().reference().child("creatorProfiles")) {
        self.storageRoot = storageRoot
    }
#else
    init() {}
#endif

    func fetchProfile(for id: String) async throws -> CreatorProfile? {
#if canImport(FirebaseFirestore)
        let snapshot = try await collection.document(id).getDocument()
        guard let data = snapshot.data() else {
            return nil
        }

        return CreatorProfile(firebaseData: data)
#else
        return nil
#endif
    }

    func saveProfile(_ profile: CreatorProfile) async throws {
#if canImport(FirebaseFirestore)
        try await collection.document(profile.id).setData(profile.firebaseData, merge: true)
#else
        _ = profile
#endif
    }

    func uploadImage(data: Data, path: String, contentType: String) async throws -> URL? {
#if canImport(FirebaseStorage)
        let metadata = StorageMetadata()
        metadata.contentType = contentType
        let reference = storageRoot.child(path)
        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL()
#else
        _ = data
        _ = path
        _ = contentType
        return nil
#endif
    }
}
