import AppKit
import Combine
import SwiftUI

@MainActor
final class SelectionPanelController {
    private let toolbarPanel: NSPanel
    private let resultPanel: NSPanel
    private let viewModel: SelectionViewModel
    private var currentSelection: AccessibleSelection?
    private var cancellables: Set<AnyCancellable> = []

    private static let resultMinHeight: CGFloat = 240
    private static let resultMaxHeight: CGFloat = 540
    private static let resultWidth: CGFloat = 430

    init(viewModel: SelectionViewModel) {
        self.viewModel = viewModel
        toolbarPanel = Self.makePanel(
            identifier: "MacMate.SelectionToolbar",
            size: NSSize(width: 300, height: 52)
        )
        resultPanel = Self.makePanel(
            identifier: "MacMate.SelectionResult",
            size: NSSize(width: Self.resultWidth, height: Self.resultMinHeight)
        )
        toolbarPanel.contentViewController = NSHostingController(rootView: SelectionToolbarView(
            viewModel: viewModel,
            panel: toolbarPanel,
            onAction: { [weak self] action in self?.perform(action) }
        ))
        resultPanel.contentViewController = NSHostingController(rootView: SelectionResultView(
            viewModel: viewModel,
            panel: resultPanel,
            close: { [weak self] in self?.hide() }
        ))

        // Observe view model changes to resize result panel dynamically
        viewModel.$resultText
            .combineLatest(viewModel.$isLoading, viewModel.$pronunciationText, viewModel.$errorMessage)
            .debounce(for: 0.05, scheduler: DispatchQueue.main)
            .sink { [weak self] _, _, _, _ in
                self?.updateResultPanelSize()
            }
            .store(in: &cancellables)
    }

    var isVisible: Bool { toolbarPanel.isVisible || resultPanel.isVisible }

    func show(_ selection: AccessibleSelection) {
        currentSelection = selection
        viewModel.setSelection(selection)
        resultPanel.orderOut(nil)
        position(toolbarPanel, size: NSSize(width: 300, height: 52), near: selection)
        toolbarPanel.orderFrontRegardless()
    }

    func hide() {
        viewModel.cancel()
        toolbarPanel.orderOut(nil)
        resultPanel.orderOut(nil)
        currentSelection = nil
    }

    private func perform(_ action: AssistantAction) {
        guard let selection = currentSelection else { return }
        viewModel.perform(action)
        toolbarPanel.orderOut(nil)
        let size = computePanelSize()
        position(resultPanel, size: size, near: selection)
        resultPanel.orderFrontRegardless()
    }

    private func updateResultPanelSize() {
        guard resultPanel.isVisible else { return }
        let size = computePanelSize()
        var frame = resultPanel.frame
        let deltaY = frame.height - size.height
        frame.origin.y += deltaY
        frame.size = size
        resultPanel.setFrame(frame, display: true, animate: true)
    }

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

        let total = min(max(chromeHeight + contentHeight, Self.resultMinHeight), Self.resultMaxHeight)
        return NSSize(width: Self.resultWidth, height: total)
    }

    private func position(_ panel: NSPanel, size: NSSize, near selection: AccessibleSelection) {
        let anchor = selection.appKitBounds
        let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)

        let origin: CGPoint
        if anchor.width > 0, anchor.height > 0 {
            // 有有效选中区域边界 → 优先放在选区下方，空间不足则移到上方
            origin = Self.bestPosition(
                size: size, anchor: anchor, visible: visible,
                anchorCenterX: anchor.midX,
                preferredBelowY: anchor.minY - size.height - 12,
                preferredAboveY: anchor.maxY + 12
            )
        } else {
            // 无有效边界（退回鼠标位置）→ 优先放在鼠标上方，便于阅读结果
            let mouse = NSEvent.mouseLocation
            origin = Self.bestPosition(
                size: size, anchor: anchor, visible: visible,
                anchorCenterX: mouse.x,
                preferredBelowY: mouse.y - size.height - 14,
                preferredAboveY: mouse.y + 16
            )
        }

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
    }

    /// 计算面板的最佳位置：优先放在选区下方，空间不足放到上方，仍不足则垂直居中。
    /// 水平方向：优先居中，超出屏幕时智能反向放置。
    private static func bestPosition(
        size: NSSize, anchor: CGRect, visible: NSRect,
        anchorCenterX: CGFloat,
        preferredBelowY: CGFloat,
        preferredAboveY: CGFloat
    ) -> CGPoint {
        // 尝试下方放置
        var y: CGFloat
        if preferredBelowY >= visible.minY,
           preferredBelowY + size.height <= visible.maxY {
            y = preferredBelowY
        } else if preferredAboveY >= visible.minY,
                  preferredAboveY + size.height <= visible.maxY {
            // 下方放不下，试试上方
            y = preferredAboveY
        } else {
            // 都不行，垂直居中
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

    private static func makePanel(identifier: String, size: NSSize) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.identifier = NSUserInterfaceItemIdentifier(identifier)
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        return panel
    }
}

