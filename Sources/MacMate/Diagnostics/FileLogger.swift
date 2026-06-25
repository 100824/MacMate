import Foundation
import OSLog

enum LogCategory: String {
    case app
    case permissions
    case hotKey
    case accessibility
    case clipboard
    case network
    case diagnostics
}

final class FileLogger: @unchecked Sendable {
    static let shared = FileLogger()

    private let lock = NSLock()
    private let subsystem = AppConstants.bundleIdentifier
    private let fileManager = FileManager.default
    private let maximumFileSize: UInt64 = 2 * 1_048_576
    private let maximumFiles = 5

    private init() {
        try? fileManager.createDirectory(
            at: AppConstants.logsDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
    }

    func info(_ category: LogCategory, _ message: String) {
        write(level: "INFO", category: category, message: message)
    }

    func error(_ category: LogCategory, _ message: String) {
        write(level: "ERROR", category: category, message: message)
    }

    private func write(level: String, category: LogCategory, message: String) {
        let sanitized = sanitize(message)
        Logger(subsystem: subsystem, category: category.rawValue).log(level: level == "ERROR" ? .error : .info, "\(sanitized, privacy: .private(mask: .hash))")
        lock.lock()
        defer { lock.unlock() }
        rotateIfNeeded()
        let formatter = ISO8601DateFormatter()
        let line = "\(formatter.string(from: Date())) [\(level)] [\(category.rawValue)] \(sanitized)\n"
        let url = AppConstants.logsDirectory.appendingPathComponent("macmate.log")
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, contents: nil, attributes: [.posixPermissions: 0o600])
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }

    private func sanitize(_ input: String) -> String {
        var value = input.replacingOccurrences(of: "\n", with: " ")
        if value.count > 500 { value = String(value.prefix(500)) }
        return value
    }

    private func rotateIfNeeded() {
        let active = AppConstants.logsDirectory.appendingPathComponent("macmate.log")
        guard let attributes = try? fileManager.attributesOfItem(atPath: active.path),
              let size = attributes[.size] as? UInt64,
              size >= maximumFileSize else { return }

        let oldest = AppConstants.logsDirectory.appendingPathComponent("macmate.\(maximumFiles - 1).log")
        try? fileManager.removeItem(at: oldest)
        if maximumFiles > 2 {
            for index in stride(from: maximumFiles - 2, through: 1, by: -1) {
                let source = AppConstants.logsDirectory.appendingPathComponent("macmate.\(index).log")
                let target = AppConstants.logsDirectory.appendingPathComponent("macmate.\(index + 1).log")
                if fileManager.fileExists(atPath: source.path) {
                    try? fileManager.moveItem(at: source, to: target)
                }
            }
        }
        try? fileManager.moveItem(at: active, to: AppConstants.logsDirectory.appendingPathComponent("macmate.1.log"))
    }
}
