import AppKit
import Combine
import SwiftUI

@MainActor
final class ClipboardPanelState: ObservableObject {
    @Published var selectedIndex = 0
}

@MainActor
final class ClipboardPanelController: NSObject, NSWindowDelegate {
    private let window: NSWindow
    private let manager: ClipboardManager
    private let state = ClipboardPanelState()
    private var targetApplication: NSRunningApplication?
    private var keyMonitor: Any?

    init(manager: ClipboardManager) {
        self.manager = manager
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 540),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        super.init()
        window.title = ""
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        window.contentViewController = NSHostingController(rootView: ClipboardPanelView(
            store: manager.store,
            settings: manager.settings,
            state: state,
            onPaste: { [weak self] index in self?.paste(index: index) },
            onClose: { [weak window] in window?.orderOut(nil) }
        ))
        window.delegate = self
    }

    var isVisible: Bool { window.isVisible }

    func show() {
        targetApplication = NSWorkspace.shared.frontmostApplication
        state.selectedIndex = 0
        if let screen = NSScreen.main {
            let frame = window.frame
            window.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - frame.width / 2, y: screen.visibleFrame.midY - frame.height / 2))
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        installKeyMonitor()
    }

    func hide() {
        window.orderOut(nil)
        removeKeyMonitor()
    }

    func windowWillClose(_ notification: Notification) {
        removeKeyMonitor()
    }

    private func paste(index: Int) {
        guard manager.store.entries.indices.contains(index) else { return }
        let entry = manager.store.entries[index]
        hide()
        _ = manager.paste(entry, into: targetApplication)
    }

    private func installKeyMonitor() {
        removeKeyMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.window.isKeyWindow else { return event }
            switch event.keyCode {
            case 53:
                self.hide()
                return nil
            case 125:
                self.state.selectedIndex = min(self.state.selectedIndex + 1, max(0, self.manager.store.entries.count - 1))
                return nil
            case 126:
                self.state.selectedIndex = max(0, self.state.selectedIndex - 1)
                return nil
            case 36, 76:
                self.paste(index: self.state.selectedIndex)
                return nil
            default:
                if let value = event.charactersIgnoringModifiers, let digit = Int(value), digit >= 0 {
                    let index = digit == 0 ? 9 : digit - 1
                    if self.manager.store.entries.indices.contains(index) { self.paste(index: index) }
                    return nil
                }
                return event
            }
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}

private struct ClipboardPanelView: View {
    @ObservedObject var store: ClipboardStore
    let settings: AppSettings?
    @ObservedObject var state: ClipboardPanelState
    let onPaste: (Int) -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()
                .padding(.horizontal, 20)
                .overlay(Design.warmBorder)

            // Content
            if store.entries.isEmpty {
                MacMateEmptyState(
                    title: "暂无剪贴板记录",
                    subtitle: "复制文字或图片后会显示在这里\n方向键选择 · Enter 粘贴"
                )
            } else {
                entriesList
            }
        }
        .frame(width: 640, height: 540)
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

    // MARK: - Header

    private var headerView: some View {
        HStack(spacing: 12) {
            // App icon
            if let appIcon = NSApp.applicationIconImage {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("剪贴板历史")
                    .font(.system(size: 18, weight: .bold))
                Text("方向键选择，Enter 粘贴，数字键 1–0 快速选择")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if let settings {
                Toggle("暂停记录", isOn: Binding(get: { settings.clipboardPaused }, set: { settings.clipboardPaused = $0 }))
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .tint(Design.accent)
            }

            Button("清空") { store.clear() }
                .buttonStyle(GhostButton())
                .disabled(store.entries.isEmpty)
        }
        .padding(EdgeInsets(top: 20, leading: 24, bottom: 16, trailing: 24))
    }

    // MARK: - Entries List

    private var entriesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(store.entries.enumerated()), id: \.element.id) { index, entry in
                        ClipboardRow(
                            index: index,
                            entry: entry,
                            image: store.image(for: entry),
                            selected: state.selectedIndex == index,
                            onPaste: { onPaste(index) },
                            onDelete: { store.remove(entry) }
                        )
                        .id(entry.id)
                    }
                }
                .padding(16)
            }
            .onChange(of: state.selectedIndex) { _, newIndex in
                if store.entries.indices.contains(newIndex) {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(store.entries[newIndex].id, anchor: .center)
                    }
                }
            }
        }
    }
}

private struct ClipboardRow: View {
    let index: Int
    let entry: ClipboardEntry
    let image: NSImage?
    let selected: Bool
    let onPaste: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Badge — rounded number indicator
            Text(index == 9 ? "0" : "\(index + 1)")
                .font(.system(size: 12, weight: .bold).monospacedDigit())
                .foregroundStyle(selected ? .white : Design.accent)
                .frame(width: 28, height: 28)
                .background(
                    selected
                        ? Design.accent
                        : Design.accentLight,
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                )

            // Thumbnail or text icon
            Group {
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 56, height: 48)
                } else {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(selected ? AnyShapeStyle(Design.selectionGreen.opacity(0.6)) : AnyShapeStyle(HierarchicalShapeStyle.tertiary))
                        .frame(width: 56, height: 48)
                }
            }
            .background(
                selected ? Design.selectionGreenUltraLight : Color.primary.opacity(0.03),
                in: RoundedRectangle(cornerRadius: 10, style: .continuous)
            )

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(entry.text?.nonEmptyTrimmed ?? "图片")
                    .lineLimit(2)
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? .primary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    Image(systemName: "app.dashed")
                        .font(.system(size: 9))
                    Text(entry.sourceApplication)
                        .lineLimit(1)
                    Text("·")
                    Text(entry.createdAt.formatted(date: .omitted, time: .shortened))
                }
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
            }

            Spacer()

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28, height: 28)
                    .background(
                        Color.primary.opacity(0.04),
                        in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .opacity(0.5)
            .help("删除")
        }
        .padding(12)
        .background(selected ? Design.selectionGreen.opacity(0.12) : Design.cardBackground, in: RoundedRectangle(cornerRadius: Design.smallCornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Design.smallCornerRadius, style: .continuous)
                .stroke(selected ? Design.selectionGreen.opacity(0.3) : Color.primary.opacity(0.04), lineWidth: selected ? 1.5 : 0.5)
        )
        .shadow(color: selected ? Design.selectionGreen.opacity(0.06) : .clear, radius: 8, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture(perform: onPaste)
    }
}
