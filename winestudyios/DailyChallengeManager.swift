//
//  DailyChallengeManager.swift
//  winestudyios
//

import Foundation

struct DailyChallengeManager {

    private static let completedDateKey = "daily_completedDate"
    private static let scoreKey = "daily_score"

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar.current
        return formatter
    }()

    // MARK: - Question Selection

    /// Returns a deterministic set of 10 questions for today's date.
    /// The same date always produces the same questions in the same order.
    static func questionsForToday(from allQuestions: [Question], count: Int = 10) -> [Question] {
        guard !allQuestions.isEmpty else { return [] }
        var rng = SeededRandomNumberGenerator(seed: stableSeed(for: todayString()))
        let shuffled = allQuestions.shuffled(using: &rng)
        return Array(shuffled.prefix(count))
    }

    // Swift's String.hashValue is randomized per process, so it can't be used
    // as a reproducible seed. FNV-1a 64-bit gives the same value every launch.
    private static func stableSeed(for string: String) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in string.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
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

    // MARK: - Private

    private static func todayString() -> String {
        dateFormatter.string(from: Date())
    }
}

// MARK: - Seeded RNG

/// A simple seeded random number generator for deterministic shuffling.
private struct SeededRandomNumberGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        // xorshift64
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}
