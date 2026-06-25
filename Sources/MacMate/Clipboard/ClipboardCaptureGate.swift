import Foundation

final class ClipboardCaptureGate: @unchecked Sendable {
    static let shared = ClipboardCaptureGate()

    private let lock = NSLock()
    private var suppressedUntil = Date.distantPast

    func suppress(for interval: TimeInterval) {
        lock.lock()
        suppressedUntil = max(suppressedUntil, Date().addingTimeInterval(interval))
        lock.unlock()
    }

    var isSuppressed: Bool {
        lock.lock()
        defer { lock.unlock() }
        return Date() < suppressedUntil
    }
}
