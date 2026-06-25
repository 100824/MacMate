import SwiftUI

// MARK: - Design System
// Inspired by the MacMate bird icon.
// The aesthetic is clean & minimal (简洁) with a playful, rounded feel (卡通圆润).

enum Design {
    // MARK: - Colors
    /// Primary accent — warm coral, matches the bird's cheek patch (#E84D3D)
    static let accent = Color(red: 0.91, green: 0.30, blue: 0.24)
    /// Lighter accent variant for backgrounds
    static let accentLight = Color(red: 0.91, green: 0.30, blue: 0.24, opacity: 0.12)
    /// Very light accent for subtle tinted backgrounds
    static let accentUltraLight = Color(red: 0.91, green: 0.30, blue: 0.24, opacity: 0.06)
    /// Secondary accent — cool blue complement (#4A7BF7)
    static let accentBlue = Color(red: 0.29, green: 0.48, blue: 0.97)
    /// Lighter blue accent for backgrounds
    static let accentBlueLight = Color(red: 0.29, green: 0.48, blue: 0.97, opacity: 0.12)

    /// Soft green for clipboard selection states (avoids the "error" connotation of red)
    static let selectionGreen = Color(red: 0.20, green: 0.72, blue: 0.48)
    /// Lighter green for selection backgrounds
    static let selectionGreenLight = Color(red: 0.20, green: 0.72, blue: 0.48, opacity: 0.12)
    /// Very light green for subtle selection tints
    static let selectionGreenUltraLight = Color(red: 0.20, green: 0.72, blue: 0.48, opacity: 0.06)

    /// Bird face warm white
    static let warmWhite = Color(red: 0.96, green: 0.94, blue: 0.92)
    /// Bird body dark charcoal — for bold text and accents
    static let darkCharcoal = Color(red: 0.10, green: 0.10, blue: 0.10)
    /// Warm secondary text color
    static let warmSecondary = Color(red: 0.55, green: 0.45, blue: 0.38)

    /// Subtle background highlight
    static let surfaceHighlight = Color.primary.opacity(0.04)
    /// Warmer surface highlight for content cards
    static let surfaceWarm = Color(red: 0.96, green: 0.94, blue: 0.92, opacity: 0.3)
    /// Selected row background
    static let selectedBackground = accent.opacity(0.15)

    /// Dark panel background for floating panels
    static let panelBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name == .darkAqua
            ? NSColor(calibratedWhite: 0.12, alpha: 0.95)
            : NSColor(calibratedWhite: 0.97, alpha: 0.95)
    }))
    /// Card background for section cards
    static let cardBackground = Color(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
        appearance.name == .darkAqua
            ? NSColor(calibratedWhite: 0.17, alpha: 0.85)
            : NSColor(calibratedWhite: 0.995, alpha: 0.88)
    }))

    /// Warm border color for cards and sections
    static let warmBorder = Color(red: 0.85, green: 0.80, blue: 0.75, opacity: 0.3)

    // MARK: - Layout Constants
    /// Large corner radius for panels and cards (very rounded, playful)
    static let cornerRadius: CGFloat = 18
    /// Medium corner radius for smaller components
    static let mediumCornerRadius: CGFloat = 14
    /// Small corner radius for buttons and tags
    static let smallCornerRadius: CGFloat = 12
    /// Extra small for inline elements
    static let extraSmallCornerRadius: CGFloat = 8

    /// Standard padding
    static let padding: CGFloat = 20
    /// Tight padding
    static let tightPadding: CGFloat = 14
    /// Extra tight padding
    static let extraTightPadding: CGFloat = 10

    // MARK: - Shadows
    /// Soft floating shadow for panels
    static var panelShadow: some View {
        Color.clear
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
    }
    /// Card elevation shadow
    static var cardShadow: some View {
        Color.clear
            .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }

    // MARK: - Animations
    /// Bouncy spring for interactive elements
    static let spring = Animation.spring(response: 0.35, dampingFraction: 0.7)
    /// Smooth ease for transitions
    static let smooth = Animation.easeInOut(duration: 0.25)

    // MARK: - Panel Styling (legacy compatible)
    /// Apply standard panel styling with frosted background, border, and shadow
    @ViewBuilder
    static func stylePanel<Content: View>(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                    .stroke(.white.opacity(0.15), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
    }

    /// Solid panel styling (non-frosted, for better readability)
    @ViewBuilder
    static func styleSolidPanel<Content: View>(_ content: Content) -> some View {
        content
            .background(panelBackground, in: RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius + 2, style: .continuous)
                    .stroke(.white.opacity(0.12), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.08), radius: 20, x: 0, y: 8)
    }
}

// MARK: - View Modifiers

/// Panel style modifier — frosted glass with rounded corners
struct PanelModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.2), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 4)
    }
}

/// Card style modifier — solid background with rounded corners for sections
struct CardModifier: ViewModifier {
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .background(Design.cardBackground, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            )
            .shadow(color: .black.opacity(0.04), radius: 6, x: 0, y: 2)
    }
}

/// Warm highlight background modifier
struct WarmHighlightModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Design.surfaceWarm, in: RoundedRectangle(cornerRadius: Design.smallCornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Design.smallCornerRadius, style: .continuous)
                    .stroke(Design.warmBorder, lineWidth: 0.5)
            )
    }
}

// MARK: - View Extensions

