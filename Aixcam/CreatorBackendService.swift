import CryptoKit
import Foundation
import Security

struct SignUpPayload {
    var fullName: String
    var email: String
    var password: String
    var accountType: AccountType
}

enum CreatorBackendError: LocalizedError, Equatable {
    case invalidInput(String)
    case duplicateEmail
    case invalidCredentials
    case missingUser
    case uploadFailed
    case unknown

    var errorDescription: String? {
        switch self {
        case .invalidInput(let message):
            return message
        case .duplicateEmail:
            return "That email is already in use."
        case .invalidCredentials:
            return "Your login credentials are invalid."
        case .missingUser:
            return "We could not load your account."
        case .uploadFailed:
            return "Media upload failed. Try again."
        case .unknown:
            return "Something went wrong. Please try again."
        }
    }
}

protocol CreatorBackendServicing {
    func signUp(payload: SignUpPayload) async throws -> AppUser
    func login(email: String, password: String) async throws -> AppUser
    func refreshUser(userID: String) async throws -> AppUser
    func signOut() async throws
    func loadCreatorDraft(userID: String) async throws -> CreatorOnboardingDraft?
    func saveCreatorDraft(userID: String, draft: CreatorOnboardingDraft) async throws
    func observeCreatorDraft(userID: String) -> AsyncStream<CreatorOnboardingDraft>
    func publishCreatorProfile(userID: String, draft: CreatorOnboardingDraft) async throws -> PublishedCreatorProfile
    func uploadAsset(userID: String, data: Data, mediaType: CreatorMediaType) async throws -> String
    func generateCaptionSuggestion(prompt: String) async throws -> String
    func loadSubscriberDraft(userID: String) async throws -> SubscriberOnboardingDraft?
    func saveSubscriberDraft(userID: String, draft: SubscriberOnboardingDraft) async throws
    func completeSubscriberOnboarding(userID: String, draft: SubscriberOnboardingDraft) async throws -> AppUser
}

enum CreatorBackendFactory {
    static func makeService() -> CreatorBackendServicing {
        #if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseStorage) && canImport(FirebaseFunctions) && canImport(FirebaseCore)
        if FirebaseBootstrap.isReadyForFirebaseBackend {
            return FirebaseCreatorBackendService()
        }
        #endif
        return LocalCreatorBackendService.shared
    }

    static var activeKind: CreatorBackendKind {
        FirebaseBootstrap.activeBackendKind
    }
}

enum CreatorProfileURL {
    static let publicBase = "https://aixcam.app/creator"

    static func make(slug: String) -> String {
        "\(publicBase)/\(slug)"
    }

    static func sanitizeSlug(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .replacingOccurrences(of: "_", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
    }
}

@MainActor
final class LocalCreatorBackendService: CreatorBackendServicing {
    static let shared = LocalCreatorBackendService()

    private struct MemberRecord: Codable {
        var user: AppUser
        var passwordSalt: String
        var passwordHash: String
    }

    private let membersStorageKey = "aixcam.members.v3"
    private let draftStorageKey = "aixcam.creatorDrafts.v2"
    private let subscriberDraftStorageKey = "aixcam.subscriberDrafts.v1"
    private let credentialStore: SecureCredentialStoring
    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private var membersByEmail: [String: MemberRecord]
    private var draftsByUserID: [String: CreatorOnboardingDraft]
    private var subscriberDraftsByUserID: [String: SubscriberOnboardingDraft]
    private var draftContinuations: [String: [UUID: AsyncStream<CreatorOnboardingDraft>.Continuation]]

    init(
        credentialStore: SecureCredentialStoring = KeychainCredentialStore(),
        userDefaults: UserDefaults = .standard
    ) {
        self.credentialStore = credentialStore
        self.userDefaults = userDefaults
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        membersByEmail = [:]
        draftsByUserID = [:]
        subscriberDraftsByUserID = [:]
        draftContinuations = [:]
        loadPersistedState()
    }

