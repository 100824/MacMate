import Foundation

enum AIProvider: String, Codable, CaseIterable {
    case opencode
    case deepseek
    case openai
    case custom

    var title: String {
        switch self {
        case .opencode: return "OpenCode Go"
        case .deepseek: return "DeepSeek"
        case .openai: return "OpenAI"
        case .custom: return "自定义 (OpenAI-compatible)"
        }
    }

    var subtitle: String {
        switch self {
        case .opencode: return "推荐 DeepSeek / Claude 模型"
        case .deepseek: return "官方 API 站点"
        case .openai: return "官方 API"
        case .custom: return "任意 OpenAI 兼容接口"
        }
    }

    var defaultBaseURL: String {
        switch self {
        case .opencode: return "https://opencode.ai/zen/go/v1"
        case .deepseek: return "https://api.deepseek.com"
        case .openai: return "https://api.openai.com"
        case .custom: return ""
        }
    }

    var defaultModel: String {
        switch self {
        case .opencode: return "deepseek-v4-flash"
        case .deepseek: return "deepseek-chat"
        case .openai: return "gpt-4o-mini"
        case .custom: return ""
        }
    }

    var hint: String {
        switch self {
        case .opencode: return "Go 推荐 Base URL：https://opencode.ai/zen/go/v1"
        case .deepseek: return "DeepSeek API 端点：https://api.deepseek.com"
        case .openai: return "OpenAI API 端点：https://api.openai.com"
        case .custom: return "输入你的 OpenAI 兼容 API 地址"
        }
    }

    var requiresAPIKey: Bool {
        switch self {
        case .opencode: return true
        case .deepseek, .openai: return true
        case .custom: return true
        }
    }
}

enum AssistantAction: String, Codable, CaseIterable {
    case translate
    case explain

    var title: String {
        switch self {
        case .translate: return "翻译 / 读音"
        case .explain: return "AI 解释"
        }
    }
}

enum ClipboardContentKind: String, Codable {
    case text
    case image
}

struct ClipboardEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let kind: ClipboardContentKind
    let createdAt: Date
    let sourceApplication: String
    let contentHash: String
    let text: String?
    let rtfFileName: String?
    let imageFileName: String?

    init(
        id: UUID = UUID(),
        kind: ClipboardContentKind,
        createdAt: Date = Date(),
        sourceApplication: String,
        contentHash: String,
        text: String? = nil,
        rtfFileName: String? = nil,
        imageFileName: String? = nil
    ) {
        self.id = id
        self.kind = kind
        self.createdAt = createdAt
        self.sourceApplication = sourceApplication
        self.contentHash = contentHash
        self.text = text
        self.rtfFileName = rtfFileName
        self.imageFileName = imageFileName
    }
}

struct ClipboardCapture {
    let kind: ClipboardContentKind
    let text: String?
    let rtfData: Data?
    let imagePNGData: Data?
    let sourceApplication: String
    let contentHash: String
}

struct AIConfiguration: Equatable {
    var provider: AIProvider
    var baseURL: String
    var apiKey: String
    var model: String
    var explanationPrompt: String

    var isUsable: Bool {
        guard let url = URL(string: baseURL), !model.trimmingCharacters(in: .whitespaces).isEmpty else {
            return false
        }
        if url.scheme?.lowercased() == "https" { return true }
        let host = url.host?.lowercased()
        return url.scheme?.lowercased() == "http" && (host == "localhost" || host == "127.0.0.1" || host == "::1")
    }
}

struct HotKeyShortcut: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
    var enabled: Bool

    static let assistantDefault = HotKeyShortcut(keyCode: 49, carbonModifiers: 2_048, enabled: true)
    static let clipboardDefault = HotKeyShortcut(keyCode: 9, carbonModifiers: 256 | 512, enabled: true)
}