extension View {
    /// Apply frosted panel styling with rounded corners
    func panelStyle(cornerRadius: CGFloat = 16) -> some View {
        modifier(PanelModifier(cornerRadius: cornerRadius))
    }

    /// Apply solid card styling with rounded corners
    func cardStyle(cornerRadius: CGFloat = Design.mediumCornerRadius) -> some View {
        modifier(CardModifier(cornerRadius: cornerRadius))
    }

    /// Apply warm highlight background
    func warmHighlight() -> some View {
        modifier(WarmHighlightModifier())
    }
}

// MARK: - Button Styles

/// Primary accent button - pill-shaped, coral accent
struct AccentButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(
                Design.accent
                    .opacity(configuration.isPressed ? 0.85 : 1),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Design.spring, value: configuration.isPressed)
    }
}

/// Secondary button - pill-shaped, blue accent
struct SecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 20)
            .padding(.vertical, 9)
            .background(
                Design.accentBlue
                    .opacity(configuration.isPressed ? 0.85 : 1),
                in: Capsule()
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(Design.spring, value: configuration.isPressed)
    }
}

/// Ghost button - subtle, rounded
struct GhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Color.primary.opacity(configuration.isPressed ? 0.10 : 0.05),
                in: RoundedRectangle(cornerRadius: Design.extraSmallCornerRadius, style: .continuous)
            )
            .animation(Design.spring, value: configuration.isPressed)
    }
}

/// Accent ghost button — coral tinted ghost
struct AccentGhostButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(Design.accent)
            .padding(.horizontal, 14)
            .padding(.vertical, 6)
            .background(
                Design.accentLight
                    .opacity(configuration.isPressed ? 0.2 : 0.12),
                in: RoundedRectangle(cornerRadius: Design.extraSmallCornerRadius, style: .continuous)
            )
            .animation(Design.spring, value: configuration.isPressed)
    }
}

// MARK: - Components

/// A card container with title, optional icon, and content
struct MacMateCard<Content: View>: View {
    let title: String
    let icon: String?
    let content: Content

    init(title: String, icon: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Title row
            HStack(spacing: 8) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Design.accent)
                }
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
            }

            // Content
            content
        }
        .padding(Design.padding)
        .cardStyle()
    }
}

/// Section header label with accent underline
struct MacMateSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Design.accent)
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .kerning(0.5)
        }
        .padding(.bottom, 4)
    }
}

/// Mini MacMate bird mascot — simplified icon derived from the app icon
struct MacMateBird: View {
    let size: CGFloat

    init(size: CGFloat = 32) {
        self.size = size
    }

    var body: some View {
        ZStack {
            // Body — dark charcoal oval
            Ellipse()
                .fill(Design.darkCharcoal)
                .frame(width: size * 0.85, height: size * 0.75)
                .offset(x: size * 0.05, y: size * 0.05)

            // Face — warm white oval
            Ellipse()
                .fill(.white)
                .frame(width: size * 0.55, height: size * 0.5)
                .offset(x: -size * 0.08, y: -size * 0.02)

            // Cheek patch — coral circle
            Circle()
                .fill(Design.accent)
                .frame(width: size * 0.22, height: size * 0.22)
                .offset(x: -size * 0.20, y: size * 0.06)

            // Eye — small dark circle
            Circle()
                .fill(Design.darkCharcoal)
                .frame(width: size * 0.09, height: size * 0.09)
                .offset(x: size * 0.04, y: -size * 0.04)

            // Beak — small triangle pointing right
            Path { path in
                path.move(to: CGPoint(x: size * 0.38, y: size * 0.02))
                path.addLine(to: CGPoint(x: size * 0.52, y: 0))
                path.addLine(to: CGPoint(x: size * 0.38, y: -size * 0.06))
                path.closeSubpath()
            }
            .fill(Design.darkCharcoal)
            .offset(x: size * 0.05)
        }
        .frame(width: size, height: size)
    }
}

/// Empty state view with the bird mascot
struct MacMateEmptyState: View {
    let title: String
    let subtitle: String
    let icon: String

    init(title: String, subtitle: String, icon: String = "bird") {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            MacMateBird(size: 56)
                .opacity(0.6)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Rounded loading indicator
struct MacMateLoadingView: View {
    var text: String = "加载中…"

    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .controlSize(.regular)
                .tint(Design.accent)

            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 80)
    }
}

/// A row that shows a permission/status with clear visual feedback
struct MacMateStatusRow: View {
    let title: String
    let detail: String
    let isGranted: Bool
    let action: () -> Void
    let settingsAction: (() -> Void)?

    init(title: String, detail: String, isGranted: Bool, action: @escaping () -> Void, settingsAction: (() -> Void)? = nil) {
        self.title = title
        self.detail = detail
        self.isGranted = isGranted
        self.action = action
        self.settingsAction = settingsAction
    }

    var body: some View {
        HStack(spacing: 14) {
            // Status icon
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isGranted ? Color.green.opacity(0.12) : Color.orange.opacity(0.12))
                    .frame(width: 36, height: 36)

                Image(systemName: isGranted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(isGranted ? .green : .orange)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer()

            if isGranted {
                Text("已授权")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.green.opacity(0.08), in: Capsule())
            } else {
                Button("请求权限", action: action)
                    .buttonStyle(AccentButton())
                    .controlSize(.small)

                if let settingsAction {
                    Button("系统设置", action: settingsAction)
                        .buttonStyle(GhostButton())
                }
            }
        }
    }
}
