import AppKit
import SwiftUI

@main
enum MacMateMain {
    private static var retainedDelegate: AppDelegate?

    static func main() {
        if ProcessInfo.processInfo.arguments.contains("--self-test") {
            Task { @MainActor in
                let succeeded = await SelfTestRunner.run()
                exit(succeeded ? 0 : 1)
            }
            RunLoop.main.run()
            return
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        retainedDelegate = delegate
        application.delegate = delegate
        application.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate, NSMenuDelegate {
    private let isUIPreview = ProcessInfo.processInfo.arguments.contains("--ui-preview")
        || ProcessInfo.processInfo.arguments.contains("--ui-preview-chinese")
    private let settings = AppSettings()
    private let accessibility = AccessibilityService()
    private lazy var permissions = PermissionManager(accessibilityService: accessibility)
    private let speech = SpeechService()
    private let diagnostics = DiagnosticsManager()
    private let launchAtLogin = LaunchAtLoginManager()
    private let hotKeys = GlobalHotKeyManager()
    private lazy var selectionViewModel = SelectionViewModel(settings: settings, speech: speech)
    private lazy var selectionPanel = SelectionPanelController(viewModel: selectionViewModel)
    private lazy var selectionMonitor = SelectionMonitor(settings: settings, permissions: permissions, accessibility: accessibility)
    private lazy var clipboardManager = ClipboardManager(settings: settings)
    private lazy var clipboardPanel = ClipboardPanelController(manager: clipboardManager)

    private var statusItem: NSStatusItem?
    private var statusMenu: NSMenu?
    private var autoBubbleMenuItem: NSMenuItem?
    private var settingsWindow: NSWindow?
    private var aboutWindow: NSWindow?
    private let settingsWindowState = SettingsWindowState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMainMenu()
        configureIcon()
        diagnostics.beginSession()
        configureStatusItem()
        configureSelection()
        configureHotKeys()
        clipboardManager.start()
        selectionMonitor.start()
        launchAtLogin.registerByDefaultIfNeeded(settings: settings)
        FileLogger.shared.info(.app, "application_started version=\(AppConstants.version)")

        if isUIPreview {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
                let point = NSEvent.mouseLocation
                let previewText = ProcessInfo.processInfo.arguments.contains("--ui-preview-chinese")
                    ? "你好，欢迎使用 MacMate。"
                    : "This is a MacMate selection preview."
                self?.selectionPanel.show(AccessibleSelection(
                    text: previewText,
                    appKitBounds: CGRect(x: point.x - 80, y: point.y, width: 160, height: 20),
                    source: .clipboardFallback
                ))
            }
        }

        let onboardingKey = "onboarding.permissions.shown"
        if !isUIPreview,
           !UserDefaults.standard.bool(forKey: onboardingKey),
           (!permissions.accessibilityTrusted || !permissions.inputMonitoringTrusted) {
            UserDefaults.standard.set(true, forKey: onboardingKey)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
                self?.openSettings(section: .general)
            }
        }
    }

