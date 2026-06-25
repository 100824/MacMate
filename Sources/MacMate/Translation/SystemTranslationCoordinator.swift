import Foundation
import SwiftUI
import Translation

enum SystemTranslationError: LocalizedError {
    case unavailable
    case unsupported
    case languagePackNotInstalled
    case timeout

    var errorDescription: String? {
        switch self {
        case .unavailable:
            return "系统本地翻译需要 macOS 15 或更高版本，可点击“使用 AI 翻译”"
        case .unsupported:
            return "系统不支持这组语言的本地翻译，可点击“使用 AI 翻译”"
        case .languagePackNotInstalled:
            return "系统翻译语言包尚未安装，请先在 macOS 的翻译语言设置中下载，或点击“使用 AI 翻译”"
        case .timeout:
            return "系统本地翻译响应超时，可点击“使用 AI 翻译”"
        }
    }
}

@available(macOS 15.0, *)
@MainActor
final class SystemTranslationCoordinator: ObservableObject {
    @Published var configuration: TranslationSession.Configuration?

    private struct PendingRequest {
        let text: String
        let continuation: CheckedContinuation<String, Error>
    }

    private var pending: PendingRequest?
    private var timeoutTask: Task<Void, Never>?
    private var nextConfigurationID = 0

    func translate(_ text: String, source: Locale.Language, target: Locale.Language) async throws -> String {
        resetForNewRequest(clearConfiguration: true)
        let availability = await LanguageAvailability().status(from: source, to: target)
        guard availability != .unsupported else { throw SystemTranslationError.unsupported }
        guard availability == .installed else { throw SystemTranslationError.languagePackNotInstalled }

        return try await withCheckedThrowingContinuation { continuation in
            pending = PendingRequest(text: text, continuation: continuation)
            nextConfigurationID += 1
            configuration = TranslationSession.Configuration(source: source, target: target)
            startTimeout(text: text)
        }
    }

    func execute(using session: TranslationSession) async {
        guard let request = pending else {
            FileLogger.shared.error(.network, "system_translation_execute_no_pending")
            return
        }
        do {
            try await session.prepareTranslation()
            let response = try await session.translate(request.text)
            finish(.success(response.targetText))
        } catch is CancellationError {
            finish(.failure(CancellationError()))
        } catch {
            FileLogger.shared.error(.network, "system_translation_failed type=\(String(describing: type(of: error))) msg=\(error.localizedDescription)")
            finish(.failure(error))
        }
    }

    func cancel() {
        resetForNewRequest(clearConfiguration: true)
    }

    private func resetForNewRequest(clearConfiguration: Bool) {
        timeoutTask?.cancel()
        timeoutTask = nil
        if let request = pending {
            pending = nil
            request.continuation.resume(throwing: CancellationError())
        }
        if clearConfiguration {
            configuration?.invalidate()
            configuration = nil
        }
    }

    private func startTimeout(text: String) {
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(10 * 1_000_000_000))
            guard let self, let request = self.pending, request.text == text else { return }
            FileLogger.shared.error(.network, "system_translation_timeout text=\(text.prefix(20))")
            self.finish(.failure(SystemTranslationError.timeout))
            self.configuration?.invalidate()
            self.configuration = nil
        }
    }

    private func finish(_ result: Result<String, Error>) {
        timeoutTask?.cancel()
        timeoutTask = nil
        guard let request = pending else { return }
        pending = nil
        request.continuation.resume(with: result)
    }
}

@available(macOS 15.0, *)
struct SystemTranslationTaskHost: View {
    @ObservedObject var coordinator: SystemTranslationCoordinator

    var body: some View {
        Color.clear
            .frame(width: 0, height: 0)
            .translationTask(coordinator.configuration) { session in
                await coordinator.execute(using: session)
            }
    }
}
