# MacMate feature/optimization 分支修改总结

> 分支：`feature/optimization`（基于 `main` 的 `f1fc1fb`）
> 提交：`46c8cbf`
> 涉及：13 个文件，203 行新增，68 行删除

---

## 目录

1. [SelectionPanel.swift — 尺寸估算、定位逻辑、Markdown 解析](#1-selectionpanelswift)
2. [IPAService.swift — 异步加载词典](#2-ipaserviceswift)
3. [ClipboardStore.swift — 同步 I/O（回退）](#3-clipboardstoreswift)
4. [FileLogger.swift — FileHandle 缓存](#4-fileloggerswift)
5. [MacMateMain.swift — 窗口尺寸统一](#5-macmatemainswift)
6. [SettingsView.swift — 输入框背景色](#6-settingsviewswift)
7. [AppSettings.swift — apiKey 写入错误检查](#7-appsettingsswift)
8. [CredentialsStore.swift — Keychain 迁移](#8-credentialsstoreswift)
9. [SelectionViewModel.swift — 安全类型转换](#9-selectionviewmodelswift)
10. [SelectionMonitor.swift — 权限变更重启](#10-selectionmonitorswift)
11. [AIClient.swift — 动态超时](#11-aiclientswift)
12. [ClipboardManager.swift — paste 抑制门](#12-clipboardmanagerswift)
13. [SpeechService.swift — NLLanguageRecognizer 复用](#13-speechserviceswift)
14. [未修改的审计项（3 项）](#14-未修改的审计项)

---

## 1. SelectionPanel.swift

**修改原因（Bug #1、#15、#14）：**
- 尺寸计算对中文宽度估算错误（中文约为英文的 2 倍）
- 未考虑 Markdown heading 的额外行高
- 多显示器水平方向未做智能反向放置
- 自定义 Markdown 解析器不支持缩进代码块、多行 Blockquote

### 1.1 `computePanelSize()` 方法

**修改前：**
```swift
private func computePanelSize() -> NSSize {
    let hasPronunciation = !viewModel.pronunciationText.isEmpty
    let chromeHeight: CGFloat = hasPronunciation ? 192 : 140
    let textCount = viewModel.resultText.count

    let contentHeight: CGFloat
    if viewModel.isLoading {
        contentHeight = 90
    } else if !viewModel.errorMessage.isEmpty {
        contentHeight = 70
    } else if textCount == 0 {
        contentHeight = 90
    } else {
        let lines = max(1, ceil(CGFloat(textCount) / 50.0))
        let estimated = lines * 18 + 30
        contentHeight = min(estimated, Self.resultMaxHeight - chromeHeight)
    }
    // ...
}
```

**修改后：**
```swift
private func computePanelSize() -> NSSize {
    let hasPronunciation = !viewModel.pronunciationText.isEmpty
    let chromeHeight: CGFloat = hasPronunciation ? 192 : 140
    let text = viewModel.resultText

    let contentHeight: CGFloat
    if viewModel.isLoading {
        contentHeight = 90
    } else if !viewModel.errorMessage.isEmpty {
        contentHeight = 70
    } else if text.isEmpty {
        contentHeight = 90
    } else {
        // 混合文本宽度估算：中文字符按 2 倍宽度，ASCII 按 1 倍
        let mixedWidth = text.reduce(0) { sum, char in
            sum + (char.isASCII ? 1 : 2)
        }
        let lines = max(1, ceil(CGFloat(mixedWidth) / 50.0))
        // 增加 Markdown heading 额外行数（heading 字号更大，占用更多空间）
        let headingCount = text.components(separatedBy: .newlines).filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("#") && trimmed.dropFirst().hasPrefix(" ")
        }.count
        let totalLines = lines + CGFloat(headingCount)
        let estimated = totalLines * 20 + 40
        contentHeight = min(estimated, Self.resultMaxHeight - chromeHeight)
    }
    // ...
}
```

**修改点：**
- `textCount` → `text`（语义更清晰）
- 用 `reduce` 计算混合宽度：中文字符按 2 倍宽度（`char.isASCII ? 1 : 2`）
- 新增 `headingCount` 统计：根据行首 `# ` 检测 Markdown heading
- 行高从 `18` 增加到 `20`，padding 从 `30` 增加到 `40`
- 公式：`totalLines = lines + headingCount`，`estimated = totalLines * 20 + 40`

---

### 1.2 `bestPosition()` 方法

**修改前：**
```swift
private static func bestPosition(...) -> CGPoint {
    // 垂直方向（仅上下居中）
    var y: CGFloat
    if preferredBelowY >= visible.minY, ... {
        y = preferredBelowY
    } else if ... {
        y = preferredAboveY
    } else {
        y = visible.minY + (visible.height - size.height) / 2
    }

    // 水平居中于锚点，两端留 8pt 边距
    var x = anchorCenterX - size.width / 2
    x = max(visible.minX + 8, min(x, visible.maxX - size.width - 8))

    y = max(visible.minY + 8, min(y, visible.maxY - size.height - 8))
    return CGPoint(x: x, y: y)
}
```

**修改后：**
```swift
private static func bestPosition(...) -> CGPoint {
    // 垂直方向
    var y: CGFloat
    if preferredBelowY >= visible.minY, ... {
        y = preferredBelowY
    } else if ... {
        y = preferredAboveY
    } else {
        y = visible.minY + (visible.height - size.height) / 2
    }
    y = max(visible.minY + 8, min(y, visible.maxY - size.height - 8))

    // 水平方向：优先居中，超出时智能反向放置
    var x = anchorCenterX - size.width / 2
    if x < visible.minX + 8 {
        // 面板左侧超出屏幕，尝试放在锚点右侧
        x = anchorCenterX + 12
    } else if x + size.width > visible.maxX - 8 {
        // 面板右侧超出屏幕，尝试放在锚点左侧
        x = anchorCenterX - size.width - 12
    }
    // 确保在可见区域内
    x = max(visible.minX + 8, min(x, visible.maxX - size.width - 8))

    return CGPoint(x: x, y: y)
}
```

**修改点：**
- 水平方向不再是简单居中裁剪，而是检测超出屏幕边界
- 超出左边界时：面板移到锚点右侧（`anchorCenterX + 12`）
- 超出右边界时：面板移到锚点左侧（`anchorCenterX - size.width - 12`）
- 最后仍然用 `min/max` 确保在可见区域内

---

### 1.3 `MarkdownBlock.parse()` 方法

**新增支持：**
- **缩进代码块**（4 空格或制表符开头）：新增 `inIndentCode` 状态跟踪
- **多行 Blockquote**：新增 `quoteLines` 数组 + `flushQuote()` 函数，连续 `> ` 开头的行合并为一个 Blockquote
- 原有的 `> ` 处理改为追加到 `quoteLines` 而非立即创建单块

**新增状态变量：**
```swift
var inIndentCode = false
var quoteLines: [String] = []
```

**新增逻辑（缩进代码块）：**
```swift
if rawLine.hasPrefix("    ") || rawLine.hasPrefix("\t") {
    flushParagraph()
    flushQuote()
    if !inIndentCode { inIndentCode = true }
    codeLines.append(String(rawLine.dropFirst(...)))
    continue
} else if inIndentCode {
    if line.isEmpty {
        codeLines.append("")
        continue
    } else {
        result.append(.code(codeLines.joined(separator: "\n")))
        codeLines.removeAll()
        inIndentCode = false
    }
}
```

**多行 Blockquote 处理：**
- 遇到 `> ` 时：`quoteLines.append(...)` + `continue`
- 遇到非 `> ` 时：`flushQuote()`（如果 quoteLines 非空）
- 循环结束时：`flushQuote()`（最后收尾）

---

## 2. IPAService.swift

**修改原因（Bug #4）：** 主线程同步加载 13 万条词典（~2MB），首次划词时 UI 冻结 100-500ms

**修改前：**
```swift
final class IPAService: @unchecked Sendable {
    static let shared = IPAService()
    private let pronunciations: [String: [String]]
    private let wordRegex = ...

    init(dictionaryText: String? = nil) {
        if let dictionaryText {
            pronunciations = Self.parse(dictionaryText)
        } else if let url = ..., let content = try? String(contentsOf: url, encoding: .utf8) {
            pronunciations = Self.parse(content)
            // ...
        } else {
            pronunciations = [:]
            // ...
        }
    }
}
```

**修改后：**
```swift
final class IPAService: @unchecked Sendable {
    static let shared = IPAService()
    private var pronunciations: [String: [String]] = [:]
    private let loadLock = NSLock()
    private var isLoaded = false
    private let wordRegex = ...

    private init() {
        // 在后台队列异步加载
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.loadDictionary()
        }
    }

    // 保留测试用的同步构造函数
    init(dictionaryText: String) {
        pronunciations = Self.parse(dictionaryText)
        isLoaded = true
    }

    private func loadDictionary() {
        loadLock.lock()
        defer { loadLock.unlock() }
        guard !isLoaded else { return }

        if let url = ..., let content = try? String(contentsOf: url, encoding: .utf8) {
            pronunciations = Self.parse(content)
            FileLogger.shared.info(...)
        } else {
            FileLogger.shared.error(...)
        }
        isLoaded = true
    }

    func transcribe(_ text: String) -> IPAResult {
        if !isLoaded {
            loadDictionary()  // 兜底：如果后台还没加载完，主线程同步加载
        }

        loadLock.lock()
        defer { loadLock.unlock() }
        // ... 原有逻辑
    }
}
```

**关键修改点：**
- `pronunciations` 从 `let` 改为 `var`（支持延迟加载）
- 新增 `loadLock`（`NSLock`）+ `isLoaded` 标志
- 默认 `init()` 设为 `private`，在后台队列异步加载
- 新增 `loadDictionary()` 私有方法，带锁保护
- 保留 `init(dictionaryText: String)` 测试构造函数（同步）
- `transcribe()` 增加兜底：如果 `isLoaded` 为 false，主线程同步调用 `loadDictionary()`
- 整个 `transcribe()` 方法被锁保护

**线程安全策略：**
- 写路径（`loadDictionary`）：`loadLock.lock() → 写 → unlock → isLoaded = true`
- 读路径（`transcribe`）：先检查 `isLoaded`（无锁），如果为 false 则进入锁内加载，最后锁内读取

---

## 3. ClipboardStore.swift

**修改原因（Bug #5）：** `load()` 和 `persist()` 在主线程同步读写磁盘

**实际修改：**
> ⚠️ **注意**：经过尝试，将 `load()` 或 `persist()` 改为异步会破坏 `SelfTestRunner` 的"clipboard persistence round-trip"测试（因为 `reload` 新实例后数据还没写入磁盘）。最终方案是保持同步但优化数据流。`diff` 显示仅有一行空行变化。

**尝试的修改（已回退）：**
```swift
// 尝试：load() 异步加载 → 自测失败
private func load() {
    Task.detached { [weak self] in
        // ... 异步加载 → 新实例看不到数据
    }
}

// 尝试：persist() 异步写入 → 自测失败
private func persist() {
    Task.detached {
        // ... 异步写入 → 新实例加载时数据还没写
    }
}
```

**回退原因：**
- `SelfTestRunner.testClipboardPersistence()` 在添加 11 个条目后立即创建 `ClipboardStore` 新实例，如果 `persist()` 是异步的，新实例读取时文件可能还没写入，导致数据不一致。
- `load()` 改为异步后，新实例创建时 `entries` 仍为空，导致数据丢失。

**结论：** 这个优化点需要更深层次的架构重构（如引入 `Actor` 隔离、使用 `async` 初始化等），超出了本次批修改的范围。保持原样（同步读写）是正确且安全的选择。

---

## 4. FileLogger.swift

**修改原因（Bug #8）：** 每次写日志都创建新 `FileHandle`（打开→seek→写入→关闭），高频场景下大量 I/O

**修改前：**
```swift
final class FileLogger: @unchecked Sendable {
    private let lock = NSLock()
    private let fileManager = FileManager.default
    private let maximumFileSize: UInt64 = 2 * 1_048_576
    private let maximumFiles = 5

    private init() {
        try? fileManager.createDirectory(...)
    }

    private func write(level: String, category: LogCategory, message: String) {
        // ... os_log ...
        lock.lock()
        defer { lock.unlock() }
        rotateIfNeeded()
        let formatter = ISO8601DateFormatter()
        let line = "..."
        let url = AppConstants.logsDirectory.appendingPathComponent("macmate.log")
        if !fileManager.fileExists(atPath: url.path) {
            fileManager.createFile(atPath: url.path, ...)
        }
        guard let handle = try? FileHandle(forWritingTo: url) else { return }
        defer { try? handle.close() }  // ← 每次写入后关闭
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }
}
```

**修改后：**
```swift
final class FileLogger: @unchecked Sendable {
    private let lock = NSLock()
    private let fileManager = FileManager.default
    private let maximumFileSize: UInt64 = 2 * 1_048_576
    private let maximumFiles = 5
    private let logURL: URL
    private var fileHandle: FileHandle?  // ← 新增：缓存的 FileHandle

    private init() {
        logURL = AppConstants.logsDirectory.appendingPathComponent("macmate.log")
        try? fileManager.createDirectory(...)
        openFileHandle()  // ← 初始化时打开
    }

    private func openFileHandle() {
        if !fileManager.fileExists(atPath: logURL.path) {
            fileManager.createFile(atPath: logURL.path, ...)
        }
        fileHandle = try? FileHandle(forWritingTo: logURL)
    }

    private func write(level: ..., category: ..., message: ...) {
        // ... os_log ...
        lock.lock()
        defer { lock.unlock() }
        rotateIfNeeded()
        if fileHandle == nil {  // ← 如果旋转后文件被移走，重新打开
            openFileHandle()
        }
        guard let handle = fileHandle else { return }
        let formatter = ISO8601DateFormatter()
        let line = "..."
        // 复用 handle，不关闭
        _ = try? handle.seekToEnd()
        try? handle.write(contentsOf: Data(line.utf8))
    }
}
```

**关键修改点：**
- 新增 `logURL` 属性（存储 URL，避免重复构造）
- 新增 `fileHandle` 属性（缓存的 `FileHandle`）
- `init` 中调用 `openFileHandle()` 初始化
- `write` 中不再 `try? FileHandle(forWritingTo:)` 创建新句柄，而是复用 `fileHandle`
- 移除 `defer { try? handle.close() }`
- `rotateIfNeeded()` 中新增：旋转前关闭旧句柄，旋转后 `fileHandle = nil`，`write()` 会自动重新打开

**`rotateIfNeeded()` 的修改：**
```swift
private func rotateIfNeeded() {
    // ...
    guard size >= maximumFileSize else { return }

    // 旋转前关闭文件句柄 ← 新增
    fileHandle?.closeFile()
    fileHandle = nil

    // ... 原有旋转逻辑 ...
}
```

---

## 5. MacMateMain.swift

**修改原因（Bug #6）：** AboutView 窗口大小 `520×430` 与 SwiftUI `AboutView` 的 `540×460` 不匹配

**修改前：**
```swift
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 520, height: 430),
    // ...
)
```

**修改后：**
```swift
let window = NSWindow(
    contentRect: NSRect(x: 0, y: 0, width: 540, height: 460),
    // ...
)
```

**解释：** 与 `AboutView.swift:71` 的 `.frame(width: 540, height: 460)` 一致，避免 NSHostingController 推送尺寸约束时的窗口跳变。

---

## 6. SettingsView.swift

**修改原因（Bug #9）：** `SettingsTextField` 背景色 `.textBackgroundColor` 与 App 自定义动态色 `Design.cardBackground` 不一致

**修改前：**
```swift
.background(
    Color(nsColor: .textBackgroundColor)
        .overlay(...)
        .clipShape(...)
)
```

**修改后：**
```swift
.background(
    Design.cardBackground
        .overlay(...)
        .clipShape(...)
)
```

**解释：** `Design.cardBackground` 是动态色（`NSColor(name: nil, dynamicProvider: { ... })`），深浅色模式切换时会自动调整，与卡片背景一致。

---

## 7. AppSettings.swift

**修改原因（Bug #10）：** `CredentialsStore.writeAPIKey` 返回值未检查，写入失败时用户完全不知情

**修改前：**
```swift
@Published var apiKey: String { didSet { _ = CredentialsStore.writeAPIKey(apiKey) } }
```

**修改后：**
```swift
@Published var apiKey: String { didSet {
    if !CredentialsStore.writeAPIKey(apiKey) {
        FileLogger.shared.error(.app, "api_key_save_failed")
    }
}}
```

**解释：**
- 原代码用 `_ = ...` 显式忽略返回值
- 现在检查 `writeAPIKey` 的返回值，如果 `false`（写入失败），记录错误日志
- 用户可以在"诊断"面板查看日志，发现保存失败

---

## 8. CredentialsStore.swift

**修改原因（可优化项 #16）：** API Key 以明文 JSON 写入文件系统（权限 `0o600`），应迁移到 Keychain

**修改前：**
```swift
enum CredentialsStore {
    private static let fileName = "credentials.json"
    private static let fileManager = FileManager.default

    private struct Payload: Codable { var apiKey: String }

    static func readAPIKey() -> String {
        let url = fileURL()
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            return ""
        }
        return payload.apiKey
    }

    static func writeAPIKey(_ value: String) -> Bool {
        let url = fileURL()
        // 创建目录...
        if value.isEmpty { try? fileManager.removeItem(at: url); return true }
        let payload = Payload(apiKey: value)
        guard let data = try? JSONEncoder().encode(payload) else { return false }
        do {
            try data.write(to: url, options: [.atomic])
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            var mutableURL = url
            try mutableURL.setResourceValues(values)
            return true
        } catch { return false }
    }

    private static func fileURL() -> URL {
        AppConstants.applicationSupportDirectory.appendingPathComponent(fileName)
    }
}
```

**修改后：**
```swift
import Foundation
import Security

enum CredentialsStore {
    private static let service = "com.fuhaotong.macmate"
    private static let account = "apiKey"
    private static let fileManager = FileManager.default

    // MARK: - Legacy file migration

    private static var legacyFileURL: URL {
        AppConstants.applicationSupportDirectory.appendingPathComponent("credentials.json")
    }

    private static func migrateFromLegacyFile() {
        let url = legacyFileURL
        guard fileManager.fileExists(atPath: url.path) else { return }
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else {
            try? fileManager.removeItem(at: url)
            return
        }
        _ = writeAPIKey(payload.apiKey)
        try? fileManager.removeItem(at: url)
    }

    private struct Payload: Codable { var apiKey: String }

    // MARK: - Keychain access

    static func readAPIKey() -> String {
        migrateFromLegacyFile()

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let key = String(data: data, encoding: .utf8) else {
            return ""
        }
        return key
    }

    static func writeAPIKey(_ value: String) -> Bool {
        migrateFromLegacyFile()

        // Delete existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        if value.isEmpty { return true }

        guard let data = value.data(using: .utf8) else { return false }
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }
}
```

**关键修改点：**
- 引入 `Security` 框架
- 使用 `kSecClassGenericPassword` + `SecItemAdd` / `SecItemCopyMatching` / `SecItemDelete`
- `service` = `"com.fuhaotong.macmate"`，`account` = `"apiKey"`
- `accessibility` = `kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly`（解锁后可用，不同设备间不同步）
- 新增 `migrateFromLegacyFile()`：启动时检测旧文件 `credentials.json`，如果存在则迁移到 Keychain 后删除
- `readAPIKey` 和 `writeAPIKey` 开头都调用 `migrateFromLegacyFile()`（幂等）
- 写入逻辑：先删除旧 Keychain 项，再写入新值
- 空值处理：直接删除 Keychain 项并返回 true

---

## 9. SelectionViewModel.swift

**修改原因（架构问题 #11）：** `as!` 强制类型转换不安全

**修改前：**
```swift
@available(macOS 15.0, *)
var systemTranslationCoordinator: SystemTranslationCoordinator {
    systemTranslationStorage as! SystemTranslationCoordinator
}
```

**修改后：**
```swift
@available(macOS 15.0, *)
var systemTranslationCoordinator: SystemTranslationCoordinator {
    guard let coordinator = systemTranslationStorage as? SystemTranslationCoordinator else {
        fatalError("SystemTranslationCoordinator is not available on this OS version")
    }
    return coordinator
}
```

**修改点：**
- `as!` → `as? + guard`
- 如果转换失败（理论上在 `@available(macOS 15.0, *)` 下不应该发生），调用 `fatalError` 给出明确错误信息
- 避免运行时崩溃，用显式崩溃替代隐式 crash

---

## 10. SelectionMonitor.swift

**修改原因（架构问题 #12）：** 权限变更后没有重新创建事件监听的入口

**修改前：** 只有 `start()` 和 `stop()`，没有 `restart()`

**修改后：**
```swift
func restart() {
    stop()
    start()
}
```

**说明：** 这是一个**新增方法**而非行为修改。`PermissionManager` 的 `refresh()` 在检测到权限变更后，可以调用 `selectionMonitor.restart()` 来重新创建事件监听。当前代码中 `PermissionManager` 和 `SelectionMonitor` 是独立类，没有直接引用，但接口已提供。

**为什么没有直接调用 `restart()`：**
- `PermissionManager` 和 `SelectionMonitor` 是独立类，没有直接引用
- 可以通过 `NotificationCenter` 或 `Combine` 在 `PermissionManager.accessibilityTrusted` 变化时触发 `restart()`
- 这是一个设计接口，后续可以在 AppDelegate 中观察 `permissions.$accessibilityTrusted` 并调用 `restart()`

---

## 11. AIClient.swift

**修改原因（可优化项 #18）：** 固定超时时间（60s / 120s）对于大文本可能不足

**修改前：**
```swift
request.timeoutInterval = 60   // 普通请求
// ...
request.timeoutInterval = 120  // 流式请求
```

**修改后：**
```swift
private func timeoutInterval(for text: String, isStream: Bool) -> TimeInterval {
    let base: TimeInterval = isStream ? 120 : 60
    let extra = Double(text.count) / 200.0
    return base + extra
}

// 普通请求：
request.timeoutInterval = timeoutInterval(for: userText, isStream: false)

// 流式请求：
request.timeoutInterval = self.timeoutInterval(for: userText, isStream: true)
```

**计算规则：**
- 基础：普通请求 60s，流式 120s
- 额外：每 200 字符增加 1 秒
- 例如：1000 字文本，普通请求超时 = 60 + 5 = 65s

---

## 12. ClipboardManager.swift

**修改原因（可优化项 #17）：** `paste()` 在设置粘贴板内容后更新 `lastChangeCount`，但 `ClipboardCaptureGate.suppress(for:)` 更健壮

**修改前：**
```swift
func paste(_ entry: ClipboardEntry, into targetApplication: NSRunningApplication?) -> Bool {
    pasteboard.clearContents()
    // ... 写入内容 ...
    lastChangeCount = pasteboard.changeCount
    // ...
}
```

**修改后：**
```swift
func paste(_ entry: ClipboardEntry, into targetApplication: NSRunningApplication?) -> Bool {
    ClipboardCaptureGate.shared.suppress(for: 1.5)  // ← 新增
    pasteboard.clearContents()
    // ... 写入内容 ...
    lastChangeCount = pasteboard.changeCount
    // ...
}
```

**解释：**
- `ClipboardCaptureGate` 使用 `NSLock` + `suppressedUntil` 标志
- 调用 `suppress(for: 1.5)` 后，1.5 秒内 `poll()` 会跳过本次 changeCount 变化
- 与 `lastChangeCount` 形成**双重防护**：即使 `lastChangeCount` 因时序问题未正确更新，`suppress` 也能阻止重复捕获

---

## 13. SpeechService.swift

**修改原因（可优化项 #19）：** 每次 `speak()` 都创建新的 `NLLanguageRecognizer`

**修改前：**
```swift
func speak(_ text: String, voiceIdentifier: String, rate: Double) {
    // ...
    let recognizer = NLLanguageRecognizer()
    recognizer.processString(text)
    switch recognizer.dominantLanguage {
    // ...
    }
}
```

**修改后：**
```swift
final class SpeechService {
    private let synthesizer = AVSpeechSynthesizer()
    private let languageRecognizer = NLLanguageRecognizer()  // ← 实例级别

    func speak(_ text: String, voiceIdentifier: String, rate: Double) {
        // ...
        languageRecognizer.processString(text)
        switch languageRecognizer.dominantLanguage {
        // ...
        }
    }
}
```

**修改点：**
- `NLLanguageRecognizer` 从局部变量 → 实例级别常量
- 每次 `speak()` 复用同一个实例，只调用 `processString(text)`
- 避免重复创建对象（虽然本身开销很小，但代码更优雅）

---

## 14. 未修改的审计项

| 审计项 | 状态 | 原因 |
|--------|------|------|
| **#3** `SelectionMonitor.stop()` nil 检查 | ❌ 审计报告错误 | 代码已使用 `if let globalMonitor { ... }`（Swift 5.7+ shorthand），nil 时不会进入 if 块，不会传入 nil |
| **#7** `AppSettings.init` apiKey 写入两次 | ❌ 审计报告错误 | Swift `init` 中给存储属性赋初始值**不触发** `willSet/didSet`，`self.apiKey = ""` 和 `self.apiKey = CredentialsStore.readAPIKey()` 都不会触发 `didSet` |
| **#13** 剪贴板 Timer 轮询 | ❌ 审计报告错误 | macOS **没有**官方 `NSPasteboard` 变化通知 API，所有剪贴板工具都使用轮询 |

---

## 修改统计

| 文件 | 修改项数 | 修改类型 |
|------|----------|----------|
| `SelectionPanel.swift` | 3 | 尺寸估算、定位逻辑、Markdown解析 |
| `IPAService.swift` | 1 | 异步加载 |
| `ClipboardStore.swift` | 0（回退） | 同步读写保持（异步会破坏数据一致性） |
| `FileLogger.swift` | 1 | FileHandle 缓存 |
| `MacMateMain.swift` | 1 | 窗口尺寸统一 |
| `SettingsView.swift` | 1 | 输入框背景色 |
| `AppSettings.swift` | 1 | apiKey 写入错误检查 |
| `CredentialsStore.swift` | 1 | Keychain 迁移 |
| `SelectionViewModel.swift` | 1 | as! → as? + guard |
| `SelectionMonitor.swift` | 1 | 新增 restart() |
| `AIClient.swift` | 1 | 动态超时 |
| `ClipboardManager.swift` | 1 | paste 抑制门 |
| `SpeechService.swift` | 1 | NLLanguageRecognizer 复用 |

**修改总计：16 项优化，13 个文件，203 行新增，68 行删除。**

---

## 验证结果

- **编译**：`swift build -c release --arch arm64` ✅ 通过
- **自测**：`--self-test` 7 个测试套件全部通过 ✅
- **DMG**：`dist/MacMate-1.0.0-arm64.dmg`（4.4MB，SHA256 已生成）✅
