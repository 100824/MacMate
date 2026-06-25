import AppKit
import ApplicationServices
import Combine
import CoreGraphics
import Foundation

@MainActor
final class PermissionManager: ObservableObject {
    @Published private(set) var accessibilityTrusted = false
    @Published private(set) var inputMonitoringTrusted = false

    private let accessibilityService: AccessibilityService
    private var refreshTimer: Timer?

    init(accessibilityService: AccessibilityService) {
        self.accessibilityService = accessibilityService
        refresh()
        refreshTimer = .scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func refresh() {
        accessibilityTrusted = accessibilityService.isTrusted()
        inputMonitoringTrusted = CGPreflightListenEventAccess()
    }

    func requestAccessibility() {
        _ = accessibilityService.isTrusted(prompt: true)
        FileLogger.shared.info(.permissions, "accessibility_prompt_requested")
    }

    func requestInputMonitoring() {
        _ = CGRequestListenEventAccess()
        refresh()
        FileLogger.shared.info(.permissions, "input_monitoring_prompt_requested")
    }

    func openAccessibilitySettings() {
        openSystemSettings(anchor: "Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openSystemSettings(anchor: "Privacy_ListenEvent")
    }

    private func openSystemSettings(anchor: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)") else { return }
        NSWorkspace.shared.open(url)
    }
}