    func signUp(payload: SignUpPayload) async throws -> AppUser {
        let cleanedName = payload.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = normalizeEmail(payload.email)

        guard cleanedName.isEmpty == false else {
            throw CreatorBackendError.invalidInput("Enter your full name to continue.")
        }

        guard isValidEmail(cleanedEmail) else {
            throw CreatorBackendError.invalidInput("Enter a valid email address.")
        }

        guard payload.password.count >= 8 else {
            throw CreatorBackendError.invalidInput("Use a password with at least 8 characters.")
        }

        guard membersByEmail[cleanedEmail] == nil else {
            throw CreatorBackendError.duplicateEmail
        }

        let salt = Self.makeSalt()
        let newUser = AppUser(
            id: UUID().uuidString,
            name: cleanedName,
            email: cleanedEmail,
            accountType: payload.accountType,
            createdAt: Date(),
            hasPublishedCreatorProfile: false,
            accountStatus: .active,
            hasCompletedSubscriberOnboarding: false
        )
        let memberRecord = MemberRecord(
            user: newUser,
            passwordSalt: salt.base64EncodedString(),
            passwordHash: Self.hash(password: payload.password, salt: salt)
        )
        membersByEmail[cleanedEmail] = memberRecord
        try persistMembers()
        if payload.accountType == .creator {
            draftsByUserID[newUser.id] = CreatorOnboardingDraft(user: newUser)
            persistDrafts()
        } else if payload.accountType.isSubscriberRole {
            subscriberDraftsByUserID[newUser.id] = SubscriberOnboardingDraft(user: newUser)
            persistSubscriberDrafts()
        }
        return newUser
    }

    func login(email: String, password: String) async throws -> AppUser {
        let cleanedEmail = normalizeEmail(email)
        guard let record = membersByEmail[cleanedEmail] else {
            throw CreatorBackendError.invalidCredentials
        }
        guard Self.verify(password: password, record: record) else {
            throw CreatorBackendError.invalidCredentials
        }
        return record.user
    }

    func refreshUser(userID: String) async throws -> AppUser {
        guard let record = memberRecord(for: userID) else {
            throw CreatorBackendError.missingUser
        }
        return record.user
    }

    func signOut() async throws {
        // Local prototype sessions are owned by AuthViewModel.
    }

    func loadCreatorDraft(userID: String) async throws -> CreatorOnboardingDraft? {
        draftsByUserID[userID]
    }

    func saveCreatorDraft(userID: String, draft: CreatorOnboardingDraft) async throws {
        var updated = draft
        updated.lastUpdatedAt = Date()
        draftsByUserID[userID] = updated
        persistDrafts()
        notifyDraftObservers(userID: userID, draft: updated)
    }

