import Foundation

enum AppConstants {
    static let appName = "MacMate"
    static let bundleIdentifier = "com.fuhaotong.macmate"
    static let version = "1.0.0"

    static let maximumInputCharacters = 1_000
    static let maximumOutputCharacters = 2_000
    static let maximumAIExplanationCharacters = 1_000
    static let maximumClipboardTextBytes = 1_048_576
    static let maximumClipboardImageBytes = 20 * 1_048_576
    static let clipboardHistoryLimit = 10

    static var applicationSupportDirectory: URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent(appName, isDirectory: true)
    }

    static var logsDirectory: URL {
        let root = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("Logs/\(appName)", isDirectory: true)
    }
}

extension String {
    func limited(to maximum: Int) -> (text: String, truncated: Bool) {
        guard count > maximum else { return (self, false) }
        return (String(prefix(maximum)), true)
    }

    func limitedWithNotice(to maximum: Int) -> String {
        guard count > maximum else { return self }
        let notice = "\n\n（内容已截断）"
        let prefixLength = max(0, maximum - notice.count)
        return String(prefix(prefixLength)) + notice
    }

    var nonEmptyTrimmed: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}
