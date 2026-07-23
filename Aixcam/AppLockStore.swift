import CryptoKit
import Foundation

struct AppLockPINRecord: Codable, Equatable {
    var salt: String
    var hash: String
}

final class AppLockStore {
    static let policyKey = "aixcam.appLock.policy.v1"
    static let pinKey = "aixcam.appLock.pin.v1"

    private let credentialStore: SecureCredentialStoring
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(credentialStore: SecureCredentialStoring = KeychainCredentialStore()) {
        self.credentialStore = credentialStore
    }

    var hasPIN: Bool {
        loadPINRecord() != nil
    }

    func loadPolicy() -> AppLockPolicy {
        guard let data = credentialStore.loadData(for: Self.policyKey),
              let policy = try? decoder.decode(AppLockPolicy.self, from: data) else {
            return .default
        }
        return policy
    }

    func savePolicy(_ policy: AppLockPolicy) throws {
        let data = try encoder.encode(policy)
        try credentialStore.saveData(data, for: Self.policyKey)
    }

    func setPIN(_ pin: String) throws {
        guard AppLockPolicy.isValidPIN(pin) else {
            throw CreatorBackendError.invalidInput("Use a \(AppLockPolicy.pinLength)-digit PIN.")
        }
        let salt = Self.makeSalt()
        let record = AppLockPINRecord(
            salt: salt.base64EncodedString(),
            hash: Self.hash(pin: pin, salt: salt)
        )
        let data = try encoder.encode(record)
        try credentialStore.saveData(data, for: Self.pinKey)

        var policy = loadPolicy()
        policy.isEnabled = true
        try savePolicy(policy)
    }

    func verifyPIN(_ pin: String) -> Bool {
        guard let record = loadPINRecord(),
              let salt = Data(base64Encoded: record.salt) else {
            return false
        }
        return Self.hash(pin: pin, salt: salt) == record.hash
    }

    func clearPIN() throws {
        try credentialStore.deleteData(for: Self.pinKey)
        var policy = loadPolicy()
        policy.isEnabled = false
        try savePolicy(policy)
    }

    private func loadPINRecord() -> AppLockPINRecord? {
        guard let data = credentialStore.loadData(for: Self.pinKey) else {
            return nil
        }
        return try? decoder.decode(AppLockPINRecord.self, from: data)
    }

    private static func makeSalt(byteCount: Int = 16) -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        if status == errSecSuccess {
            return Data(bytes)
        }
        return Data((0..<byteCount).map { _ in UInt8.random(in: 0...255) })
    }

    private static func hash(pin: String, salt: Data) -> String {
        var data = salt
        data.append(Data(pin.utf8))
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
