import SwiftUI

struct AboutView: View {
    private var licenseText: String {
        guard let url = Bundle.main.url(forResource: "CMUdict-LICENSE", withExtension: "txt")
                ?? Bundle.module.url(forResource: "CMUdict-LICENSE", withExtension: "txt", subdirectory: "Pronunciation")
                ?? Bundle.module.url(forResource: "CMUdict-LICENSE", withExtension: "txt") else {
            return "许可证文件未找到。"
        }
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "许可证文件无法读取。"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Header — icon + title
            VStack(spacing: 12) {
                if let image = NSApplication.shared.applicationIconImage {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: 88, height: 88)
                        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 14, x: 0, y: 6)
                }

                Text("MacMate")
                    .font(.system(size: 24, weight: .bold))

                Text("版本 \(AppConstants.version)")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 4)
                    .background(Design.accentLight, in: Capsule())

                Text("本地划词、朗读、AI 解释与剪贴板助手")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 8)

            Divider()
                .padding(.horizontal, 40)
                .overlay(Design.warmBorder)

            // License card
            VStack(alignment: .leading, spacing: 10) {
                MacMateSectionHeader(title: "CMU Pronouncing Dictionary", icon: "book.closed")

                ScrollView {
                    Text(licenseText)
                        .font(.system(size: 10, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 130)
                .padding(10)
                .background(Design.darkCharcoal.opacity(0.03), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Design.warmBorder, lineWidth: 0.5)
                )
            }
            .padding(16)
            .cardStyle()

            Text("日志与崩溃信息仅保存在本机，不会自动上传。")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .padding(24)
        .frame(width: 540, height: 460)
        .background(Design.cardBackground.opacity(0.5))
    }
}
