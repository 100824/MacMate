import AppKit
import Foundation

@MainActor
final class DiagnosticsManager: ObservableObject {
    @Published private(set) var previousRunEndedUnexpectedly = false
    @Published var lastExportMessage = ""

    private let markerURL = AppConstants.applicationSupportDirectory.appendingPathComponent("running.session")
    private let fileManager = FileManager.default

    func beginSession() {
        try? fileManager.createDirectory(
            at: AppConstants.applicationSupportDirectory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        previousRunEndedUnexpectedly = fileManager.fileExists(atPath: markerURL.path)
        fileManager.createFile(atPath: markerURL.path, contents: Data(Date().description.utf8), attributes: [.posixPermissions: 0o600])
        FileLogger.shared.info(.diagnostics, "session_started previous_abnormal=\(previousRunEndedUnexpectedly)")
    }

    func endSession() {
        try? fileManager.removeItem(at: markerURL)
        FileLogger.shared.info(.diagnostics, "session_ended_cleanly")
    }

    func exportDiagnostics(settings: AppSettings, accessibilityTrusted: Bool, inputMonitoringTrusted: Bool) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "MacMate-Diagnostics-\(Self.timestamp()).zip"
        panel.allowedContentTypes = [.zip]
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        do {
            try createArchive(
                at: destination,
                settings: settings,
                accessibilityTrusted: accessibilityTrusted,
                inputMonitoringTrusted: inputMonitoringTrusted
            )
            lastExportMessage = "诊断包已导出"
        } catch {
            lastExportMessage = "导出失败：\(error.localizedDescription)"
            FileLogger.shared.error(.diagnostics, "export_failed type=\(String(describing: type(of: error)))")
        }
    }

    private func createArchive(
        at destination: URL,
        settings: AppSettings,
        accessibilityTrusted: Bool,
        inputMonitoringTrusted: Bool
    ) throws {
        let staging = fileManager.temporaryDirectory.appendingPathComponent("MacMateDiagnostics-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        defer { try? fileManager.removeItem(at: staging) }

        let summary = """
        MacMate version: \(AppConstants.version)
        macOS version: \(ProcessInfo.processInfo.operatingSystemVersionString)
        Architecture: arm64
        Accessibility trusted: \(accessibilityTrusted)
        Input Monitoring trusted: \(inputMonitoringTrusted)
        Base URL host: \(URL(string: settings.baseURL)?.host ?? "invalid")
        Model configured: \(!settings.model.isEmpty)
        API key configured: \(!settings.apiKey.isEmpty)
        Auto bubble: \(settings.autoBubbleEnabled)
        Clipboard paused: \(settings.clipboardPaused)
        """
        try Data(summary.utf8).write(to: staging.appendingPathComponent("summary.txt"), options: .atomic)

        if fileManager.fileExists(atPath: AppConstants.logsDirectory.path) {
            try fileManager.copyItem(at: AppConstants.logsDirectory, to: staging.appendingPathComponent("Logs"))
        }
        let crashFolder = staging.appendingPathComponent("CrashReports", isDirectory: true)
        let reports = matchingCrashReports()
        if !reports.isEmpty {
            try fileManager.createDirectory(at: crashFolder, withIntermediateDirectories: true)
            for report in reports.prefix(5) {
                try? fileManager.copyItem(at: report, to: crashFolder.appendingPathComponent(report.lastPathComponent))
            }
        }

        try? fileManager.removeItem(at: destination)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-c", "-k", "--sequesterRsrc", "--keepParent", staging.path, destination.path]
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw CocoaError(.fileWriteUnknown)
        }
        FileLogger.shared.info(.diagnostics, "export_succeeded reports=\(reports.count)")
    }

    private func matchingCrashReports() -> [URL] {
        let reportsRoot = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Logs/DiagnosticReports")
        let urls = (try? fileManager.contentsOfDirectory(at: reportsRoot, includingPropertiesForKeys: [.contentModificationDateKey])) ?? []
        return urls
            .filter { $0.lastPathComponent.hasPrefix("MacMate") && ($0.pathExtension == "ips" || $0.pathExtension == "crash") }
            .sorted {
                let left = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let right = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return left > right
            }
    }

    private static func timestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