    func observeCreatorDraft(userID: String) -> AsyncStream<CreatorOnboardingDraft> {
        AsyncStream { continuation in
            let observerID = UUID()
            var observers = draftContinuations[userID, default: [:]]
            observers[observerID] = continuation
            draftContinuations[userID] = observers

            if let existing = draftsByUserID[userID] {
                continuation.yield(existing)
            }

            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    guard let self else { return }
                    self.draftContinuations[userID]?[observerID] = nil
                    if self.draftContinuations[userID]?.isEmpty == true {
                        self.draftContinuations[userID] = nil
                    }
                }
            }
        }
    }

    func publishCreatorProfile(userID: String, draft: CreatorOnboardingDraft) async throws -> PublishedCreatorProfile {
        guard var member = memberRecord(for: userID)?.user else {
            throw CreatorBackendError.missingUser
        }
        let profilePath = draft.branding.customProfilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let slugSource = profilePath.isEmpty ? draft.profile.username : profilePath
        guard slugSource.isEmpty == false else {
            throw CreatorBackendError.invalidInput("Set a username or custom profile URL before publishing.")
        }
        let slug = CreatorProfileURL.sanitizeSlug(slugSource)
        guard slug.isEmpty == false else {
            throw CreatorBackendError.invalidInput("Set a username or custom profile URL before publishing.")
        }

        let published = PublishedCreatorProfile(
            publicURL: CreatorProfileURL.make(slug: slug),
            publishedAt: Date()
        )

        var updatedDraft = draft
        updatedDraft.publishedProfileURL = published.publicURL
        updatedDraft.lastUpdatedAt = Date()
        draftsByUserID[userID] = updatedDraft
        notifyDraftObservers(userID: userID, draft: updatedDraft)

        member.hasPublishedCreatorProfile = true
        updateMember(member)
        try persistMembers()
        persistDrafts()
        return published
    }

    func uploadAsset(userID: String, data: Data, mediaType: CreatorMediaType) async throws -> String {
        let folderURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("aixcam-assets", isDirectory: true)
            .appendingPathComponent(userID, isDirectory: true)
        try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
        let fileURL = folderURL.appendingPathComponent(UUID().uuidString + (mediaType == .photo ? ".jpg" : ".mov"))
        do {
            try data.write(to: fileURL)
            return fileURL.absoluteString
        } catch {
            throw CreatorBackendError.uploadFailed
        }
    }

    func generateCaptionSuggestion(prompt: String) async throws -> String {
        let normalized = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.isEmpty == false else {
            throw CreatorBackendError.invalidInput("Add a short prompt to generate a caption.")
        }
        let base = normalized.prefix(72)
        return "New drop alert: \(base) - tap in for behind-the-scenes access and premium creator updates."
    }

    func loadSubscriberDraft(userID: String) async throws -> SubscriberOnboardingDraft? {
        subscriberDraftsByUserID[userID]
    }

    func saveSubscriberDraft(userID: String, draft: SubscriberOnboardingDraft) async throws {
        var updated = draft
        updated.lastUpdatedAt = Date()
        subscriberDraftsByUserID[userID] = updated
        persistSubscriberDrafts()
    }

    func completeSubscriberOnboarding(userID: String, draft: SubscriberOnboardingDraft) async throws -> AppUser {
        guard var member = memberRecord(for: userID)?.user else {
            throw CreatorBackendError.missingUser
        }
        let name = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else {
            throw CreatorBackendError.invalidInput("Enter a display name to finish setup.")
        }
        guard draft.interests.isEmpty == false else {
            throw CreatorBackendError.invalidInput("Pick at least one interest.")
        }

        var updatedDraft = draft
        updatedDraft.displayName = name
        updatedDraft.lastUpdatedAt = Date()
        subscriberDraftsByUserID[userID] = updatedDraft
        persistSubscriberDrafts()

        member.name = name
        member.hasCompletedSubscriberOnboarding = true
        updateMember(member)
        try persistMembers()
        return member
    }

    private func isValidEmail(_ email: String) -> Bool {
        let emailPattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        guard let range = email.range(of: emailPattern, options: [.regularExpression, .caseInsensitive]) else {
            return false
        }
        return range == email.startIndex..<email.endIndex
    }

    private func normalizeEmail(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func memberRecord(for userID: String) -> MemberRecord? {
        membersByEmail.values.first(where: { $0.user.id == userID })
    }

    private func updateMember(_ user: AppUser) {
        let email = normalizeEmail(user.email)
        guard var record = membersByEmail[email] else { return }
        record.user = user
        membersByEmail[email] = record
    }

    private func notifyDraftObservers(userID: String, draft: CreatorOnboardingDraft) {
        draftContinuations[userID]?.values.forEach { continuation in
            continuation.yield(draft)
        }
    }

    private func loadPersistedState() {
        if let memberData = credentialStore.loadData(for: membersStorageKey),
           let decoded = try? decoder.decode([String: MemberRecord].self, from: memberData) {
            membersByEmail = decoded
        }

        if let draftData = userDefaults.data(forKey: draftStorageKey),
           let decoded = try? decoder.decode([String: CreatorOnboardingDraft].self, from: draftData) {
            draftsByUserID = decoded
        }

        if let subscriberData = userDefaults.data(forKey: subscriberDraftStorageKey),
           let decoded = try? decoder.decode([String: SubscriberOnboardingDraft].self, from: subscriberData) {
            subscriberDraftsByUserID = decoded
        }
    }

    private func persistMembers() throws {
        if membersByEmail.isEmpty {
            try credentialStore.deleteData(for: membersStorageKey)
            return
        }
        let data = try encoder.encode(membersByEmail)
        try credentialStore.saveData(data, for: membersStorageKey)
    }

    private func persistDrafts() {
        if let data = try? encoder.encode(draftsByUserID) {
            userDefaults.set(data, forKey: draftStorageKey)
        }
    }

    private func persistSubscriberDrafts() {
        if let data = try? encoder.encode(subscriberDraftsByUserID) {
            userDefaults.set(data, forKey: subscriberDraftStorageKey)
        }
    }

    private static func makeSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        let byteCount = bytes.count
        let status = bytes.withUnsafeMutableBytes { buffer in
            SecRandomCopyBytes(kSecRandomDefault, byteCount, buffer.baseAddress!)
        }
        if status != errSecSuccess {
            bytes = Array(UUID().uuidString.utf8)
        }
        return Data(bytes)
    }

    private static func hash(password: String, salt: Data) -> String {
        var input = Data()
        input.append(salt)
        input.append(Data(password.utf8))
        let digest = SHA256.hash(data: input)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private static func verify(password: String, record: MemberRecord) -> Bool {
        guard let salt = Data(base64Encoded: record.passwordSalt) else {
            return false
        }
        return hash(password: password, salt: salt) == record.passwordHash
    }
}

