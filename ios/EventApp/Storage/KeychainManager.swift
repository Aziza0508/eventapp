import Foundation
import Security

/// KeychainManager securely stores JWT access and refresh tokens.
final class KeychainManager {
    static let shared = KeychainManager()
    private let service = "com.eventapp.tokens"
    private let accessKey = "access_token"
    private let refreshKey = "refresh_token"

    private init() {}

    // MARK: - Access Token

    func saveToken(_ token: String) {
        save(key: accessKey, value: token)
    }

    func loadToken() -> String? {
        load(key: accessKey)
    }

    func deleteToken() {
        delete(key: accessKey)
    }

    // MARK: - Refresh Token

    func saveRefreshToken(_ token: String) {
        save(key: refreshKey, value: token)
    }

    func loadRefreshToken() -> String? {
        load(key: refreshKey)
    }

    func deleteRefreshToken() {
        delete(key: refreshKey)
    }

    // MARK: - Clear All

    func clearAll() {
        deleteToken()
        deleteRefreshToken()
    }

    // MARK: - Generic Keychain Ops

    private func save(key: String, value: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData:   data
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private func load(key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:           kSecClassGenericPassword,
            kSecAttrService:     service,
            kSecAttrAccount:     key,
            kSecReturnData:      true,
            kSecMatchLimit:      kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let token = String(data: data, encoding: .utf8) else {
            return nil
        }
        return token
    }

    private func delete(key: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}
