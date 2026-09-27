import Foundation
import Security

// MARK: - CredentialStore Protocol

protocol CredentialStore: Sendable {
    func store(value: String, forKey key: String) throws
    func retrieve(forKey key: String) throws -> String
    func delete(forKey key: String) throws
}

// MARK: - CredentialStoreError

enum CredentialStoreError: LocalizedError {
    case itemNotFound
    case unexpectedData
    case unhandledError(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .itemNotFound:             return "Clé non trouvée dans le Keychain"
        case .unexpectedData:           return "Données inattendues dans le Keychain"
        case .unhandledError(let s):    return "Erreur Keychain : \(s)"
        }
    }
}

// MARK: - KeychainCredentialStore

/// Stockage sécurisé des credentials via iOS Keychain.
/// Ne jamais stocker de secrets dans le code ou dans UserDefaults.
struct KeychainCredentialStore: CredentialStore {
    private let service = "com.zoecarplayplanner.credentials"

    func store(value: String, forKey key: String) throws {
        guard let data = value.data(using: .utf8) else { throw CredentialStoreError.unexpectedData }

        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    key
        ]
        let attributes: [CFString: Any] = [kSecValueData: data]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var newItem = query
            newItem[kSecValueData] = data
            let addStatus = SecItemAdd(newItem as CFDictionary, nil)
            guard addStatus == errSecSuccess else {
                throw CredentialStoreError.unhandledError(status: addStatus)
            }
        } else if status != errSecSuccess {
            throw CredentialStoreError.unhandledError(status: status)
        }
    }

    func retrieve(forKey key: String) throws -> String {
        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrService:    service,
            kSecAttrAccount:    key,
            kSecReturnData:     true,
            kSecMatchLimit:     kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            if status == errSecItemNotFound { throw CredentialStoreError.itemNotFound }
            throw CredentialStoreError.unhandledError(status: status)
        }
        guard let data = result as? Data,
              let string = String(data: data, encoding: .utf8)
        else { throw CredentialStoreError.unexpectedData }
        return string
    }

    func delete(forKey key: String) throws {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CredentialStoreError.unhandledError(status: status)
        }
    }
}
