import AppKit
import ServiceManagement
import SwiftUI

enum SettingsSection: Hashable {
    case general
    case ai
    case speech
    case diagnostics
}

@MainActor
final class SettingsWindowState: ObservableObject {
    @Published var section: SettingsSection = .general
}

@MainActor
final class AIConnectionTester: ObservableObject {
    @Published var isTesting = false
    @Published var message = ""
    @Published var succeeded = false
    @Published var usage = AIUsageLimiter.shared.snapshot()
    @Published var simulationInput = "用一句话解释人工智能。"
    @Published var simulationOutput = ""
    @Published var isSimulating = false

    func test(configuration: AIConfiguration) {
        isTesting = true
        message = ""
        Task {
            do {
                try await AIClient().test(configuration: configuration)
                message = "连接成功"
                succeeded = true
            } catch {
                message = error.localizedDescription
                succeeded = false
            }
            usage = AIUsageLimiter.shared.snapshot()
            isTesting = false
        }
    }

    func refreshUsage() { usage = AIUsageLimiter.shared.snapshot() }

    func simulate(configuration: AIConfiguration) {
        guard let input = simulationInput.nonEmptyTrimmed else {
            simulationOutput = "请输入模拟测试内容"
            return
        }
        isSimulating = true
        simulationOutput = ""
        Task {
            do {
                simulationOutput = try await AIClient().chat(
                    configuration: configuration,
                    systemPrompt: configuration.explanationPrompt,
                    userText: input,
                    maximumTokens: 128
                )
            } catch {
                simulationOutput = "测试失败：\(error.localizedDescription)"
            }
            usage = AIUsageLimiter.shared.snapshot()
            isSimulating = false
        }
    }
}

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissions: PermissionManager
    @ObservedObject var hotKeys: GlobalHotKeyManager
    @ObservedObject var launchAtLogin: LaunchAtLoginManager
    @ObservedObject var diagnostics: DiagnosticsManager
    @ObservedObject var windowState: SettingsWindowState
    let speechService: SpeechService
    let updateShortcut: (GlobalHotKeyAction, HotKeyShortcut) -> Bool

    @StateObject private var tester = AIConnectionTester()

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar

            Divider()
                .overlay(Design.warmBorder)

            // Content area
            Group {
                switch windowState.section {
                case .general: generalTab
                case .ai: aiTab
                case .speech: speechTab
                case .diagnostics: diagnosticsTab
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 820, height: 600)
        .background(
            LinearGradient(
                colors: [
                    Design.accent.opacity(0.07),
                    Design.accent.opacity(0.02),
                    Design.cardBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // App icon
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(.top, 32)
                    .padding(.bottom, 28)
            } else {
                Spacer().frame(height: 124)
            }

            VStack(spacing: 6) {
                sidebarButton(.general, title: "通用", icon: "gearshape")
                sidebarButton(.ai, title: "AI设置", icon: "brain.head.profile")
                sidebarButton(.speech, title: "语音", icon: "speaker.wave.2")
                sidebarButton(.diagnostics, title: "诊断", icon: "stethoscope")
            }
            .padding(.horizontal, 10)

            Spacer()
        }
        .frame(width: 170)
        .background(Design.cardBackground.opacity(0.5))
    }

    private func sidebarButton(_ section: SettingsSection, title: String, icon: String) -> some View {
        let isSelected = windowState.section == section
        return Button {
            withAnimation(Design.smooth) { windowState.section = section }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 15, weight: isSelected ? .semibold : .medium))
                    .frame(width: 22)
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                Spacer()
            }
            .foregroundStyle(isSelected ? Design.accent : .secondary)
            .contentShape(Rectangle())
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(
                isSelected
                    ? Design.accent.opacity(0.12)
                    : Color.primary.opacity(0.04),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Permissions card
                VStack(alignment: .leading, spacing: 14) {
                    MacMateSectionHeader(title: "权限", icon: "lock.shield")

                    MacMateStatusRow(
                        title: "辅助功能",
                        detail: "读取选区位置并完成自动粘贴",
                        isGranted: permissions.accessibilityTrusted,
                        action: permissions.requestAccessibility,
                        settingsAction: permissions.openAccessibilitySettings
                    )

                    MacMateStatusRow(
                        title: "输入监控",
                        detail: "在 mouseUp 后显示浮标，并在输入或点击时隐藏",
                        isGranted: permissions.inputMonitoringTrusted,
                        action: permissions.requestInputMonitoring,
                        settingsAction: permissions.openInputMonitoringSettings
                    )
                }
                .padding(20)
                .cardStyle()

                // Behavior card
                VStack(alignment: .leading, spacing: 14) {
                    MacMateSectionHeader(title: "行为", icon: "hand.tap")

                    behaviorRow(
                        title: "自动显示划词浮标",
                        subtitle: "选中文字后自动弹出翻译与解释按钮",
                        isOn: $settings.autoBubbleEnabled,
                        disabled: !permissions.accessibilityTrusted || !permissions.inputMonitoringTrusted
                    )

                    behaviorRow(
                        title: "开机自动启动",
                        subtitle: "登录时自动运行 MacMate",
                        isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { launchAtLogin.setEnabled($0) }
                        )
                    )

                    if !launchAtLogin.message.isEmpty {
                        Label(launchAtLogin.message, systemImage: "exclamationmark.triangle")
                            .font(.system(size: 11))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(.red.opacity(0.06), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                }
                .padding(20)
                .cardStyle()

                // Shortcuts card
                VStack(alignment: .leading, spacing: 14) {
                    MacMateSectionHeader(title: "全局快捷键", icon: "keyboard")

                    ShortcutRow(
                        title: "划词助手",
                        shortcut: settings.assistantShortcut,
                        error: hotKeys.errors[.assistant],
                        onChange: { shortcut in
                            if updateShortcut(.assistant, shortcut) { settings.assistantShortcut = shortcut }
                        }
                    )

                    Divider()
                        .overlay(Design.warmBorder)
                        .padding(.vertical, 2)

                    ShortcutRow(
                        title: "剪贴板历史",
                        shortcut: settings.clipboardShortcut,
                        error: hotKeys.errors[.clipboard],
                        onChange: { shortcut in
                            if updateShortcut(.clipboard, shortcut) { settings.clipboardShortcut = shortcut }
                        }
                    )
                }
                .padding(20)
                .cardStyle()
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    private func behaviorRow(title: String, subtitle: String, isOn: Binding<Bool>, disabled: Bool = false) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .tint(Design.accent)
                .labelsHidden()
                .disabled(disabled)
                .help(disabled ? "需要先授权相应权限" : "")
        }
    }

    // MARK: - AI Tab

    private var aiTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Provider config card
                VStack(alignment: .leading, spacing: 14) {
                    MacMateSectionHeader(title: settings.aiProvider.title, icon: "brain.head.profile")

                    Picker("供应商", selection: $settings.aiProvider) {
                        ForEach(AIProvider.allCases, id: \.self) { provider in
                            Text(provider.title).tag(provider)
                        }
                    }
                    .pickerStyle(.menu)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Base URL")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        SettingsTextField(title: "例如 https://api.example.com/v1", text: $settings.baseURL)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("API Key")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        SettingsTextField(title: "输入你的 API Key", text: $settings.apiKey, isSecure: true)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("模型 ID")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        SettingsTextField(title: "例如 deepseek-chat", text: $settings.model)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(settings.aiProvider.hint)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        if !settings.aiProvider.requiresAPIKey {
                            Text("API Key 可选，当前保存在本地应用支持目录。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("API Key 保存在本地应用支持目录，不再请求钥匙串权限。")
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("解释提示词")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.secondary)
                        SettingsTextEditor(text: $settings.explanationPrompt, height: 82)
                    }

                    HStack {
                        Button("测试连接") {
                            tester.test(configuration: settings.aiConfiguration)
                        }
                        .buttonStyle(AccentButton())
                        .controlSize(.small)
                        .disabled(tester.isTesting)

                        if tester.isTesting { ProgressView().controlSize(.small).tint(Design.accent) }

                        if !tester.message.isEmpty {
                            Label(tester.message, systemImage: tester.succeeded ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(tester.succeeded ? .green : .red)
                        }
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .cardStyle()

                // Simulation card
                VStack(alignment: .leading, spacing: 14) {
                    MacMateSectionHeader(title: "模拟测试", icon: "wand.and.stars")

                    SettingsTextEditor(text: $tester.simulationInput, height: 58)

                    HStack {
                        Button("运行模拟测试") { tester.simulate(configuration: settings.aiConfiguration) }
                            .buttonStyle(AccentButton())
                            .controlSize(.small)
                            .disabled(tester.isSimulating)

                        if tester.isSimulating { ProgressView().controlSize(.small).tint(Design.accent) }

                        Text("最多返回 128 tokens")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    if !tester.simulationOutput.isEmpty {
                        ScrollView {
                            Text(tester.simulationOutput)
                                .textSelection(.enabled)
                                .font(.system(size: 12))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 84)
                        .padding(10)
                        .background(Design.darkCharcoal.opacity(0.04), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(Design.darkCharcoal.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                }
                .padding(20)
                .cardStyle()

                // Usage card
                VStack(alignment: .leading, spacing: 14) {
                    MacMateSectionHeader(title: "本日用量限制", icon: "chart.bar")

                    usageRow(
                        title: "请求次数",
                        value: "\(tester.usage.requestCount) / \(tester.usage.dailyRequestLimit)",
                        progress: Double(tester.usage.requestCount) / Double(max(tester.usage.dailyRequestLimit, 1))
                    )

                    Divider().overlay(Design.warmBorder)

                    usageRow(
                        title: "Token 用量",
                        value: "\(tester.usage.tokenCount) / \(tester.usage.dailyTokenLimit)",
                        progress: Double(tester.usage.tokenCount) / Double(max(tester.usage.dailyTokenLimit, 1))
                    )

                    Text("每分钟最多 10 次；AI 解释最多显示 1000 字。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .cardStyle()
            }
            .padding(20)
        }
        .onAppear { tester.refreshUsage() }
        .scrollIndicators(.hidden)
    }

    private func usageRow(title: String, value: String, progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(value)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Color.primary.opacity(0.06))
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Design.accent)
                        .frame(width: geo.size.width * min(progress, 1), height: 6)
                }
            }
            .frame(height: 6)
        }
    }

    // MARK: - Speech Tab

    private var speechTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    MacMateSectionHeader(title: "系统语音", icon: "speaker.wave.2")

                    Picker("声音", selection: $settings.speechVoiceIdentifier) {
                        Text("系统自动选择").tag("")
                        ForEach(speechService.availableVoices, id: \.identifier) { voice in
                            Text(voice.name).tag(voice.identifier)
                        }
                    }
                    .pickerStyle(.menu)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("语速").font(.system(size: 12, weight: .medium))
                            Spacer()
                            Text("\(Int(settings.speechRate)) 字/分")
                                .font(.system(size: 12).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $settings.speechRate, in: 80...320, step: 5)
                            .tint(Design.accent)
                    }

                    Button("试听") {
                        speechService.speak("Hello，欢迎使用 MacMate。", voiceIdentifier: settings.speechVoiceIdentifier, rate: settings.speechRate)
                    }
                    .buttonStyle(AccentButton())
                    .controlSize(.small)
                }
                .padding(20)
                .cardStyle()
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 12) {
                    MacMateSectionHeader(title: "离线音标", icon: "textformat")

                    Label("英文音标来自内置 CMU Pronouncing Dictionary，并在本机转换为 IPA；未收录词不会发送到网络。", systemImage: "lock.icloud")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .alignmentGuide(.firstTextBaseline) { $0[.firstTextBaseline] }
                }
                .padding(20)
                .cardStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }

    // MARK: - Diagnostics Tab

    private var diagnosticsTab: some View {
        ScrollView {
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 14) {
                    MacMateSectionHeader(title: "运行状态", icon: "pulse")

                    HStack {
                        Image(systemName: diagnostics.previousRunEndedUnexpectedly ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .foregroundStyle(diagnostics.previousRunEndedUnexpectedly ? .orange : .green)
                        Text("上次运行")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text(diagnostics.previousRunEndedUnexpectedly ? "可能异常退出" : "正常")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }

                    Divider().overlay(Design.warmBorder)

                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(Design.accent)
                        Text("日志目录")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("~/Library/Logs/MacMate/")
                            .font(.system(size: 11).monospaced())
                            .foregroundStyle(.secondary)
                    }

                    Text("日志不会记录选中文字、剪贴板内容、API Key、提示词或 AI 正文。")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .background(Design.accentUltraLight, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
                .padding(20)
                .cardStyle()
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    MacMateSectionHeader(title: "诊断包", icon: "shippingbox")

                    Button("导出脱敏诊断包…") {
                        diagnostics.exportDiagnostics(
                            settings: settings,
                            accessibilityTrusted: permissions.accessibilityTrusted,
                            inputMonitoringTrusted: permissions.inputMonitoringTrusted
                        )
                    }
                    .buttonStyle(AccentButton())
                    .controlSize(.small)

                    if !diagnostics.lastExportMessage.isEmpty {
                        Text(diagnostics.lastExportMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    Label("诊断包只保存在你选择的位置，不会自动上传。", systemImage: "lock.shield")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .padding(20)
                .cardStyle()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(20)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Custom Components

private struct SettingsTextField: View {
    var title: String = ""
    @Binding var text: String
    var isSecure: Bool = false

    var body: some View {
        Group {
            if isSecure {
                SecureField(title, text: $text)
                    .textFieldStyle(.plain)
            } else {
                TextField(title, text: $text)
                    .textFieldStyle(.plain)
            }
        }
        .font(.system(size: 12))
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(height: 32)
        .background(
            Color(nsColor: .textBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Design.warmBorder.opacity(1.5), lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        )
    }
}

private struct SettingsTextEditor: View {
    @Binding var text: String
    let height: CGFloat

    var body: some View {
        TextEditor(text: $text)
            .font(.system(size: 12))
            .scrollContentBackground(.hidden)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .frame(height: height)
            .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(Design.warmBorder.opacity(1.5), lineWidth: 1)
            }
    }
}

private struct ShortcutRow: View {
    let title: String
    let shortcut: HotKeyShortcut
    let error: String?
    let onChange: (HotKeyShortcut) -> Void
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                if let error {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.system(size: 11))
                        .foregroundStyle(.red)
                }
            }
            Spacer()
            Button(recording ? "请按组合键…" : ShortcutDisplay.string(for: shortcut)) {
                beginRecording()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .frame(minWidth: 130)

            Button("禁用") {
                onChange(HotKeyShortcut(keyCode: shortcut.keyCode, carbonModifiers: shortcut.carbonModifiers, enabled: false))
            }
            .buttonStyle(GhostButton())
            .controlSize(.small)
            .disabled(!shortcut.enabled)
        }
        .onDisappear { removeMonitor() }
    }

    private func beginRecording() {
        recording = true
        removeMonitor()
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                recording = false
                removeMonitor()
                return nil
            }
            guard let value = ShortcutDisplay.from(event: event) else { return nil }
            onChange(value)
            recording = false
            removeMonitor()
            return nil
        }
    }

    private func removeMonitor() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }
}