// MARK: - Drag Modifier

/// Drag gesture modifier that moves a panel when the user drags.
/// Uses `minimumDistance: 3` so taps still pass through to child buttons.
private struct PanelDragModifier: ViewModifier {
    let panel: NSPanel?
    @State private var dragStart: CGPoint?

    func body(content: Content) -> some View {
        content.simultaneousGesture(
            DragGesture(minimumDistance: 3)
                .onChanged { value in
                    if dragStart == nil {
                        dragStart = panel?.frame.origin
                    }
                    guard let start = dragStart, let panel = panel else { return }
                    panel.setFrameOrigin(CGPoint(
                        x: start.x + value.translation.width,
                        y: start.y - value.translation.height
                    ))
                }
                .onEnded { _ in
                    dragStart = nil
                }
        )
    }
}

// MARK: - Toolbar View

private struct SelectionToolbarView: View {
    @ObservedObject var viewModel: SelectionViewModel
    let panel: NSPanel?
    let onAction: (AssistantAction) -> Void

    var body: some View {
        HStack(spacing: 10) {
            // App icon
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            // Translate button — translucent coral
            Button {
                onAction(.translate)
            } label: {
                Label("翻译/读音", systemImage: "character.book.closed")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(PillButtonStyle(color: Design.accent.opacity(0.75)))

            // Explain button — translucent blue
            Button {
                onAction(.explain)
            } label: {
                Label("AI 解释", systemImage: "sparkles")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity, minHeight: 30)
            }
            .buttonStyle(PillButtonStyle(color: Design.accentBlue.opacity(0.75)))
        }
        .padding(10)
        .frame(width: 300, height: 52)
        .panelStyle(cornerRadius: 20)
        .modifier(PanelDragModifier(panel: panel))
    }
}

/// Pill-shaped button style with a color fill
private struct PillButtonStyle: ButtonStyle {
    let color: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white)
            .background(
                color.opacity(configuration.isPressed ? 0.8 : 1),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(Design.spring, value: configuration.isPressed)
    }
}

// MARK: - Result View

private struct SelectionResultView: View {
    @ObservedObject var viewModel: SelectionViewModel
    let panel: NSPanel?
    let close: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            headerView

            // Pronunciation section
            if viewModel.activeAction == .translate || viewModel.activeAction == .explain {
                pronunciationView
            }

            // Content area
            contentArea

