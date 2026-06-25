import Foundation

struct AIUsageSnapshot: Equatable {
    let date: String
    let requestCount: Int
    let tokenCount: Int
    let dailyRequestLimit: Int
    let dailyTokenLimit: Int
}

final class AIUsageLimiter: @unchecked Sendable {
    static let shared = AIUsageLimiter()
    static let dailyRequestLimit = 50
    static let dailyTokenLimit = 100_000
    static let requestsPerMinuteLimit = 10

    private enum Key {
        static let date = "ai.usage.date"
        static let requests = "ai.usage.requests"
        static let tokens = "ai.usage.tokens"
    }

    private let lock = NSLock()
    private let defaults: UserDefaults
    private var recentRequests: [Date] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func authorizeRequest(now: Date = Date()) throws {
        lock.lock()
        defer { lock.unlock() }
        resetIfNeeded(now: now)
        recentRequests.removeAll { now.timeIntervalSince($0) > 60 }
        guard recentRequests.count < Self.requestsPerMinuteLimit else {
            throw AIClientError.usageLimit("请求过于频繁，请一分钟后再试")
        }
        let count = defaults.integer(forKey: Key.requests)
        guard count < Self.dailyRequestLimit else {
            throw AIClientError.usageLimit("今日 AI 请求次数已达到 \(Self.dailyRequestLimit) 次上限")
        }
        let tokens = defaults.integer(forKey: Key.tokens)
        guard tokens < Self.dailyTokenLimit else {
            throw AIClientError.usageLimit("今日 AI 用量已达到 \(Self.dailyTokenLimit) tokens 上限")
        }
        defaults.set(count + 1, forKey: Key.requests)
        recentRequests.append(now)
    }

    func recordTokenUsage(_ tokens: Int, now: Date = Date()) {
        guard tokens > 0 else { return }
        lock.lock()
        defer { lock.unlock() }
        resetIfNeeded(now: now)
        defaults.set(defaults.integer(forKey: Key.tokens) + tokens, forKey: Key.tokens)
    }

    func snapshot(now: Date = Date()) -> AIUsageSnapshot {
        lock.lock()
        defer { lock.unlock() }
        resetIfNeeded(now: now)
        return AIUsageSnapshot(
            date: Self.dayString(now),
            requestCount: defaults.integer(forKey: Key.requests),
            tokenCount: defaults.integer(forKey: Key.tokens),
            dailyRequestLimit: Self.dailyRequestLimit,
            dailyTokenLimit: Self.dailyTokenLimit
        )
    }

    private func resetIfNeeded(now: Date) {
        let today = Self.dayString(now)
        guard defaults.string(forKey: Key.date) != today else { return }
        defaults.set(today, forKey: Key.date)
        defaults.set(0, forKey: Key.requests)
        defaults.set(0, forKey: Key.tokens)
        recentRequests.removeAll()
    }

    private static func dayString(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
