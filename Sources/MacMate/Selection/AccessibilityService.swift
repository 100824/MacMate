import AppKit
import ApplicationServices
import Foundation

struct AccessibleSelection: Equatable {
    enum Source: Equatable {
        case accessibility
        case clipboardFallback
    }

    let text: String
    let appKitBounds: CGRect
    let source: Source
}

final class AccessibilityService: @unchecked Sendable {
    func isTrusted(prompt: Bool = false) -> Bool {
        if prompt {
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            return AXIsProcessTrustedWithOptions(options)
        }
        return AXIsProcessTrusted()
    }

    @MainActor
    func currentSelection() -> AccessibleSelection? {
        guard isTrusted() else { return nil }
        let systemElement = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(systemElement, kAXFocusedUIElementAttribute as CFString, &focusedValue) == .success,
              let focusedValue,
              CFGetTypeID(focusedValue) == AXUIElementGetTypeID() else {
            return nil
        }
        let focusedElement = unsafeBitCast(focusedValue, to: AXUIElement.self)
        var selectedValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextAttribute as CFString, &selectedValue) == .success,
              let text = selectedValue as? String,
              let trimmed = text.nonEmptyTrimmed else {
            return nil
        }

        var appKitBounds = CGRect(origin: NSEvent.mouseLocation, size: .zero)
        var rangeValue: CFTypeRef?
        if AXUIElementCopyAttributeValue(focusedElement, kAXSelectedTextRangeAttribute as CFString, &rangeValue) == .success,
           let rangeValue,
           CFGetTypeID(rangeValue) == AXValueGetTypeID() {
            var boundsValue: CFTypeRef?
            let result = AXUIElementCopyParameterizedAttributeValue(
                focusedElement,
                kAXBoundsForRangeParameterizedAttribute as CFString,
                rangeValue,
                &boundsValue
            )
            if result == .success, let boundsValue, CFGetTypeID(boundsValue) == AXValueGetTypeID() {
                var quartzBounds = CGRect.zero
                if AXValueGetValue(unsafeBitCast(boundsValue, to: AXValue.self), .cgRect, &quartzBounds) {
                    appKitBounds = Self.convertQuartzToAppKit(quartzBounds)
                }
            }
        }
        FileLogger.shared.info(.accessibility, "selection_read source=ax chars=\(trimmed.count)")
        return AccessibleSelection(text: trimmed, appKitBounds: appKitBounds, source: .accessibility)
    }

    @MainActor
    func currentSelectionWithClipboardFallback() async -> AccessibleSelection? {
        if let selection = currentSelection() { return selection }
        guard isTrusted() else { return nil }
        let pasteboard = NSPasteboard.general
        let snapshot = PasteboardSnapshot(pasteboard: pasteboard)
        let initialChangeCount = pasteboard.changeCount
        ClipboardCaptureGate.shared.suppress(for: 1.5)

        let source = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true)
        let up = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)

        var copiedText: String?
        for _ in 0..<24 {
            try? await Task.sleep(for: .milliseconds(25))
            if pasteboard.changeCount != initialChangeCount {
                copiedText = pasteboard.string(forType: .string)?.nonEmptyTrimmed
                break
            }
        }
        snapshot.restore(to: pasteboard)
        guard let copiedText else {
            FileLogger.shared.info(.accessibility, "selection_read source=clipboard result=empty")
            return nil
        }
        FileLogger.shared.info(.accessibility, "selection_read source=clipboard chars=\(copiedText.count)")
        return AccessibleSelection(
            text: copiedText,
            appKitBounds: CGRect(origin: NSEvent.mouseLocation, size: .zero),
            source: .clipboardFallback
        )
    }

    private static func convertQuartzToAppKit(_ rect: CGRect) -> CGRect {
        guard let primary = NSScreen.screens.first else { return rect }
        return CGRect(x: rect.origin.x, y: primary.frame.maxY - rect.maxY, width: rect.width, height: rect.height)
    }
}

private struct PasteboardSnapshot {
    struct Item {
        let representations: [(NSPasteboard.PasteboardType, Data)]
    }

    let items: [Item]

    init(pasteboard: NSPasteboard) {
        items = (pasteboard.pasteboardItems ?? []).map { item in
            Item(representations: item.types.compactMap { type in
                item.data(forType: type).map { (type, $0) }
            })
        }
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }
        let restoredItems: [NSPasteboardItem] = items.map { item in
            let restored = NSPasteboardItem()
            for (type, data) in item.representations {
                restored.setData(data, forType: type)
            }
            return restored
        }
        pasteboard.writeObjects(restoredItems)
    }
}