            // Footer
            footerView
        }
        .padding(16)
        .frame(width: 430)
        .fixedSize(horizontal: false, vertical: true)
        .panelStyle(cornerRadius: 20)
        .modifier(PanelDragModifier(panel: panel))
        .background {
            if #available(macOS 15.0, *) {
                SystemTranslationTaskHost(coordinator: viewModel.systemTranslationCoordinator)
                    .id(viewModel.translationRequestID)
            }
        }
    }

    // MARK: - Header

    @ViewBuilder
    private var headerView: some View {
        HStack(spacing: 10) {
            // App icon
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 22, height: 22)
                    .clipShape(RoundedRectangle(cornerRadius: 5, style: .continuous))
            }

            Label(viewModel.activeAction?.title ?? "处理结果", systemImage: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(iconColor)

            Spacer()

            if viewModel.isLoading {
                Button("取消") { viewModel.cancel() }
                    .buttonStyle(.link)
                    .controlSize(.small)
                    .foregroundStyle(Design.accent)
            }

            Button(action: close) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.tertiary)
                    .opacity(0.6)
            }
            .buttonStyle(.plain)
        }
    }

    private var icon: String {
        switch viewModel.activeAction {
        case .translate: return viewModel.isUsingAITranslation ? "sparkles" : "character.book.closed"
        case .explain: return "sparkles"
        case nil: return "sparkles"
        }
    }

    private var iconColor: Color {
        switch viewModel.activeAction {
        case .translate: return Design.accent
        case .explain: return Design.accentBlue
        case nil: return .primary
        }
    }

    // MARK: - Pronunciation

    private var pronunciationView: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(viewModel.pronunciationTitle)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)

                Text(viewModel.pronunciationText.isEmpty ? "暂无音标或拼音" : viewModel.pronunciationText)
                    .font(.system(.body, design: .rounded))
                    .textSelection(.enabled)
                    .lineLimit(3)
                    .foregroundStyle(.primary)
            }

            Spacer()

            if !viewModel.pronunciationText.isEmpty {
                Button(action: viewModel.speakSelection) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Design.accent)
                        .frame(width: 32, height: 32)
                        .background(Design.accentLight, in: Circle())
                }
                .buttonStyle(.plain)
                .help("使用系统语音朗读")
            }
        }
        .padding(12)
        .warmHighlight()
    }

    // MARK: - Content Area

    @ViewBuilder
    private var contentArea: some View {
        if viewModel.isLoading {
            MacMateLoadingView(text: loadingText)
        } else if !viewModel.errorMessage.isEmpty {
            Label(viewModel.errorMessage, systemImage: "exclamationmark.triangle")
                .font(.system(size: 12))
                .foregroundStyle(.orange)
                .lineLimit(3)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: Design.extraSmallCornerRadius, style: .continuous))
        } else {
            ScrollView {
                MarkdownResultText(markdown: viewModel.resultText)
                    .padding(.top, 2)
            }
        }
    }

    private var loadingText: String {
        switch viewModel.activeAction {
        case .translate:
            return viewModel.isUsingAITranslation ? "正在使用 AI 翻译…" : "正在使用系统本地翻译…"
        case .explain:
            return "正在获取 AI 解释…"
        case nil:
            return "处理中…"
        }
    }

    // MARK: - Footer

    @ViewBuilder
    private var footerView: some View {
        if !viewModel.isLoading && (viewModel.activeAction != nil) {
            HStack(spacing: 6) {
                if !viewModel.resultText.isEmpty {
                    Button("复制", systemImage: "doc.on.doc") { viewModel.copyResult() }
                        .buttonStyle(AccentGhostButton())
                }

                Button("重试", systemImage: "arrow.clockwise") { viewModel.retry() }
                    .buttonStyle(GhostButton())

                if viewModel.activeAction == .translate {
                    Button("AI 翻译", systemImage: "sparkles") { viewModel.translateWithAI() }
                        .buttonStyle(GhostButton())
                }

                Spacer()

                if viewModel.activeAction == .translate, !viewModel.translationProvider.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.green)
                        Text(viewModel.translationProvider)
                            .font(.system(size: 11))
                    }
                    .foregroundStyle(.secondary)
                } else if viewModel.activeAction == .explain {
                    HStack(spacing: 4) {
                        Image(systemName: "text.word.count")
                            .font(.system(size: 10))
                        Text("\(viewModel.explanationCharacterCount) / \(AppConstants.maximumAIExplanationCharacters) 字")
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - Markdown Rendering

private struct MarkdownResultText: View {
    let markdown: String

    var body: some View {
        if markdown.isEmpty {
            Text("没有可显示的结果")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                    blockView(block)
                }
            }
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(level == 1 ? .title2.weight(.bold) : level == 2 ? .title3.weight(.semibold) : .headline)
                .padding(.top, level == 1 ? 3 : 1)
        case .paragraph(let text):
            Text(inline(text)).font(.system(size: 13))
        case .bullet(let text):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text("•")
                    .fontWeight(.bold)
                    .foregroundStyle(Design.accent.opacity(0.7))
                Text(inline(text))
                    .font(.system(size: 13))
            }
        case .ordered(let marker, let text):
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(marker)
                    .fontWeight(.semibold)
                    .foregroundStyle(Design.accent.opacity(0.7))
                    .frame(minWidth: 18, alignment: .trailing)
                Text(inline(text))
                    .font(.system(size: 13))
            }
        case .quote(let text):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 2, style: .continuous)
                    .fill(Design.accent.opacity(0.4))
                    .frame(width: 3)
                Text(inline(text))
                    .foregroundStyle(.secondary)
                    .font(.system(size: 13))
            }
        case .code(let text):
            Text(text)
                .font(.system(.callout, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Design.darkCharcoal.opacity(0.05), in: RoundedRectangle(cornerRadius: Design.extraSmallCornerRadius, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Design.extraSmallCornerRadius, style: .continuous)
                        .stroke(Design.darkCharcoal.opacity(0.08), lineWidth: 0.5)
                )
        case .rule:
            Divider()
                .overlay(Design.warmBorder)
        }
    }

    private var blocks: [MarkdownBlock] {
        MarkdownBlock.parse(markdown)
    }

    private func inline(_ value: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: value, options: options)) ?? AttributedString(value)
    }
}

