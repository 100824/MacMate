import AppKit
import Combine
import CryptoKit
import Foundation

@MainActor
final class ClipboardStore: ObservableObject {
    @Published private(set) var entries: [ClipboardEntry] = []

    private let fileManager: FileManager
    private let rootDirectory: URL
    private let payloadDirectory: URL
    private let metadataURL: URL

    init(fileManager: FileManager = .default, rootDirectory: URL = AppConstants.applicationSupportDirectory.appendingPathComponent("Clipboard", isDirectory: true)) {
        self.fileManager = fileManager
        self.rootDirectory = rootDirectory
        payloadDirectory = rootDirectory.appendingPathComponent("Payloads", isDirectory: true)
        metadataURL = rootDirectory.appendingPathComponent("history.json")
        prepareDirectories()
        load()
    }

    func add(_ capture: ClipboardCapture) {
        if let duplicate = entries.first(where: { $0.contentHash == capture.contentHash }) {
            removePayloads(for: duplicate)
            entries.removeAll { $0.id == duplicate.id }
        }
        let id = UUID()
        var rtfFileName: String?
        var imageFileName: String?
        if let rtf = capture.rtfData {
            let fileName = "\(id.uuidString).rtf"
            if writePayload(rtf, named: fileName) { rtfFileName = fileName }
        }
        if let image = capture.imagePNGData {
            let fileName = "\(id.uuidString).png"
            if writePayload(image, named: fileName) { imageFileName = fileName }
        }
        entries.insert(ClipboardEntry(
            id: id,
            kind: capture.kind,
            sourceApplication: capture.sourceApplication,
            contentHash: capture.contentHash,
            text: capture.text,
            rtfFileName: rtfFileName,
            imageFileName: imageFileName
        ), at: 0)
        while entries.count > AppConstants.clipboardHistoryLimit {
            let removed = entries.removeLast()
            removePayloads(for: removed)
        }
        persist()
        FileLogger.shared.info(.clipboard, "entry_added kind=\(capture.kind.rawValue) history_count=\(entries.count)")
    }

    func remove(_ entry: ClipboardEntry) {
        removePayloads(for: entry)
        entries.removeAll { $0.id == entry.id }
        persist()
    }

    func clear() {
        for entry in entries { removePayloads(for: entry) }
        entries.removeAll()
        persist()
        FileLogger.shared.info(.clipboard, "history_cleared")
    }

    func rtfData(for entry: ClipboardEntry) -> Data? {
        guard let name = entry.rtfFileName else { return nil }
        return try? Data(contentsOf: payloadDirectory.appendingPathComponent(name))
    }

    func imageData(for entry: ClipboardEntry) -> Data? {
        guard let name = entry.imageFileName else { return nil }
        return try? Data(contentsOf: payloadDirectory.appendingPathComponent(name))
    }

    func image(for entry: ClipboardEntry) -> NSImage? {
        imageData(for: entry).flatMap(NSImage.init(data:))
    }

    private func prepareDirectories() {
        try? fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try? fileManager.createDirectory(at: payloadDirectory, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
    }
    private func load() {
        guard let data = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([ClipboardEntry].self, from: data) else { return }
        entries = Array(decoded.prefix(AppConstants.clipboardHistoryLimit)).filter { entry in
            switch entry.kind {
            case .text: return entry.text != nil || entry.rtfFileName != nil
            case .image: return entry.imageFileName != nil
            }
        }
        FileLogger.shared.info(.clipboard, "history_loaded count=\(entries.count)")
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(entries) else { return }
        do {
            try data.write(to: metadataURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: metadataURL.path)
        } catch {
            FileLogger.shared.error(.clipboard, "history_persist_failed type=\(String(describing: type(of: error)))")
        }
    }

    private func writePayload(_ data: Data, named name: String) -> Bool {
        let url = payloadDirectory.appendingPathComponent(name)
        do {
            try data.write(to: url, options: [.atomic, .completeFileProtectionUnlessOpen])
            try? fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            return true
        } catch {
            FileLogger.shared.error(.clipboard, "payload_write_failed bytes=\(data.count)")
            return false
        }
    }

    private func removePayloads(for entry: ClipboardEntry) {
        for name in [entry.rtfFileName, entry.imageFileName].compactMap({ $0 }) {
            try? fileManager.removeItem(at: payloadDirectory.appendingPathComponent(name))
        }
    }
}

enum ClipboardHash {
    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
