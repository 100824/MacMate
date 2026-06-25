import Foundation

enum CredentialsStore {
    private static let fileName = "credentials.json"
    private static let fileManager = FileManager.default

    private struct Payload: Codable {
        var apiKey: String
    }

    static func readAPIKey() -> String {
        let url = fileURL()
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return ""
        }
        return payload.apiKey
    }

    @discardableResult
    static func writeAPIKey(_ value: String) -> Bool {
        let url = fileURL()
        do {
            try fileManager.createDirectory(
                at: AppConstants.applicationSupportDirectory,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
        } catch {
            return false
        }

        if value.isEmpty {
            try? fileManager.removeItem(at: url)
            return true
        }

        let payload = Payload(apiKey: value)
        guard let data = try? JSONEncoder().encode(payload) else { return false }
        do {
            try data.write(to: url, options: [.atomic])
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableURL = url
            try mutableURL.setResourceValues(values)
            return true
        } catch {
            return false
        }
    }

    private static func fileURL() -> URL {
        AppConstants.applicationSupportDirectory.appendingPathComponent(fileName)
    }
}