// MARK: - Markdown Parser

private enum MarkdownBlock {
    case heading(Int, String)
    case paragraph(String)
    case bullet(String)
    case ordered(String, String)
    case quote(String)
    case code(String)
    case rule

    static func parse(_ markdown: String) -> [MarkdownBlock] {
        var result: [MarkdownBlock] = []
        var paragraph: [String] = []
        var codeLines: [String] = []
        var inCode = false
        var inIndentCode = false
        var quoteLines: [String] = []

        func flushParagraph() {
            guard !paragraph.isEmpty else { return }
            result.append(.paragraph(paragraph.joined(separator: "\n")))
            paragraph.removeAll()
        }

        func flushQuote() {
            guard !quoteLines.isEmpty else { return }
            result.append(.quote(quoteLines.joined(separator: "\n")))
            quoteLines.removeAll()
        }

        for rawLine in markdown.components(separatedBy: .newlines) {
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            // Fenced code block
            if line.hasPrefix("```") {
                if inCode {
                    result.append(.code(codeLines.joined(separator: "\n")))
                    codeLines.removeAll()
                } else {
                    flushParagraph()
                    flushQuote()
                }
                inCode.toggle()
                continue
            }
            if inCode {
                codeLines.append(rawLine)
                continue
            }

            // Indented code block (4 spaces or tab)
            if rawLine.hasPrefix("    ") || rawLine.hasPrefix("\t") {
                flushParagraph()
                flushQuote()
                if !inIndentCode {
                    inIndentCode = true
                }
                codeLines.append(String(rawLine.dropFirst(rawLine.hasPrefix("    ") ? 4 : 1)))
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

            if line.isEmpty {
                flushParagraph()
                flushQuote()
                continue
            }
            if line == "---" || line == "***" || line == "___" {
                flushParagraph()
                flushQuote()
                result.append(.rule)
                continue
            }
            let hashes = line.prefix { $0 == "#" }.count
            if (1...6).contains(hashes), line.dropFirst(hashes).hasPrefix(" ") {
                flushParagraph()
                flushQuote()
                result.append(.heading(hashes, String(line.dropFirst(hashes + 1))))
                continue
            }
            if line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("+ ") {
                flushParagraph()
                flushQuote()
                result.append(.bullet(String(line.dropFirst(2))))
                continue
            }
            if line.hasPrefix("> ") {
                flushParagraph()
                quoteLines.append(String(line.dropFirst(2)))
                continue
            }
            if !quoteLines.isEmpty {
                flushQuote()
            }
            if let period = line.firstIndex(of: "."),
               line[..<period].allSatisfy(\.isNumber),
               line.index(after: period) < line.endIndex,
               line[line.index(after: period)] == " " {
                flushParagraph()
                let marker = String(line[...period])
                result.append(.ordered(marker, String(line[line.index(period, offsetBy: 2)...])))
                continue
            }
            paragraph.append(rawLine)
        }
        if inCode, !codeLines.isEmpty { result.append(.code(codeLines.joined(separator: "\n"))) }
        if inIndentCode, !codeLines.isEmpty { result.append(.code(codeLines.joined(separator: "\n"))) }
        flushQuote()
        flushParagraph()
        return result
    }
}
