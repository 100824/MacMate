import AppKit

// DMG 安装页面背景图。
// 像素尺寸固定 820×520（与 package_dmg.sh 中 Finder 窗口 {200,100,1020,620} 一致），
// 避免在 Retina 屏上被翻倍。坐标系为左下原点（NSImage 习惯）。
//
// Finder 图标位置（package_dmg.sh 的 AppleScript，左上原点）：
//   MacMate.app   {210, 305}  96×96  -> 背景图区域 x[210,306] y[119,215], 中心 (258,167)
//   Applications  {610, 305}  96×96  -> 背景图区域 x[610,706] y[119,215], 中心 (658,167)
// 换算：背景图 y = 520 - Finder y。

let width: CGFloat = 820
let height: CGFloat = 520

// 用固定像素的 NSBitmapImageRep 作为绘制目标，确保输出严格 820×520 且内容真正写入。
guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(width),
    pixelsHigh: Int(height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fatalError("Failed to create bitmap")
}
bitmap.size = NSSize(width: width, height: height)

guard let ctx = NSGraphicsContext(bitmapImageRep: bitmap) else {
    fatalError("Failed to create graphics context")
}
NSGraphicsContext.current = ctx
let cg = ctx.cgContext

// 渐变背景 — 暖珊瑚到柔和蜜桃，匹配 MacMate 风格
let colorSpace = CGColorSpaceCreateDeviceRGB()
let gradient = CGGradient(
    colorsSpace: colorSpace,
    colors: [
        NSColor(red: 0.98, green: 0.92, blue: 0.90, alpha: 1.0).cgColor,
        NSColor(red: 1.00, green: 0.97, blue: 0.95, alpha: 1.0).cgColor,
        NSColor(red: 0.99, green: 0.96, blue: 0.94, alpha: 1.0).cgColor
    ] as CFArray,
    locations: [0.0, 0.5, 1.0]
)!
cg.drawLinearGradient(
    gradient,
    start: CGPoint(x: 0, y: 0),
    end: CGPoint(x: width, y: height),
    options: []
)

// 顶部红色强调条
let accentColor = NSColor(red: 0.91, green: 0.30, blue: 0.24, alpha: 1.0)
cg.setFillColor(accentColor.cgColor)
cg.fill(CGRect(x: 0, y: height - 6, width: width, height: 6))

// 顶部居中的 App 大图标（由 package_dmg.sh 作为第一个参数传入）
// 加细微投影增强清晰度，避免在浅色渐变背景上发虚。
let iconPath = CommandLine.arguments.dropFirst().first
    ?? "Sources/MacMate/Resources/Icons/MacMate.png"
let appIcon = NSImage(contentsOf: URL(fileURLWithPath: iconPath))
let appIconSize: CGFloat = 80
if let appIcon = appIcon {
    // 投影（通过 cgContext 设置，绘制图标后立即清除）
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: -2), blur: 6,
                 color: NSColor(white: 0.0, alpha: 0.18).cgColor)
    let iconRect = NSRect(
        x: (width - appIconSize) / 2,
        y: 281,
        width: appIconSize,
        height: appIconSize
    )
    appIcon.draw(in: iconRect)
    cg.restoreGState()
}

// 标题（baseline=247，位于 app 图标下方，留 5pt 间距）
// 加细微投影提升在浅色背景上的清晰度。
func drawTextWithShadow(_ text: String, at point: CGPoint, attrs: [NSAttributedString.Key: Any]) {
    let shadow = NSShadow()
    shadow.shadowColor = NSColor(white: 1.0, alpha: 0.6)
    shadow.shadowBlurRadius = 2
    shadow.shadowOffset = NSSize(width: 0, height: -1)
    var withShadow = attrs
    withShadow[.shadow] = shadow
    text.draw(at: point, withAttributes: withShadow)
}

let title = "MacMate"
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 30, weight: .bold),
    .foregroundColor: NSColor(red: 0.18, green: 0.18, blue: 0.18, alpha: 1.0)
]
let titleSize = title.size(withAttributes: titleAttrs)
drawTextWithShadow(title, at: CGPoint(x: (width - titleSize.width) / 2, y: 247), attrs: titleAttrs)

// 副标题 / 安装提示 — 两行，置于 Finder 图标上方。
// 用更大更粗的字号 + 更深的颜色 + 细投影，提升在浅色背景上的清晰度。
// 措辞控制在 ~200pt 内，居中后落在两图标的中间空白带 x[306,610] 内，左右都不被挡。
let subtitleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
    .foregroundColor: NSColor(red: 0.25, green: 0.24, blue: 0.22, alpha: 1.0)
]
let subtitleLine1 = "拖到 Applications 文件夹"
let subtitleLine2 = "即可完成安装"
let line1Size = subtitleLine1.size(withAttributes: subtitleAttrs)
let line2Size = subtitleLine2.size(withAttributes: subtitleAttrs)
drawTextWithShadow(subtitleLine1, at: CGPoint(x: (width - line1Size.width) / 2, y: 216), attrs: subtitleAttrs)
drawTextWithShadow(subtitleLine2, at: CGPoint(x: (width - line2Size.width) / 2, y: 186), attrs: subtitleAttrs)

// 拖放箭头 — 连接两个 Finder 图标，对齐图标中心高度 y=167。
// 缩短 1/3：原 x[318,598] 长 280pt -> 新 x[318,505] 长 187pt，
// 右端停在右图标左缘 610 之前 105pt，不再戳进 Applications 图标内。
let arrowY: CGFloat = 167
let arrowLeftX: CGFloat = 318
let arrowRightX: CGFloat = 505
let arrowHead: CGFloat = 12
let arrowPath = NSBezierPath()
// 水平线
arrowPath.move(to: CGPoint(x: arrowLeftX, y: arrowY))
arrowPath.line(to: CGPoint(x: arrowRightX, y: arrowY))
// 上箭头翼
arrowPath.move(to: CGPoint(x: arrowRightX, y: arrowY))
arrowPath.line(to: CGPoint(x: arrowRightX - arrowHead, y: arrowY + 7))
// 下箭头翼
arrowPath.move(to: CGPoint(x: arrowRightX, y: arrowY))
arrowPath.line(to: CGPoint(x: arrowRightX - arrowHead, y: arrowY - 7))
accentColor.setStroke()
arrowPath.lineWidth = 3
arrowPath.lineCapStyle = .round
arrowPath.lineJoinStyle = .round
arrowPath.stroke()

NSGraphicsContext.current = nil

// 保存为 PNG（严格 820×520 像素，无 Retina 翻倍）
let outputPath = CommandLine.arguments.dropFirst().last
    ?? "build/dmg-background.png"
let outputURL = URL(fileURLWithPath: outputPath)

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fatalError("Failed to write PNG")
}
try png.write(to: outputURL)
print(outputURL.path)
