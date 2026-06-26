import AppKit
import Combine
import Foundation
import NaturalLanguage

@MainActor
final class SelectionViewModel: ObservableObject {
    @Published private(set) var selectedText = ""
    @Published private(set) var anchorBounds = CGRect.zero
    @Published private(set) var resultText = ""
    @Published private(set) var errorMessage = ""
    @Published private(set) var isLoading = false
    @Published private(set) var activeAction: AssistantAction?
    @Published private(set) var translationProvider = ""
    @Published private(set) var isUsingAITranslation = false
    @Published private(set) var translationRequestID = 0
    @Published private(set) var pronunciationTitle = "读音"
    @Published private(set) var pronunciationText = ""

    private let settings: AppSettings
    private let aiClient: AIClient
    private let pronunciation: IPAService
    private let speech: SpeechService
    private let systemTranslationStorage: Any
    private var task: Task<Void, Never>?

    init(settings: AppSettings, aiClient: AIClient = AIClient(), pronunciation: IPAService = .shared, speech: SpeechService) {
        self.settings = settings
        self.aiClient = aiClient
        self.pronunciation = pronunciation
        self.speech = speech
        if #available(macOS 15.0, *) {
            systemTranslationStorage = SystemTranslationCoordinator()
        } else {
            systemTranslationStorage = NSObject()
        }
    }

    @available(macOS 15.0, *)
    var systemTranslationCoordinator: SystemTranslationCoordinator {
        guard let coordinator = systemTranslationStorage as? SystemTranslationCoordinator else {
            fatalError("SystemTranslationCoordinator is not available on this OS version")
        }
        return coordinator
    }

    var exceedsInputLimit: Bool { selectedText.count > AppConstants.maximumInputCharacters }

    func setSelection(_ selection: AccessibleSelection) {
        cancel()
        selectedText = selection.text
        anchorBounds = selection.appKitBounds
        resultText = ""
        errorMessage = exceedsInputLimit ? "最多处理 \(AppConstants.maximumInputCharacters) 个字符，当前为 \(selectedText.count) 个字符。" : ""
        activeAction = nil
        translationProvider = ""
        pronunciationText = ""
    }

    func perform(_ action: AssistantAction) {
        guard !exceedsInputLimit else {
            errorMessage = "最多处理 \(AppConstants.maximumInputCharacters) 个字符，当前为 \(selectedText.count) 个字符。"
            return
        }
        cancel()
        activeAction = action
        isUsingAITranslation = false
        if action == .translate {
            translationRequestID += 1
        }
        errorMessage = ""
        resultText = ""
        translationProvider = ""

        switch action {
        case .translate:
            preparePronunciation()
            runSystemTranslation()
        case .explain:
            preparePronunciation()
            runAIExplanation()
        }
    }

    func translateWithAI() {
        guard activeAction == .translate, !exceedsInputLimit else { return }
        cancel()
        isUsingAITranslation = true
        errorMessage = ""
        resultText = ""
        translationProvider = "AI"
        isLoading = true
        let input = selectedText
        let configuration = settings.aiConfiguration
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let translation = try await self.aiTranslation(input, configuration: configuration)
                guard !Task.isCancelled else { return }
                self.resultText = self.formatTranslation(input: input, translation: translation)
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    func retry() {
        guard let activeAction else { return }
        if activeAction == .translate, isUsingAITranslation {
            translateWithAI()
        } else {
            perform(activeAction)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        if #available(macOS 15.0, *) {
            systemTranslationCoordinator.cancel()
        }
        isLoading = false
    }

    func copyResult() {
        guard !resultText.isEmpty else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(resultText, forType: .string)
    }

    func speakSelection() {
        speech.speak(selectedText, voiceIdentifier: settings.speechVoiceIdentifier, rate: settings.speechRate)
    }

    private func runSystemTranslation() {
        translationProvider = "系统本地"
        isLoading = true
        let input = selectedText
        let languages = Self.translationLanguages(for: input)
        task = Task { [weak self] in
            guard let self else { return }
            do {
                guard let source = languages.source else { throw SystemTranslationError.unsupported }
                let translation: String
                if #available(macOS 15.0, *) {
                    translation = try await self.systemTranslationCoordinator.translate(input, source: source, target: languages.target)
                } else {
                    throw SystemTranslationError.unavailable
                }
                guard !Task.isCancelled else { return }
                self.resultText = self.formatTranslation(input: input, translation: translation)
                self.isLoading = false
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                // 系统本地翻译失败时自动回退到 AI 翻译，统一译为简体中文。
                self.translateWithAI()
            }
        }
    }

    private func runAIExplanation() {
        isLoading = true
        let input = selectedText
        let configuration = settings.aiConfiguration
        let prompt = configuration.explanationPrompt
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let explanation = try await self.aiClient.chat(
                    configuration: configuration,
                    systemPrompt: prompt,
                    userText: input,
                    maximumTokens: 800
                )
                guard !Task.isCancelled else { return }
                self.resultText = explanation
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                self.errorMessage = error.localizedDescription
            }
            self.isLoading = false
        }
    }

    private func preparePronunciation() {
        switch Self.detectLanguage(selectedText) {
        case .english:
            let ipa = pronunciation.transcribe(selectedText)
            pronunciationTitle = "英文音标"
            pronunciationText = ipa.transcription
            if !ipa.unknownWords.isEmpty {
                let words = ipa.unknownWords.prefix(6).joined(separator: "、")
                pronunciationText += "\n（部分词未收录：\(words)）"
            }
        case .simplifiedChinese, .traditionalChinese:
            pronunciationTitle = "中文拼音"
            pronunciationText = PinyinService.transcribe(selectedText)
        default:
            pronunciationTitle = "系统读音"
            pronunciationText = "点击扬声器使用系统语音朗读"
        }
    }

    private func aiTranslation(_ input: String, configuration: AIConfiguration) async throws -> String {
        return try await aiClient.chat(
            configuration: configuration,
            systemPrompt: "将以下文本准确翻译成简体中文。先给出译文，然后用一句话简要说明核心含义或语境。不要输出音标。",
            userText: input
        )
    }

    private func formatTranslation(input: String, translation: String) -> String {
        let language = Self.detectLanguage(input)
        let combined: String
        if language == .english {
            let ipa = pronunciation.transcribe(input).transcription
            combined = "### 译文\n\(translation)\n\n### 英文音标\n\(ipa)"
        } else if language == .simplifiedChinese || language == .traditionalChinese {
            let ipa = pronunciation.transcribe(translation).transcription
            combined = "### 译文\n\(translation)\n\n### 英文音标\n\(ipa)"
        } else {
            combined = "### 译文\n\(translation)"
        }
        return combined
    }

    private static func translationLanguages(for text: String) -> (source: Locale.Language?, target: Locale.Language) {
        switch detectLanguage(text) {
        case .english:
            return (Locale.Language(identifier: "en"), Locale.Language(identifier: "zh"))
        case .simplifiedChinese:
            return (Locale.Language(identifier: "zh"), Locale.Language(identifier: "en"))
        case .traditionalChinese:
            return (Locale.Language(identifier: "zh-TW"), Locale.Language(identifier: "en"))
        case let language?:
            return (Locale.Language(identifier: language.rawValue), Locale.Language(identifier: "zh"))
        case nil:
            return (nil, Locale.Language(identifier: "zh"))
        }
    }

    static func detectLanguage(_ text: String) -> NLLanguage? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        return recognizer.dominantLanguage
    }
}
