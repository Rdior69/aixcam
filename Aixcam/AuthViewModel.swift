import CryptoKit
import Foundation
import Security

struct Member: Codable, Identifiable, Equatable {
    let id: UUID
    let name: String
    let email: String
    let accountType: AccountType
    let createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        email: String,
        accountType: AccountType,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.email = email
        self.accountType = accountType
        self.createdAt = createdAt
    }
}

enum AccountType: String, CaseIterable, Codable, Identifiable {
    case creator = "Creator"
    case fan = "Fan or member"
    case brand = "Brand partner"

    var id: String { rawValue }
}

enum AuthStatus: Equatable {
    case idle
    case success(String)
    case error(String)
}

final class AuthViewModel: ObservableObject {
    @Published private(set) var members: [Member] = []
    @Published private(set) var currentMember: Member?
    @Published var status: AuthStatus = .idle

    private let storageKey = "aixcam.members"
    private let memberStore: SecureMemberStoring
    private var storedMembers: [StoredMember] = []

    var isAuthenticated: Bool {
        currentMember != nil
    }

    init(memberStore: SecureMemberStoring = KeychainMemberStore()) {
        self.memberStore = memberStore
        loadMembers()
    }

    @discardableResult
    func signUp(name: String, email: String, accountType: AccountType, password: String) -> Bool {
        let cleanedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanedEmail = normalize(email)

        guard validate(name: cleanedName, email: cleanedEmail, password: password) else {
            return false
        }

        guard storedMembers.contains(where: { $0.member.email == cleanedEmail }) == false else {
            status = .error("That email is already signed up. Please log in instead.")
            return false
        }

        let member = Member(name: cleanedName, email: cleanedEmail, accountType: accountType)
        let salt = Self.makeSalt()
        let storedMember = StoredMember(
            member: member,
            passwordSalt: salt.base64EncodedString(),
            passwordHash: Self.hash(password: password, salt: salt)
        )

        let previousMembers = storedMembers
        storedMembers.append(storedMember)
        guard saveMembers() else {
            storedMembers = previousMembers
            refreshMembers()
            return false
        }

        currentMember = member
        status = .success("Your Aixcam account was created and you are signed in.")
        return true
    }

    @discardableResult
    func login(email: String, password: String) -> Bool {
        let cleanedEmail = normalize(email)

        guard validate(email: cleanedEmail, password: password) else {
            return false
        }

        guard let storedMember = storedMembers.first(where: { $0.member.email == cleanedEmail }) else {
            status = .error("We could not find that member email. Create a new account to join Aixcam.")
            return false
        }

        guard Self.verify(password: password, storedMember: storedMember) else {
            status = .error("That password does not match this Aixcam account.")
            return false
        }

        currentMember = storedMember.member
        status = .success("Welcome back, \(storedMember.member.name).")
        return true
    }

    func logout() {
        currentMember = nil
        status = .idle
    }

    @discardableResult
    func deleteCurrentAccount() -> Bool {
        guard let currentMember else {
            status = .error("Log in before deleting an account.")
            return false
        }

        let previousMembers = storedMembers
        storedMembers.removeAll { $0.member.email == currentMember.email }
        guard saveMembers() else {
            storedMembers = previousMembers
            refreshMembers()
            return false
        }

        self.currentMember = nil
        status = .success("Your Aixcam account was deleted from this device.")
        return true
    }

    func resetStatus() {
        status = .idle
    }

    private func validate(name: String, email: String, password: String) -> Bool {
        guard name.isEmpty == false else {
            status = .error("Enter your full name to create an account.")
            return false
        }

        return validate(email: email, password: password)
    }

    private func validate(email: String, password: String) -> Bool {
        let emailPattern = #"^[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}$"#
        let emailRange = email.range(of: emailPattern, options: [.regularExpression, .caseInsensitive])
        guard emailRange == email.startIndex..<email.endIndex else {
            status = .error("Enter a valid email address.")
            return false
        }

        guard password.count >= 8 else {
            status = .error("Use a password with at least 8 characters.")
            return false
        }

        return true
    }

    private func normalize(_ email: String) -> String {
        email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func loadMembers() {
        guard let data = memberStore.loadData(for: storageKey) else {
            refreshMembers()
            return
        }

        do {
            storedMembers = try JSONDecoder().decode([StoredMember].self, from: data)
        } catch {
            storedMembers = []
        }

        refreshMembers()
    }

    private func saveMembers() -> Bool {
        do {
            let data = try JSONEncoder().encode(storedMembers)
            if storedMembers.isEmpty {
                try memberStore.deleteData(for: storageKey)
            } else {
                try memberStore.saveData(data, for: storageKey)
            }
            refreshMembers()
            return true
        } catch {
            status = .error("We could not save the new member account. Please try again.")
            return false
        }
    }

    private func refreshMembers() {
        members = storedMembers.map(\.member)
    }

    private static func makeSalt() -> Data {
        var bytes = [UInt8](repeating: 0, count: 16)
        let status = bytes.withUnsafeMutableBytes {
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, $0.baseAddress!)
        }
        if status != errSecSuccess {
            bytes = UUID().uuidString.utf8.map { UInt8($0) }
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

    private static func verify(password: String, storedMember: StoredMember) -> Bool {
        guard let salt = Data(base64Encoded: storedMember.passwordSalt) else {
            return false
        }

        return hash(password: password, salt: salt) == storedMember.passwordHash
    }
}

private struct StoredMember: Codable, Equatable {
    let member: Member
    let passwordSalt: String
    let passwordHash: String
}

protocol SecureMemberStoring {
    func loadData(for key: String) -> Data?
    func saveData(_ data: Data, for key: String) throws
    func deleteData(for key: String) throws
}

enum SecureMemberStoreError: Error {
    case unexpectedStatus(OSStatus)
}

final class KeychainMemberStore: SecureMemberStoring {
    private let service: String

    init(service: String = Bundle.main.bundleIdentifier ?? "com.aixcam.app") {
        self.service = service
    }

    func loadData(for key: String) -> Data? {
        var query = baseQuery(for: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess else {
            return nil
        }

        return item as? Data
    }

    func saveData(_ data: Data, for key: String) throws {
        let query = baseQuery(for: key)
        let attributes: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess {
            return
        }

        guard updateStatus == errSecItemNotFound else {
            throw SecureMemberStoreError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SecureMemberStoreError.unexpectedStatus(addStatus)
        }
    }

    func deleteData(for key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureMemberStoreError.unexpectedStatus(status)
        }
    }

    private func baseQuery(for key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