#if canImport(FirebaseAuth) && canImport(FirebaseFirestore) && canImport(FirebaseStorage) && canImport(FirebaseFunctions) && canImport(FirebaseCore)
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
import FirebaseFunctions
import FirebaseStorage

final class FirebaseCreatorBackendService: CreatorBackendServicing {
    private let auth = Auth.auth()
    private let firestore = Firestore.firestore()
    private let storage = Storage.storage()
    private let functions = Functions.functions()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        encoder = JSONEncoder()
        decoder = JSONDecoder()
        encoder.dateEncodingStrategy = .millisecondsSince1970
        decoder.dateDecodingStrategy = .millisecondsSince1970
    }

    func signUp(payload: SignUpPayload) async throws -> AppUser {
        let cleanedName = payload.fullName.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = payload.email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        guard cleanedName.isEmpty == false else {
            throw CreatorBackendError.invalidInput("Enter your full name to continue.")
        }
        guard cleanedEmail.contains("@"), cleanedEmail.contains(".") else {
            throw CreatorBackendError.invalidInput("Enter a valid email address.")
        }
        guard payload.password.count >= 8 else {
            throw CreatorBackendError.invalidInput("Use a password with at least 8 characters.")
        }

        do {
            let result = try await auth.createUser(withEmail: cleanedEmail, password: payload.password)
            let user = AppUser(
                id: result.user.uid,
                name: cleanedName,
                email: cleanedEmail,
                accountType: payload.accountType,
                createdAt: Date(),
                hasPublishedCreatorProfile: false,
                accountStatus: .active,
                hasCompletedSubscriberOnboarding: false
            )
            try await firestore.collection("users").document(user.id).setData(try encodeDictionary(user))
            if payload.accountType == .creator {
                let draft = CreatorOnboardingDraft(user: user)
                try await firestore.collection("creatorDrafts").document(user.id).setData(try encodeDictionary(draft))
            } else if payload.accountType.isSubscriberRole {
                let draft = SubscriberOnboardingDraft(user: user)
                try await firestore.collection("subscriberDrafts").document(user.id).setData(try encodeDictionary(draft))
            }
            return user
        } catch {
            throw mapFirebaseError(error)
        }
    }

    func login(email: String, password: String) async throws -> AppUser {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            let snapshot = try await firestore.collection("users").document(result.user.uid).getDocument()
            guard let data = snapshot.data() else {
                throw CreatorBackendError.missingUser
            }
            return try decodeObject(AppUser.self, from: data)
        } catch let error as CreatorBackendError {
            throw error
        } catch {
            throw mapFirebaseError(error)
        }
    }

    func refreshUser(userID: String) async throws -> AppUser {
        // Session is invalid if Firebase Auth no longer has this user signed in.
        guard let current = auth.currentUser, current.uid == userID else {
            throw CreatorBackendError.missingUser
        }

        do {
            let snapshot = try await firestore.collection("users").document(userID).getDocument()
            guard let data = snapshot.data() else {
                throw CreatorBackendError.missingUser
            }
            return try decodeObject(AppUser.self, from: data)
        } catch let error as CreatorBackendError {
            throw error
        } catch {
            throw mapFirebaseError(error)
        }
    }

    func signOut() async throws {
        do {
            try auth.signOut()
        } catch {
            throw mapFirebaseError(error)
        }
    }

    private func mapFirebaseError(_ error: Error) -> CreatorBackendError {
        FirebaseAuthErrorMapper.map(error) ?? .unknown
    }

    func loadCreatorDraft(userID: String) async throws -> CreatorOnboardingDraft? {
        let snapshot = try await firestore.collection("creatorDrafts").document(userID).getDocument()
        guard let data = snapshot.data() else { return nil }
        return try decodeObject(CreatorOnboardingDraft.self, from: data)
    }

    func saveCreatorDraft(userID: String, draft: CreatorOnboardingDraft) async throws {
        var copy = draft
        copy.lastUpdatedAt = Date()
        try await firestore.collection("creatorDrafts").document(userID).setData(try encodeDictionary(copy), merge: true)
    }

    func observeCreatorDraft(userID: String) -> AsyncStream<CreatorOnboardingDraft> {
        AsyncStream { continuation in
            let listener = firestore.collection("creatorDrafts").document(userID).addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let data = snapshot?.data() else { return }
                if let draft = try? self.decodeObject(CreatorOnboardingDraft.self, from: data) {
                    continuation.yield(draft)
                }
            }
            continuation.onTermination = { _ in
                listener.remove()
            }
        }
    }

    func publishCreatorProfile(userID: String, draft: CreatorOnboardingDraft) async throws -> PublishedCreatorProfile {
        let profilePath = draft.branding.customProfilePath.trimmingCharacters(in: .whitespacesAndNewlines)
        let slugSource = profilePath.isEmpty ? draft.profile.username : profilePath
        guard slugSource.isEmpty == false else {
            throw CreatorBackendError.invalidInput("Set a custom profile URL before publishing.")
        }
        let slug = CreatorProfileURL.sanitizeSlug(slugSource)
        guard slug.isEmpty == false else {
            throw CreatorBackendError.invalidInput("Set a custom profile URL before publishing.")
        }
        let published = PublishedCreatorProfile(
            publicURL: CreatorProfileURL.make(slug: slug),
            publishedAt: Date()
        )

        var draftCopy = draft
        draftCopy.publishedProfileURL = published.publicURL
        draftCopy.lastUpdatedAt = Date()
        try await firestore.collection("creatorDrafts").document(userID).setData(try encodeDictionary(draftCopy), merge: true)
        try await firestore.collection("users").document(userID).setData([
            "hasPublishedCreatorProfile": true
        ], merge: true)
        return published
    }

    func uploadAsset(userID: String, data: Data, mediaType: CreatorMediaType) async throws -> String {
        let fileExtension = mediaType == .photo ? "jpg" : "mov"
        let path = "creators/\(userID)/\(mediaType.rawValue)/\(UUID().uuidString).\(fileExtension)"
        let reference = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = mediaType == .photo ? "image/jpeg" : "video/quicktime"
        _ = try await reference.putDataAsync(data, metadata: metadata)
        return try await reference.downloadURL().absoluteString
    }

    func generateCaptionSuggestion(prompt: String) async throws -> String {
        let payload: [String: Any] = ["prompt": prompt]
        let result = try await functions.httpsCallable("generateCaptionSuggestion").call(payload)
        if let dictionary = result.data as? [String: Any],
           let caption = dictionary["caption"] as? String {
            return caption
        }
        throw CreatorBackendError.unknown
    }

    func loadSubscriberDraft(userID: String) async throws -> SubscriberOnboardingDraft? {
        let snapshot = try await firestore.collection("subscriberDrafts").document(userID).getDocument()
        guard let data = snapshot.data() else { return nil }
        return try decodeObject(SubscriberOnboardingDraft.self, from: data)
    }

    func saveSubscriberDraft(userID: String, draft: SubscriberOnboardingDraft) async throws {
        var copy = draft
        copy.lastUpdatedAt = Date()
        try await firestore.collection("subscriberDrafts").document(userID).setData(try encodeDictionary(copy), merge: true)
    }

    func completeSubscriberOnboarding(userID: String, draft: SubscriberOnboardingDraft) async throws -> AppUser {
        let name = draft.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard name.isEmpty == false else {
            throw CreatorBackendError.invalidInput("Enter a display name to finish setup.")
        }
        guard draft.interests.isEmpty == false else {
            throw CreatorBackendError.invalidInput("Pick at least one interest.")
        }

        var copy = draft
        copy.displayName = name
        copy.lastUpdatedAt = Date()
        try await firestore.collection("subscriberDrafts").document(userID).setData(try encodeDictionary(copy), merge: true)
        try await firestore.collection("users").document(userID).setData([
            "name": name,
            "hasCompletedSubscriberOnboarding": true
        ], merge: true)
        return try await refreshUser(userID: userID)
    }

    private func encodeDictionary<T: Encodable>(_ value: T) throws -> [String: Any] {
        let data = try encoder.encode(value)
        let object = try JSONSerialization.jsonObject(with: data)
        guard let dictionary = object as? [String: Any] else {
            throw CreatorBackendError.unknown
        }
        return dictionary
    }

    private func decodeObject<T: Decodable>(_ type: T.Type, from dictionary: [String: Any]) throws -> T {
        let data = try JSONSerialization.data(withJSONObject: dictionary)
        return try decoder.decode(type, from: data)
    }
}
#endif
