import Foundation
import Security

enum CredentialsStore {
    private static let service = "com.fuhaotong.macmate"
    private static let account = "apiKey"
    private static let fileManager = FileManager.default

    // MARK: - Legacy file migration

    private static var legacyFileURL: URL {
        AppConstants.applicationSupportDirectory.appendingPathComponent("credentials.json")
    }

    private static func migrateFromLegacyFile() {
        let url = legacyFileURL
        guard fileManager.fileExists(atPath: url.path) else { return }
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            try? fileManager.removeItem(at: url)
            return
        }
        _ = writeAPIKey(payload.apiKey)
        try? fileManager.removeItem(at: url)
    }

    private struct Payload: Codable {
        var apiKey: String
    }

    // MARK: - Keychain access

    static func readAPIKey() -> String {
        migrateFromLegacyFile()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return ""
        }
        return key
    }

    @discardableResult
    static func writeAPIKey(_ value: String) -> Bool {
        migrateFromLegacyFile()

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        if value.isEmpty { return true }

        guard let data = value.data(using: .utf8) else { return false }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
}
