import Foundation

private final class SelfTestURLProtocol: URLProtocol {
    static var responseData = Data()
    static var capturedRequest: URLRequest?
    static var capturedBody: Data?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.capturedRequest = request
        Self.capturedBody = request.httpBody ?? Self.read(stream: request.httpBodyStream)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.responseData)
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}

    private static func read(stream: InputStream?) -> Data? {
        guard let stream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 4_096)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

@MainActor
enum SelfTestRunner {
    private static var failures: [String] = []

    static func run() async -> Bool {
        failures = []
        print("MacMate self-test starting…")
        testLimits()
        testIPA()
        testPinyin()
        testUsageLimits()
        testClipboardPersistence()
        await testAIClient()
        testLanguageDetection()
        if failures.isEmpty {
            print("SELF-TEST PASSED: 7 suites")
            return true
        }
        failures.forEach { print("SELF-TEST FAILURE: \($0)") }
        print("SELF-TEST FAILED: \(failures.count) checks")
        return false
    }

    private static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { failures.append(message) }
    }

    private static func testLimits() {
        check(String(repeating: "a", count: 2_000).count == AppConstants.maximumInputCharacters, "input character limit")
    }

    private static func testPinyin() {
        let pinyin = PinyinService.transcribe("你好，世界")
        check(pinyin.contains("nǐ hǎo"), "offline Chinese pinyin")
        check(pinyin.contains("shì jiè"), "pinyin tone marks")
    }

    private static func testIPA() {
        let dictionary = "hello  HH AH0 L OW1\nworld  W ER1 L D\nread  R IY1 D\nread(2)  R EH1 D"
        let service = IPAService(dictionaryText: dictionary)
        let known = service.transcribe("Hello world")
        check(known.transcription == "/həlˈoʊ wˈɝld/", "ARPABET to IPA conversion")
        check(known.unknownWords.isEmpty, "known pronunciation lookup")
        let unknown = service.transcribe("MacMate")
        check(unknown.transcription == "/[MacMate ?]/", "unknown pronunciation marker")
        let bundled = IPAService.shared.transcribe("hello")
        check(!bundled.transcription.contains("?"), "bundled CMUdict resource loading")
        check(Bundle.module.url(forResource: "CMUdict-LICENSE", withExtension: "txt") != nil, "bundled CMUdict license")
    }

    private static func testUsageLimits() {
        let suite = "MacMateSelfTestUsage-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            failures.append("isolated usage defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let limiter = AIUsageLimiter(defaults: defaults)
        let now = Date()
        do {
            for _ in 0..<10 { try limiter.authorizeRequest(now: now) }
            do {
                try limiter.authorizeRequest(now: now)
                failures.append("per-minute request limit")
            } catch {}
            limiter.recordTokenUsage(321, now: now)
            check(limiter.snapshot(now: now).tokenCount == 321, "token usage tracking")
        } catch {
            failures.append("usage limiter setup")
        }
    }

    private static func testClipboardPersistence() {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("MacMateSelfTestClipboard-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: root) }
        let store = ClipboardStore(rootDirectory: root)
        for index in 0..<11 {
            let text = "item-\(index)"
            store.add(ClipboardCapture(kind: .text, text: text, rtfData: nil, imagePNGData: nil, sourceApplication: "SelfTest", contentHash: ClipboardHash.sha256(Data(text.utf8))))
        }
        check(store.entries.count == 10, "clipboard ten-entry retention")
        check(store.entries.first?.text == "item-10", "clipboard newest-first order")
        let reloaded = ClipboardStore(rootDirectory: root)
        check(reloaded.entries.map(\.text) == store.entries.map(\.text), "clipboard persistence round-trip")
    }

    private static func testAIClient() async {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [SelfTestURLProtocol.self]
        let suite = "MacMateSelfTestAI-\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: suite) else {
            failures.append("isolated AI defaults")
            return
        }
        defer { defaults.removePersistentDomain(forName: suite) }
        let client = AIClient(session: URLSession(configuration: sessionConfiguration), usageLimiter: AIUsageLimiter(defaults: defaults))
        let longText = String(repeating: "字", count: 2_500)
        let response: [String: Any] = ["choices": [["message": ["content": longText]]], "usage": ["total_tokens": 12]]
        SelfTestURLProtocol.responseData = (try? JSONSerialization.data(withJSONObject: response)) ?? Data()
        do {
            let configuration = AIConfiguration(provider: .opencode, baseURL: "https://opencode.ai/zen/go/v1", apiKey: "self-test", model: "deepseek-v4-flash", explanationPrompt: "Explain")
            let output = try await client.chat(configuration: configuration, systemPrompt: "System", userText: "Hello", maximumTokens: 12)
            check(output.count == 2500, "AI full output length preserved")
            check(SelfTestURLProtocol.capturedRequest?.url?.absoluteString == "https://opencode.ai/zen/go/v1/chat/completions", "OpenCode Go endpoint composition")
            if let body = SelfTestURLProtocol.capturedBody,
               let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                check(object["model"] as? String == "deepseek-v4-flash", "OpenCode Go model")
                // All providers now send thinking: disabled to disable reasoning chains
                check((object["thinking"] as? [String: String])?["type"] == "disabled", "All providers should send thinking: disabled")
                check(object["max_tokens"] as? Int == 12, "request token cap")
            } else {
                failures.append("AI request payload capture")
            }
            do {
                _ = try client.endpointURL(from: "http://example.com/v1")
                failures.append("remote HTTP rejection")
            } catch {}

            // Test DeepSeek provider — should send thinking: disabled
            let deepseekConfiguration = AIConfiguration(provider: .deepseek, baseURL: "https://api.deepseek.com", apiKey: "test", model: "deepseek-chat", explanationPrompt: "Explain")
            SelfTestURLProtocol.responseData = (try? JSONSerialization.data(withJSONObject: response)) ?? Data()
            _ = try? await client.chat(configuration: deepseekConfiguration, systemPrompt: "System", userText: "Hi", maximumTokens: 8)
            if let body = SelfTestURLProtocol.capturedBody,
               let object = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                check((object["thinking"] as? [String: String])?["type"] == "disabled", "DeepSeek provider should set non-thinking mode")
            }
        } catch {
            failures.append("AI mock request: \(error.localizedDescription)")
        }
    }

    private static func testLanguageDetection() {
        check(SelectionViewModel.detectLanguage("This is an English sentence.") == .english, "English language detection")
        let chinese = SelectionViewModel.detectLanguage("这是一段用于测试的中文内容。")
        check(chinese == .simplifiedChinese || chinese == .traditionalChinese, "Chinese language detection")
    }
}
