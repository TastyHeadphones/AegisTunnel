import Foundation
import Security
import AegisCore

public enum KeychainSecretStoreError: Error, Sendable {
    case unexpectedStatus(OSStatus)
    case invalidSecretEncoding
}

public actor KeychainSecretStore: SecretStore {
    private let service: String

    public init(service: String) {
        self.service = service
    }

    public func store(secret: String, for id: UUID) async throws {
        let baseQuery = query(for: id)

        let deleteStatus = SecItemDelete(baseQuery as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            throw KeychainSecretStoreError.unexpectedStatus(deleteStatus)
        }

        var addQuery = baseQuery
        addQuery[kSecValueData as String] = Data(secret.utf8)

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        guard addStatus == errSecSuccess else {
            throw KeychainSecretStoreError.unexpectedStatus(addStatus)
        }
    }

    public func load(id: UUID) async throws -> String? {
        var loadQuery = query(for: id)
        loadQuery[kSecReturnData as String] = kCFBooleanTrue
        loadQuery[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: CFTypeRef?
        let status = SecItemCopyMatching(loadQuery as CFDictionary, &result)

        if status == errSecItemNotFound {
            return nil
        }

        guard status == errSecSuccess else {
            throw KeychainSecretStoreError.unexpectedStatus(status)
        }

        guard
            let data = result as? Data,
            let secret = String(data: data, encoding: .utf8)
        else {
            throw KeychainSecretStoreError.invalidSecretEncoding
        }

        return secret
    }

    public func delete(id: UUID) async throws {
        let status = SecItemDelete(query(for: id) as CFDictionary)

        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw KeychainSecretStoreError.unexpectedStatus(status)
        }
    }

    private func query(for id: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: id.uuidString,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
    }
}
