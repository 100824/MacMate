import Combine
import Foundation

@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let provider = "ai.provider"
        static let baseURL = "ai.baseURL"
        static let model = "ai.model"
        static let explanationPrompt = "ai.explanationPrompt"
        static let speechRate = "speech.rate"
        static let speechVoice = "speech.voice"
        static let autoBubble = "selection.autoBubble"
        static let clipboardPaused = "clipboard.paused"
        static let assistantShortcut = "hotkey.assistant"
        static let clipboardShortcut = "hotkey.clipboard"
        static let didAttemptLoginRegistration = "login.attempted"
    }

    private let defaults: UserDefaults

    @Published var aiProvider: AIProvider { didSet {
        persistProvider()
        applyPresetIfNeeded(from: oldValue)
    }}
    @Published var baseURL: String { didSet { defaults.set(baseURL, forKey: Key.baseURL) } }
    @Published var apiKey: String { didSet {
        if !CredentialsStore.writeAPIKey(apiKey) {
            FileLogger.shared.error(.app, "api_key_save_failed")
        }
    }}
    @Published var model: String { didSet { defaults.set(model, forKey: Key.model) } }
    @Published var explanationPrompt: String { didSet { defaults.set(explanationPrompt, forKey: Key.explanationPrompt) } }
    @Published var speechRate: Double { didSet { defaults.set(speechRate, forKey: Key.speechRate) } }
    @Published var speechVoiceIdentifier: String { didSet { defaults.set(speechVoiceIdentifier, forKey: Key.speechVoice) } }
    @Published var autoBubbleEnabled: Bool { didSet { defaults.set(autoBubbleEnabled, forKey: Key.autoBubble) } }
    @Published var clipboardPaused: Bool { didSet { defaults.set(clipboardPaused, forKey: Key.clipboardPaused) } }
    @Published var assistantShortcut: HotKeyShortcut { didSet { save(assistantShortcut, key: Key.assistantShortcut) } }
    @Published var clipboardShortcut: HotKeyShortcut { didSet { save(clipboardShortcut, key: Key.clipboardShortcut) } }

    var didAttemptLoginRegistration: Bool {
        get { defaults.bool(forKey: Key.didAttemptLoginRegistration) }
        set { defaults.set(newValue, forKey: Key.didAttemptLoginRegistration) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.aiProvider = .opencode  // temporary, overwritten below
        self.baseURL = ""
        self.apiKey = ""
        self.model = ""
        self.explanationPrompt = ""
        self.speechRate = 180
        self.speechVoiceIdentifier = ""
        self.autoBubbleEnabled = true
        self.clipboardPaused = false
        self.assistantShortcut = .assistantDefault
        self.clipboardShortcut = .clipboardDefault

        // Now configure from persisted state
        let provider = Self.loadProvider(defaults: defaults)
        self.aiProvider = provider
        persistProvider()

        let storedBaseURL = defaults.string(forKey: Key.baseURL)
        let storedURL = storedBaseURL.flatMap(URL.init(string:))
        let storedHost = storedURL?.host?.lowercased()
        let isLegacyOpenCodeGo = storedHost == "opencode.ai"
            && storedURL?.path.hasSuffix("/zen/go/v1") != true
            && storedURL?.path.hasSuffix("/zen/go/v1/chat/completions") != true

        if provider == .opencode, storedBaseURL == nil || isLegacyOpenCodeGo {
            self.baseURL = AIProvider.opencode.defaultBaseURL
        } else if provider != .custom, storedBaseURL == nil {
            self.baseURL = provider.defaultBaseURL
        } else {
            self.baseURL = storedBaseURL ?? provider.defaultBaseURL
        }

        self.apiKey = CredentialsStore.readAPIKey()

        let storedModel = defaults.string(forKey: Key.model)
        if provider != .custom, storedModel == nil || storedModel?.isEmpty == true {
            self.model = provider.defaultModel
        } else {
            self.model = storedModel ?? provider.defaultModel
        }

        self.explanationPrompt = defaults.string(forKey: Key.explanationPrompt)
            ?? "请用简体中文清晰解释这段内容，说明含义、上下文和必要的术语。回答不超过300个字符，可使用 Markdown 排版。"
        if let storedRate = defaults.object(forKey: Key.speechRate) as? Double {
            self.speechRate = storedRate
        }
        self.speechVoiceIdentifier = defaults.string(forKey: Key.speechVoice) ?? ""
        self.autoBubbleEnabled = defaults.object(forKey: Key.autoBubble) as? Bool ?? true
        self.clipboardPaused = defaults.bool(forKey: Key.clipboardPaused)
        self.assistantShortcut = Self.loadShortcut(defaults: defaults, key: Key.assistantShortcut) ?? .assistantDefault
        self.clipboardShortcut = Self.loadShortcut(defaults: defaults, key: Key.clipboardShortcut) ?? .clipboardDefault
    }

    var aiConfiguration: AIConfiguration {
        AIConfiguration(provider: aiProvider, baseURL: baseURL, apiKey: apiKey, model: model, explanationPrompt: explanationPrompt)
    }

    // MARK: - Provider switching

    /// Call when user explicitly changes the provider (not from init).
    func switchProvider(to newProvider: AIProvider) {
        aiProvider = newProvider
    }

    private func persistProvider() {
        defaults.set(aiProvider.rawValue, forKey: Key.provider)
    }

    private func applyPresetIfNeeded(from oldValue: AIProvider) {
        guard aiProvider != oldValue, aiProvider != .custom else { return }
        baseURL = aiProvider.defaultBaseURL
        model = aiProvider.defaultModel
    }

    private static func loadProvider(defaults: UserDefaults) -> AIProvider {
        if let stored = defaults.string(forKey: Key.provider).flatMap(AIProvider.init(rawValue:)) {
            return stored
        }
        let storedHost = (defaults.string(forKey: Key.baseURL)).flatMap(URL.init(string:))?.host?.lowercased()
        switch storedHost {
        case "api.deepseek.com": return .deepseek
        case "api.openai.com": return .openai
        case .some(let host) where host != "opencode.ai": return .custom
        default: return .opencode
        }
    }

    // MARK: - Persistence helpers

    private func save(_ shortcut: HotKeyShortcut, key: String) {
        if let data = try? JSONEncoder().encode(shortcut) {
            defaults.set(data, forKey: key)
        }
    }

    private static func loadShortcut(defaults: UserDefaults, key: String) -> HotKeyShortcut? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(HotKeyShortcut.self, from: data)
    }
}
