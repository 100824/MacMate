import Foundation
import CryptoKit

/// 凭据存储：API Key 使用 AES-GCM 加密后保存到应用 Support 目录下的本地文件，
/// 不存入 macOS Keychain，避免出现在系统“密码本/钥匙串访问”中。
enum CredentialsStore {
    private static let fileManager = FileManager.default

    // MARK: - Paths

    private static var secureDirectory: URL {
        AppConstants.applicationSupportDirectory.appendingPathComponent("secure", isDirectory: true)
    }

    private static var encryptedCredentialsURL: URL {
        secureDirectory.appendingPathComponent("credentials.enc")
    }

    private static var encryptionKeyURL: URL {
        secureDirectory.appendingPathComponent(".key")
    }

    private static var legacyFileURL: URL {
        AppConstants.applicationSupportDirectory.appendingPathComponent("credentials.json")
    }

    // MARK: - Encryption key

    /// 读取或生成 AES-256 密钥。密钥本身只保存在应用私有目录的文件中，
    /// 设置 0o600 权限，不进入系统 Keychain。
    private static func encryptionKey() -> SymmetricKey? {
        ensureSecureDirectory()

        if let data = fileManager.contents(atPath: encryptionKeyURL.path),
           data.count == 32 {
            return SymmetricKey(data: data)
        }

        let key = SymmetricKey(size: .bits256)
        let data = key.withUnsafeBytes { Data($0) }
        guard fileManager.createFile(atPath: encryptionKeyURL.path, contents: data, attributes: [.posixPermissions: 0o600]) else {
            FileLogger.shared.error(.app, "encryption_key_write_failed")
            return nil
        }
        excludeFromBackup(url: encryptionKeyURL)
        return key
    }

    // MARK: - Crypto

    private static func encrypt(_ string: String, using key: SymmetricKey) -> Data? {
        guard let data = string.data(using: .utf8) else { return nil }
        do {
            let sealed = try AES.GCM.seal(data, using: key)
            return sealed.combined
        } catch {
            FileLogger.shared.error(.app, "api_key_encrypt_failed \(error)")
            return nil
        }
    }

    private static func decrypt(_ data: Data, using key: SymmetricKey) -> String? {
        do {
            let sealed = try AES.GCM.SealedBox(combined: data)
            let plaintext = try AES.GCM.open(sealed, using: key)
            return String(data: plaintext, encoding: .utf8)
        } catch {
            FileLogger.shared.error(.app, "api_key_decrypt_failed \(error)")
            return nil
        }
    }

    // MARK: - Public API

    static func readAPIKey() -> String {
        // 一次性迁移旧存储到新的加密文件。
        migrateFromLegacyFile()
        migrateFromKeychain()

        ensureSecureDirectory()
        guard let key = encryptionKey(),
              let data = fileManager.contents(atPath: encryptedCredentialsURL.path),
              !data.isEmpty else {
            return ""
        }
        return decrypt(data, using: key) ?? ""
    }

    @discardableResult
    static func writeAPIKey(_ value: String) -> Bool {
        ensureSecureDirectory()

        if value.isEmpty {
            return deleteAPIKey()
        }

        guard let key = encryptionKey(),
              let data = encrypt(value, using: key) else {
            return false
        }

        do {
            try data.write(to: encryptedCredentialsURL, options: .atomic)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: encryptedCredentialsURL.path)
            excludeFromBackup(url: encryptedCredentialsURL)
            return true
        } catch {
            FileLogger.shared.error(.app, "api_key_file_write_failed \(error)")
            return false
        }
    }

    @discardableResult
    static func deleteAPIKey() -> Bool {
        ensureSecureDirectory()
        do {
            if fileManager.fileExists(atPath: encryptedCredentialsURL.path) {
                try fileManager.removeItem(at: encryptedCredentialsURL)
            }
            return true
        } catch {
            FileLogger.shared.error(.app, "api_key_delete_failed \(error)")
            return false
        }
    }

    // MARK: - Helpers

    private static func ensureSecureDirectory() {
        if !fileManager.fileExists(atPath: secureDirectory.path) {
            do {
                try fileManager.createDirectory(at: secureDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
                excludeFromBackup(url: secureDirectory)
            } catch {
                FileLogger.shared.error(.app, "secure_dir_create_failed \(error)")
            }
        }
    }

    private static func excludeFromBackup(url: URL) {
        var mutableURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? mutableURL.setResourceValues(values)
    }

    // MARK: - Legacy migration

    private struct LegacyPayload: Codable {
        var apiKey: String
    }

    /// 迁移旧版明文 credentials.json 到新加密文件。
    private static func migrateFromLegacyFile() {
        guard fileManager.fileExists(atPath: legacyFileURL.path) else { return }
        guard let data = try? Data(contentsOf: legacyFileURL),
              let payload = try? JSONDecoder().decode(LegacyPayload.self, from: data) else {
            FileLogger.shared.error(.app, "legacy_credentials_decode_failed")
            return
        }
        if writeAPIKey(payload.apiKey) {
            try? fileManager.removeItem(at: legacyFileURL)
            FileLogger.shared.info(.app, "legacy_credentials_migrated")
        } else {
            FileLogger.shared.error(.app, "legacy_credentials_migration_failed")
        }
    }

    /// 迁移旧版 Keychain 凭据到本地加密文件，然后从 Keychain 中删除，
    /// 确保 API Key 不再出现在系统“密码本/钥匙串访问”里。
    private static func migrateFromKeychain() {
        let service = "com.fuhaotong.macmate"
        let account = "apiKey"

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
              let key = String(data: data, encoding: .utf8),
              !key.isEmpty else {
            return
        }

        if writeAPIKey(key) {
            let deleteQuery: [String: Any] = [
                kSecClass as String: kSecClassGenericPassword,
                kSecAttrService as String: service,
                kSecAttrAccount as String: account
            ]
            SecItemDelete(deleteQuery as CFDictionary)
            FileLogger.shared.info(.app, "keychain_credentials_migrated_and_deleted")
        } else {
            FileLogger.shared.error(.app, "keychain_credentials_migration_failed")
        }
    }
}
