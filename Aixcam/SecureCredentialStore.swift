import Foundation
import Security

protocol SecureCredentialStoring {
    func loadData(for key: String) -> Data?
    func saveData(_ data: Data, for key: String) throws
    func deleteData(for key: String) throws
}

enum SecureCredentialStoreError: Error {
    case unexpectedStatus(OSStatus)
}

final class KeychainCredentialStore: SecureCredentialStoring {
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
            throw SecureCredentialStoreError.unexpectedStatus(updateStatus)
        }

        var addQuery = query
        attributes.forEach { addQuery[$0.key] = $0.value }
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw SecureCredentialStoreError.unexpectedStatus(addStatus)
        }
    }

    func deleteData(for key: String) throws {
        let status = SecItemDelete(baseQuery(for: key) as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecureCredentialStoreError.unexpectedStatus(status)
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

final class MemoryCredentialStore: SecureCredentialStoring {
    private(set) var dataByKey: [String: Data] = [:]

    func loadData(for key: String) -> Data? {
        dataByKey[key]
    }

    func saveData(_ data: Data, for key: String) throws {
        dataByKey[key] = data
    }

    func deleteData(for key: String) throws {
        dataByKey.removeValue(forKey: key)
    }
}
