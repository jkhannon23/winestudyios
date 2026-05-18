//
//  DailyChallengeManager.swift
//  winestudyios
//

import Foundation

struct DailyChallengeManager {

    // MARK: - Configuration

    /// Base URL of your daily-challenges directory — no trailing slash.
    /// Each file must be named YYYY-MM-DD.json and contain:
    ///   { "date": "YYYY-MM-DD", "questionIds": ["<16-char hex>", ...] }
    ///
    /// Once you've pushed the daily-challenges/ folder to GitHub, set this to:
    ///   "https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/daily-challenges"
    ///
    /// Leave empty to always use the local deterministic fallback.
    static let serverBaseURL = ""

    // MARK: - UserDefaults Keys

    private static let completedDateKey   = "daily_completedDate"
    private static let scoreKey           = "daily_score"
    private static let serverCachePrefix  = "daily_server_"   // + YYYY-MM-DD → [String]

    // MARK: - Date Formatter

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar.current
        return formatter
    }()

    // MARK: - Server Prefetch

    /// Fire-and-forget. Call early (e.g. in viewDidLoad) so the server
    /// result is cached before the user taps Daily Challenge.
    ///
    /// On success the question IDs for today are stored in UserDefaults.
    /// On failure (offline, 404, wrong date) the local fallback is used silently.
    static func prefetchTodaysChallenge() {
        let dateStr = todayString()

        // Nothing to do if server is not configured or we already have today's cache.
        guard
            !serverBaseURL.isEmpty,
            UserDefaults.standard.stringArray(forKey: serverCachePrefix + dateStr) == nil,
            let url = URL(string: "\(serverBaseURL)/\(dateStr).json")
        else { return }

        var request = URLRequest(url: url, timeoutInterval: 8)
        request.cachePolicy = .reloadIgnoringLocalCacheData

        URLSession.shared.dataTask(with: request) { data, response, _ in
            guard
                let data,
                (response as? HTTPURLResponse)?.statusCode == 200,
                let payload = try? JSONDecoder().decode(DailyPayload.self, from: data),
                payload.date == dateStr,
                !payload.questionIds.isEmpty
            else { return }

            // Cache the IDs — questionsForToday() will pick them up synchronously.
            UserDefaults.standard.set(payload.questionIds, forKey: serverCachePrefix + dateStr)
        }.resume()
    }

    // MARK: - Question Selection

    /// Returns today's questions.
    ///
    /// Priority:
    ///   1. Server-specified IDs (if prefetchTodaysChallenge() has completed)
    ///   2. Local deterministic fallback (same date → same questions on every device)
    static func questionsForToday(from allQuestions: [Question], count: Int = 10) -> [Question] {
        guard !allQuestions.isEmpty else { return [] }

        let dateStr = todayString()

        // --- Server path ---
        if let ids = UserDefaults.standard.stringArray(forKey: serverCachePrefix + dateStr) {
            let lookup = Dictionary(
                allQuestions.map { ($0.stableId, $0) },
                uniquingKeysWith: { first, _ in first }
            )
            let resolved = ids.compactMap { lookup[$0] }
            // Only use server result if we got the full set; fall through on partial match
            // (e.g. a question was removed from the bundle after publishing the server file).
            if resolved.count == count { return resolved }
        }

        // --- Local deterministic fallback ---
        // Swift's String.hashValue is process-randomised; FNV-1a gives the same
        // seed on every launch and every device for the same date string.
        var rng = SeededRandomNumberGenerator(seed: stableSeed(for: dateStr))
        return Array(allQuestions.shuffled(using: &rng).prefix(count))
    }

    // MARK: - Completion Tracking

    static var hasCompletedToday: Bool {
        UserDefaults.standard.string(forKey: completedDateKey) == todayString()
    }

    static var todayScore: Int? {
        guard hasCompletedToday else { return nil }
        return UserDefaults.standard.integer(forKey: scoreKey)
    }

    static func recordScore(_ score: Int) {
        UserDefaults.standard.set(todayString(), forKey: completedDateKey)
        UserDefaults.standard.set(score, forKey: scoreKey)
    }

    // MARK: - Hashing (internal so Question extension can call it)

    /// FNV-1a 64-bit hash. Produces the same value on every device / launch
    /// for the same input string, and matches the Python implementation in
    /// generate_daily_challenges.py.
    static func stableSeed(for string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }

    // MARK: - Private

    private static func todayString() -> String {
        dateFormatter.string(from: Date())
    }
}

// MARK: - Question stable ID

extension Question {
    /// 16-character hex string derived from the question text via FNV-1a.
    /// Stable across app versions as long as the question wording is unchanged.
    /// Used by the server path in DailyChallengeManager to look up questions.
    var stableId: String {
        String(format: "%016x", DailyChallengeManager.stableSeed(for: question))
    }
}

// MARK: - Server Payload

private struct DailyPayload: Decodable {
    let date: String
    let questionIds: [String]
}

// MARK: - Seeded RNG (local deterministic fallback)

/// A simple xorshift64 RNG for deterministic shuffling.
/// Matches the algorithm used in the previous version of this file.
private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed == 0 ? 1 : seed   // xorshift undefined for 0
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
