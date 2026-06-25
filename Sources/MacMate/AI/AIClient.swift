import Foundation

enum AIClientError: LocalizedError, Equatable {
    case invalidConfiguration
    case invalidURL
    case transport(String)
    case http(status: Int, message: String)
    case invalidResponse
    case emptyResponse
    case usageLimit(String)

    var errorDescription: String? {
        switch self {
        case .invalidConfiguration: return "请先填写有效的 Base URL 和模型名"
        case .invalidURL: return "Base URL 无效；仅支持 HTTPS 或本机 HTTP"
        case .transport(let message): return "网络请求失败：\(message)"
        case .http(let status, let message): return "服务返回错误（\(status)）：\(message)"
        case .invalidResponse: return "服务返回了无法识别的数据"
        case .emptyResponse: return "服务没有返回内容"
        case .usageLimit(let message): return message
        }
    }
}

struct AIClient: Sendable {
    private struct Message: Codable {
        let role: String
        let content: String
    }

    private struct RequestBody: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let max_tokens: Int
        let stream: Bool
        let thinking: Thinking?

        struct Thinking: Codable { let type: String }
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct ResponseMessage: Decodable {
                let content: String?
            }
            let message: ResponseMessage
        }
        let choices: [Choice]
        let usage: Usage?

        struct Usage: Decodable {
            let prompt_tokens: Int?
            let completion_tokens: Int?
            let total_tokens: Int?
        }
    }

    private struct ErrorBody: Decodable {
        struct ServiceError: Decodable { let message: String? }
        let error: ServiceError?
    }

    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable { let content: String? }
            let delta: Delta?
        }
        let choices: [Choice]?
        let usage: Usage?

        struct Usage: Decodable {
            let total_tokens: Int?
        }
    }

    let session: URLSession
    let usageLimiter: AIUsageLimiter

    init(session: URLSession = .shared, usageLimiter: AIUsageLimiter = .shared) {
        self.session = session
        self.usageLimiter = usageLimiter
    }

    func chat(
        configuration: AIConfiguration,
        systemPrompt: String,
        userText: String,
        maximumTokens: Int = 2_000
    ) async throws -> String {
        guard configuration.isUsable else { throw AIClientError.invalidConfiguration }
        try usageLimiter.authorizeRequest()
        let endpoint = try endpointURL(from: configuration.baseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !configuration.apiKey.isEmpty {
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(RequestBody(
            model: configuration.model,
            messages: [Message(role: "system", content: systemPrompt), Message(role: "user", content: userText)],
            temperature: 0.2,
            max_tokens: maximumTokens,
            stream: false,
            thinking: configuration.provider == .deepseek ? .init(type: "disabled") : nil
        ))

        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw AIClientError.invalidResponse }
            guard (200..<300).contains(http.statusCode) else {
                let serviceMessage = (try? JSONDecoder().decode(ErrorBody.self, from: data).error?.message)
                    ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                FileLogger.shared.error(.network, "request_failed status=\(http.statusCode) response_bytes=\(data.count)")
                throw AIClientError.http(status: http.statusCode, message: serviceMessage)
            }
            let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
            guard let content = decoded.choices.first?.message.content?.nonEmptyTrimmed else {
                throw AIClientError.emptyResponse
            }
            usageLimiter.recordTokenUsage(decoded.usage?.total_tokens ?? 0)
            let limited = content.limitedWithNotice(to: AppConstants.maximumOutputCharacters)
            FileLogger.shared.info(.network, "request_succeeded input_chars=\(userText.count) output_chars=\(content.count) truncated=\(content.count > AppConstants.maximumOutputCharacters)")
            return limited
        } catch let error as AIClientError {
            throw error
        } catch {
            FileLogger.shared.error(.network, "transport_failed type=\(String(describing: type(of: error)))")
            throw AIClientError.transport(error.localizedDescription)
        }
    }

    func chatStream(
        configuration: AIConfiguration,
        systemPrompt: String,
        userText: String,
        maximumTokens: Int = 2_000
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    guard configuration.isUsable else { throw AIClientError.invalidConfiguration }
                    try usageLimiter.authorizeRequest()
                    let endpoint = try endpointURL(from: configuration.baseURL)
                    var request = URLRequest(url: endpoint)
                    request.httpMethod = "POST"
                    request.timeoutInterval = 120
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                    if !configuration.apiKey.isEmpty {
                        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
                    }
                    request.httpBody = try JSONEncoder().encode(RequestBody(
                        model: configuration.model,
                        messages: [Message(role: "system", content: systemPrompt), Message(role: "user", content: userText)],
                        temperature: 0.2,
                        max_tokens: maximumTokens,
                        stream: true,
                        thinking: configuration.provider == .deepseek ? .init(type: "disabled") : nil
                    ))

                    let (bytes, response) = try await session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else { throw AIClientError.invalidResponse }
                    guard (200..<300).contains(http.statusCode) else {
                        var errorData = Data()
                        for try await byte in bytes { errorData.append(byte) }
                        let serviceMessage = (try? JSONDecoder().decode(ErrorBody.self, from: errorData).error?.message)
                            ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
                        throw AIClientError.http(status: http.statusCode, message: serviceMessage)
                    }

                    var totalTokens = 0
                    for try await line in bytes.lines {
                        guard !Task.isCancelled else { break }
                        guard line.hasPrefix("data: ") else { continue }
                        let json = String(line.dropFirst(6))
                        guard json != "[DONE]" else { break }
                        guard let data = json.data(using: .utf8),
                              let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data) else { continue }
                        if let content = chunk.choices?.first?.delta?.content {
                            continuation.yield(content)
                        }
                        if let usage = chunk.usage {
                            totalTokens = usage.total_tokens ?? 0
                        }
                    }

                    usageLimiter.recordTokenUsage(totalTokens)
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }

    func test(configuration: AIConfiguration) async throws {
        guard configuration.isUsable else { throw AIClientError.invalidConfiguration }
        try usageLimiter.authorizeRequest()
        let endpoint = try endpointURL(from: configuration.baseURL)
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !configuration.apiKey.isEmpty {
            request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(RequestBody(
            model: configuration.model,
            messages: [Message(role: "user", content: "Hi")],
            temperature: 0.2,
            max_tokens: 8,
            stream: false,
            thinking: configuration.provider == .deepseek ? .init(type: "disabled") : nil
        ))

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw AIClientError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            let serviceMessage = (try? JSONDecoder().decode(ErrorBody.self, from: data).error?.message)
                ?? HTTPURLResponse.localizedString(forStatusCode: http.statusCode)
            throw AIClientError.http(status: http.statusCode, message: serviceMessage)
        }
        // 只要 HTTP 200 且返回合法 JSON 即认为连通；某些模型可能只返回空 content。
        guard (try? JSONSerialization.jsonObject(with: data)) != nil else {
            throw AIClientError.invalidResponse
        }
    }

    func endpointURL(from baseURL: String) throws -> URL {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let base = URL(string: trimmed),
              let scheme = base.scheme?.lowercased(), let host = base.host?.lowercased() else {
            throw AIClientError.invalidURL
        }
        let isSecure = scheme == "https"
        let isLocal = scheme == "http" && (host == "localhost" || host == "127.0.0.1" || host == "::1")
        guard isSecure || isLocal else { throw AIClientError.invalidURL }
        if base.path.hasSuffix("/chat/completions") { return base }
        // Build path safely — avoid URL.appendingPathComponent which may replace the
        // last segment when hasDirectoryPath is false
        let separator = trimmed.hasSuffix("/") ? "" : "/"
        guard let endpoint = URL(string: trimmed + separator + "chat/completions") else {
            throw AIClientError.invalidURL
        }
        return endpoint
    }
}