    private func configureMainMenu() {
        let mainMenu = NSMenu(title: "Main Menu")

        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "MacMate")
        applicationMenu.addItem(withTitle: "关于 MacMate", action: #selector(openAboutMenu), keyEquivalent: "")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "设置…", action: #selector(openSettingsMenu), keyEquivalent: ",")
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "退出 MacMate", action: #selector(quit), keyEquivalent: "q")
        applicationMenu.items.forEach { $0.target = self }
        applicationItem.submenu = applicationMenu
        mainMenu.addItem(applicationItem)

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(Self.responderMenuItem(title: "撤销", action: Selector(("undo:")), key: "z"))
        let redo = Self.responderMenuItem(title: "重做", action: Selector(("redo:")), key: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redo)
        editMenu.addItem(.separator())
        editMenu.addItem(Self.responderMenuItem(title: "剪切", action: #selector(NSText.cut(_:)), key: "x"))
        editMenu.addItem(Self.responderMenuItem(title: "复制", action: #selector(NSText.copy(_:)), key: "c"))
        editMenu.addItem(Self.responderMenuItem(title: "粘贴", action: #selector(NSText.paste(_:)), key: "v"))
        editMenu.addItem(Self.responderMenuItem(title: "全选", action: #selector(NSText.selectAll(_:)), key: "a"))
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        NSApp.mainMenu = mainMenu
    }

    private static func responderMenuItem(title: String, action: Selector, key: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = nil
        return item
    }

    func applicationWillTerminate(_ notification: Notification) {
        selectionMonitor.stop()
        clipboardManager.stop()
        diagnostics.endSession()
        FileLogger.shared.info(.app, "application_terminating")
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if isUIPreview { return true }
        if !flag { openSettings(section: .general) }
        return true
    }

    private func configureIcon() {
        if let url = Bundle.main.url(forResource: "MacMate", withExtension: "png")
                    ?? Bundle.module.url(forResource: "MacMate", withExtension: "png", subdirectory: "Icons")
                    ?? Bundle.module.url(forResource: "MacMate", withExtension: "png"),
           let image = NSImage(contentsOf: url) {
            NSApp.applicationIconImage = image
        }
    }

    private func configureSelection() {
        selectionMonitor.onSelection = { [weak self] selection in self?.selectionPanel.show(selection) }
        selectionMonitor.onDismissRequested = { [weak self] in self?.selectionPanel.hide() }
        selectionMonitor.isBubbleVisible = { [weak self] in self?.selectionPanel.isVisible ?? false }
    }

    private func configureHotKeys() {
        hotKeys.onAssistant = { [weak self] in self?.selectionMonitor.showCurrentSelection() }
        hotKeys.onClipboard = { [weak self] in self?.clipboardPanel.show() }
        hotKeys.registerInitial(assistant: settings.assistantShortcut, clipboard: settings.clipboardShortcut)
    }

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "png")
                    ?? Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png", subdirectory: "Icons")
                    ?? Bundle.module.url(forResource: "MenuBarIcon", withExtension: "png"),
           let icon = NSImage(contentsOf: url) {
            icon.size = NSSize(width: 22, height: 22)
            icon.isTemplate = true
            item.button?.image = icon
            item.button?.imageScaling = .scaleProportionallyDown
        } else {
            item.button?.image = NSImage(systemSymbolName: "text.badge.sparkles", accessibilityDescription: "MacMate")
        }
        item.button?.toolTip = "MacMate"
        item.button?.target = self
        item.button?.action = #selector(statusItemClicked(_:))
        item.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        let menu = NSMenu()
        menu.delegate = self
        menu.addItem(withTitle: "显示划词助手", action: #selector(showSelection), keyEquivalent: "")
        menu.addItem(withTitle: "剪贴板历史", action: #selector(showClipboard), keyEquivalent: "")
        menu.addItem(.separator())
        let autoItem = NSMenuItem(title: "自动划词浮标", action: #selector(toggleAutoBubble(_:)), keyEquivalent: "")
        autoBubbleMenuItem = autoItem
        menu.addItem(autoItem)
        menu.addItem(.separator())
        menu.addItem(withTitle: "设置…", action: #selector(openSettingsMenu), keyEquivalent: ",")
        menu.addItem(withTitle: "诊断…", action: #selector(openDiagnosticsMenu), keyEquivalent: "")
        menu.addItem(withTitle: "关于 MacMate", action: #selector(openAboutMenu), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出 MacMate", action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusMenu = menu
        statusItem = item
    }

    @objc private func statusItemClicked(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            guard let statusItem, let statusMenu else { return }
            statusItem.menu = statusMenu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        } else {
            openSettings(section: .general)
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        autoBubbleMenuItem?.state = settings.autoBubbleEnabled ? .on : .off
        autoBubbleMenuItem?.isEnabled = permissions.accessibilityTrusted && permissions.inputMonitoringTrusted
        menu.items.first?.title = "显示划词助手（\(ShortcutDisplay.string(for: settings.assistantShortcut))）"
        if menu.items.count > 1 {
            menu.items[1].title = "剪贴板历史（\(ShortcutDisplay.string(for: settings.clipboardShortcut))）"
        }
    }

    @objc private func showSelection() { selectionMonitor.showCurrentSelection() }
    @objc private func showClipboard() { clipboardPanel.show() }
    @objc private func toggleAutoBubble(_ sender: NSMenuItem) { settings.autoBubbleEnabled.toggle() }
    @objc private func openSettingsMenu() { openSettings(section: .general) }
    @objc private func openDiagnosticsMenu() { openSettings(section: .diagnostics) }
    @objc private func openAboutMenu() { openAbout() }
    @objc private func quit() { NSApp.terminate(nil) }

    private func openSettings(section: SettingsSection) {
        settingsWindowState.section = section
        if settingsWindow == nil {
            let root = SettingsView(
                settings: settings,
                permissions: permissions,
                hotKeys: hotKeys,
                launchAtLogin: launchAtLogin,
                diagnostics: diagnostics,
                windowState: settingsWindowState,
                speechService: speech,
                updateShortcut: { [weak self] action, shortcut in
                    guard let self else { return false }
                    let other = action == .assistant ? self.settings.clipboardShortcut : self.settings.assistantShortcut
                    return self.hotKeys.update(action, shortcut: shortcut, otherShortcut: other)
                }
            )
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 700, height: 560),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = ""
            window.titlebarAppearsTransparent = true
            window.isReleasedWhenClosed = false
            window.center()
            window.contentViewController = NSHostingController(rootView: root)
            window.delegate = self
            settingsWindow = window
        }
        showAuxiliaryWindow(settingsWindow)
    }

    private func openAbout() {
        if aboutWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
                styleMask: [.titled, .closable],
                backing: .buffered,
                defer: false
            )
            window.title = "关于 MacMate"
            window.isReleasedWhenClosed = false
            window.center()
            window.contentViewController = NSHostingController(rootView: AboutView())
            window.delegate = self
            aboutWindow = window
        }
        showAuxiliaryWindow(aboutWindow)
    }

    private func showAuxiliaryWindow(_ window: NSWindow?) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in self?.refreshActivationPolicy() }
    }

    private func refreshActivationPolicy() {
        let hasVisibleAuxiliaryWindow = [settingsWindow, aboutWindow].compactMap { $0 }.contains(where: \.isVisible)
        if !hasVisibleAuxiliaryWindow { NSApp.setActivationPolicy(.accessory) }
    }
}
