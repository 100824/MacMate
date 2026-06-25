import AppKit
import Foundation

@MainActor
final class SelectionMonitor {
    var onSelection: ((AccessibleSelection) -> Void)?
    var onDismissRequested: (() -> Void)?
    var isBubbleVisible: (() -> Bool)?

    private let settings: AppSettings
    private let permissions: PermissionManager
    private let accessibility: AccessibilityService
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private var mouseDownPoint = CGPoint.zero
    private var didDrag = false
    private var visibleSelectionText: String?
    private var visibleSelectionSource: AccessibleSelection.Source?

    init(settings: AppSettings, permissions: PermissionManager, accessibility: AccessibilityService) {
        self.settings = settings
        self.permissions = permissions
        self.accessibility = accessibility
    }

    func start() {
        guard globalMonitor == nil else { return }
        let mask: NSEvent.EventTypeMask = [.leftMouseDown, .leftMouseDragged, .leftMouseUp, .rightMouseDown, .keyDown, .scrollWheel]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor in self?.handleGlobal(event) }
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .keyDown, .scrollWheel]) { [weak self] event in
            guard let self else { return event }
            let identifier = event.window?.identifier?.rawValue ?? ""
            if self.isBubbleVisible?() == true, !identifier.hasPrefix("MacMate.Selection") {
                self.dismiss()
            }
            return event
        }
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                if self?.isBubbleVisible?() == true { self?.dismiss() }
            }
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let activationObserver { NSWorkspace.shared.notificationCenter.removeObserver(activationObserver) }
        globalMonitor = nil
        localMonitor = nil
        activationObserver = nil
    }

    func showCurrentSelection() {
        permissions.refresh()
        guard permissions.accessibilityTrusted else { return }
        Task { @MainActor [weak self] in
            guard let self, let selection = await self.accessibility.currentSelectionWithClipboardFallback() else { return }
            self.visibleSelectionText = selection.text
            self.visibleSelectionSource = selection.source
            self.onSelection?(selection)
        }
    }

    private func handleGlobal(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown:
            if isBubbleVisible?() == true { dismiss() }
            mouseDownPoint = NSEvent.mouseLocation
            didDrag = false
        case .leftMouseDragged:
            let point = NSEvent.mouseLocation
            didDrag = didDrag || hypot(point.x - mouseDownPoint.x, point.y - mouseDownPoint.y) >= 3
        case .leftMouseUp:
            guard (didDrag || event.clickCount >= 2), settings.autoBubbleEnabled else { return }
            permissions.refresh()
            guard permissions.accessibilityTrusted, permissions.inputMonitoringTrusted else { return }
            FileLogger.shared.info(.accessibility, "selection_trigger mouse_up drag=\(didDrag) clicks=\(event.clickCount)")
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(120))
                guard let self, let selection = await self.accessibility.currentSelectionWithClipboardFallback() else { return }
                self.visibleSelectionText = selection.text
                self.visibleSelectionSource = selection.source
                self.onSelection?(selection)
            }
        case .rightMouseDown, .keyDown, .scrollWheel:
            if isBubbleVisible?() == true { dismiss() }
        default:
            break
        }
    }

    private func dismiss() {
        visibleSelectionText = nil
        visibleSelectionSource = nil
        onDismissRequested?()
    }
}
