import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

protocol CreatorProfileServicing {
    func fetchProfile(for id: String) async throws -> CreatorProfile?
    func saveProfile(_ profile: CreatorProfile) async throws
}

final class FirebaseCreatorProfileService: CreatorProfileServicing {
#if canImport(FirebaseFirestore)
    private let collection: CollectionReference

    init(collection: CollectionReference = Firestore.firestore().collection("creatorProfiles")) {
        self.collection = collection
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
}
