import Foundation
import Security

enum CredentialStore {
    static func read(_ key: String) -> Data? {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "space.indiehouse.ios",
                                    kSecAttrAccount as String: key,
                                    kSecReturnData as String: true,
                                    kSecMatchLimit as String: kSecMatchLimitOne]
        var value: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &value) == errSecSuccess else { return nil }
        return value as? Data
    }

    static func write(_ data: Data, for key: String) throws {
        delete(key)
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "space.indiehouse.ios",
                                    kSecAttrAccount as String: key,
                                    kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
                                    kSecValueData as String: data]
        guard SecItemAdd(query as CFDictionary, nil) == errSecSuccess else {
            throw IndieError.message(L("error.keychain"))
        }
    }

    static func delete(_ key: String) {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "space.indiehouse.ios",
                                    kSecAttrAccount as String: key]
        SecItemDelete(query as CFDictionary)
    }
}
