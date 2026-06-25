import AppKit
import Carbon
import Combine
import Foundation

enum GlobalHotKeyAction: UInt32, CaseIterable {
    case assistant = 1
    case clipboard = 2

    var title: String { self == .assistant ? "划词助手" : "剪贴板历史" }
}

@MainActor
final class GlobalHotKeyManager: ObservableObject {
    @Published private(set) var errors: [GlobalHotKeyAction: String] = [:]

    var onAssistant: (() -> Void)?
    var onClipboard: (() -> Void)?

    private var eventHandler: EventHandlerRef?
    private var references: [GlobalHotKeyAction: EventHotKeyRef] = [:]
    private var registeredShortcuts: [GlobalHotKeyAction: HotKeyShortcut] = [:]
    private let signature: OSType = 0x4D4D484B // MMHK

    init() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, userData in
                guard let event, let userData else { return noErr }
                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )
                guard status == noErr else { return status }
                let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()
                Task { @MainActor in manager.handle(id: hotKeyID.id) }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
    }

    deinit {
        references.values.forEach { UnregisterEventHotKey($0) }
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    func registerInitial(assistant: HotKeyShortcut, clipboard: HotKeyShortcut) {
        _ = update(.assistant, shortcut: assistant, otherShortcut: clipboard)
        _ = update(.clipboard, shortcut: clipboard, otherShortcut: assistant)
    }

    @discardableResult
    func update(_ action: GlobalHotKeyAction, shortcut: HotKeyShortcut, otherShortcut: HotKeyShortcut) -> Bool {
        if shortcut.enabled, otherShortcut.enabled,
           shortcut.keyCode == otherShortcut.keyCode,
           shortcut.carbonModifiers == otherShortcut.carbonModifiers {
            errors[action] = "与另一个 MacMate 快捷键冲突"
            return false
        }
        let previousShortcut = registeredShortcuts[action]
        let oldReference = references.removeValue(forKey: action)
        if let oldReference { UnregisterEventHotKey(oldReference) }
        guard shortcut.enabled else {
            errors.removeValue(forKey: action)
            registeredShortcuts[action] = shortcut
            return true
        }
        var reference: EventHotKeyRef?
        let identifier = EventHotKeyID(signature: signature, id: action.rawValue)
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &reference
        )
        guard status == noErr, let reference else {
            if let previousShortcut, previousShortcut.enabled {
                var restoredReference: EventHotKeyRef?
                let restoredID = EventHotKeyID(signature: signature, id: action.rawValue)
                if RegisterEventHotKey(
                    previousShortcut.keyCode,
                    previousShortcut.carbonModifiers,
                    restoredID,
                    GetApplicationEventTarget(),
                    0,
                    &restoredReference
                ) == noErr, let restoredReference {
                    references[action] = restoredReference
                }
            }
            errors[action] = "快捷键已被系统或其他应用占用（错误 \(status)）"
            FileLogger.shared.error(.hotKey, "registration_failed action=\(action.rawValue) status=\(status)")
            return false
        }
        references[action] = reference
        registeredShortcuts[action] = shortcut
        errors.removeValue(forKey: action)
        FileLogger.shared.info(.hotKey, "registration_succeeded action=\(action.rawValue)")
        return true
    }

    private func handle(id: UInt32) {
        guard let action = GlobalHotKeyAction(rawValue: id) else { return }
        switch action {
        case .assistant: onAssistant?()
        case .clipboard: onClipboard?()
        }
    }
}

enum ShortcutDisplay {
    static func string(for shortcut: HotKeyShortcut) -> String {
        guard shortcut.enabled else { return "未启用" }
        var value = ""
        if shortcut.carbonModifiers & UInt32(controlKey) != 0 { value += "⌃" }
        if shortcut.carbonModifiers & UInt32(optionKey) != 0 { value += "⌥" }
        if shortcut.carbonModifiers & UInt32(shiftKey) != 0 { value += "⇧" }
        if shortcut.carbonModifiers & UInt32(cmdKey) != 0 { value += "⌘" }
        value += keyName(shortcut.keyCode)
        return value
    }

    static func from(event: NSEvent) -> HotKeyShortcut? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        guard modifiers != 0 else { return nil }
        return HotKeyShortcut(keyCode: UInt32(event.keyCode), carbonModifiers: modifiers, enabled: true)
    }

    private static func keyName(_ code: UInt32) -> String {
        let names: [UInt32: String] = [
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C", 9: "V",
            11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T", 18: "1", 19: "2",
            20: "3", 21: "4", 22: "6", 23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8",
            29: "0", 30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P", 37: "L", 38: "J",
            39: "'", 40: "K", 41: ";", 42: "\\", 43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
            49: "Space", 50: "`", 51: "⌫", 53: "Esc", 123: "←", 124: "→", 125: "↓", 126: "↑"
        ]
        return names[code] ?? "Key \(code)"
    }
}
