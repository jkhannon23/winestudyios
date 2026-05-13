//
//  QuestionStatsManager.swift
//  winestudyios
//
//  Tracks per-question performance to enable spaced repetition.
//
//  Uses a Leitner-box system: each question is in a "box" (1–5), and is
//  due for review when enough time has passed since it was last seen.
//
//      Box → review interval (days)
//        1 → 0    (review next session)
//        2 → 1
//        3 → 3
//        4 → 7
//        5 → 14   (mastered)
//
//  On answer:
//      correct → box = min(5, box + 1)
//      wrong   → box = 1
//      new     → starts at box 2 if first answer is correct, otherwise box 1
//

import Foundation

struct QuestionStatsManager {

    // MARK: - Public types

    struct Stats: Codable {
        var box: Int
        var seenCount: Int
        var correctCount: Int
        var lastSeen: Date?
    }

    // MARK: - Configuration

    private static let storeKey = "questionStats_v1"
    private static let maxBox = 5
    private static let boxIntervalDays = [0, 1, 3, 7, 14]  // index = box - 1

    /// Fraction of a quiz that should come from due-for-review items
    /// (the rest is filled with new questions, then non-due reviews).
    private static let reviewShare = 0.6

    // MARK: - Recording

    /// Update the stats for a question after the user answers it.
    static func recordAnswer(for question: Question, correct: Bool) {
        var store = load()
        let key = question.question
        var stats = store[key] ?? Stats(box: 1, seenCount: 0, correctCount: 0, lastSeen: nil)
        let isFirstSighting = stats.lastSeen == nil

        stats.seenCount += 1
        if correct {
            stats.correctCount += 1
            stats.box = isFirstSighting ? 2 : min(maxBox, stats.box + 1)
        } else {
            stats.box = 1
        }
        stats.lastSeen = Date()

        store[key] = stats
        save(store)
    }

    // MARK: - Selection

    /// Build a quiz that prioritises questions the learner needs to review,
    /// then introduces new material, then tops up with non-due reviews if needed.
    /// The final order is shuffled so review items don't always appear first.
    static func selectQuiz(from allQuestions: [Question], count: Int) -> [Question] {
        guard !allQuestions.isEmpty else { return [] }
        let store = load()
        let now = Date()

        var due: [(Question, Stats)] = []
        var notDue: [(Question, Stats)] = []
        var new: [Question] = []

        for q in allQuestions {
            if let s = store[q.question] {
                if isDue(s, now: now) {
                    due.append((q, s))
                } else {
                    notDue.append((q, s))
                }
            } else {
                new.append(q)
            }
        }

        // Weakest (lowest box) first; among same box, oldest lastSeen first.
        due.sort { lhs, rhs in
            if lhs.1.box != rhs.1.box { return lhs.1.box < rhs.1.box }
            return (lhs.1.lastSeen ?? .distantPast) < (rhs.1.lastSeen ?? .distantPast)
        }
        notDue.sort { ($0.1.lastSeen ?? .distantPast) < ($1.1.lastSeen ?? .distantPast) }
        new.shuffle()

        var picked: [Question] = []
        var pickedKeys = Set<String>()

        func tryAdd(_ q: Question) {
            guard picked.count < count, pickedKeys.insert(q.question).inserted else { return }
            picked.append(q)
        }

        // 1. Up to ~60% from due (weakest first), but at least 1 if any exist.
        let reviewTarget = max(due.isEmpty ? 0 : 1, Int(Double(count) * reviewShare))
        for (q, _) in due.prefix(reviewTarget) { tryAdd(q) }

        // 2. Fill with new questions.
        for q in new { tryAdd(q) }

        // 3. Take remaining due, still weakest-first.
        for (q, _) in due.dropFirst(reviewTarget) { tryAdd(q) }

        // 4. Last resort: non-due reviews, oldest lastSeen first.
        for (q, _) in notDue { tryAdd(q) }

        picked.shuffle()
        return picked
    }

    // MARK: - Inspection

    static func stats(for question: Question) -> Stats? {
        load()[question.question]
    }

    /// Returns the count of questions in each box (1...maxBox) plus the count
    /// of never-seen ("new") questions. Useful for a future mastery view.
    static func boxBreakdown(over allQuestions: [Question]) -> (boxes: [Int: Int], new: Int) {
        let store = load()
        var boxes: [Int: Int] = [:]
        var newCount = 0
        for q in allQuestions {
            if let s = store[q.question] {
                boxes[s.box, default: 0] += 1
            } else {
                newCount += 1
            }
        }
        return (boxes, newCount)
    }

    static func resetAll() {
        UserDefaults.standard.removeObject(forKey: storeKey)
    }

    // MARK: - Internals

    private static func isDue(_ s: Stats, now: Date) -> Bool {
        guard let lastSeen = s.lastSeen else { return true }
        let clampedBox = max(1, min(maxBox, s.box))
        let intervalSeconds = TimeInterval(boxIntervalDays[clampedBox - 1] * 86_400)
        return now.timeIntervalSince(lastSeen) >= intervalSeconds
    }

    private static func load() -> [String: Stats] {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let decoded = try? JSONDecoder().decode([String: Stats].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func save(_ store: [String: Stats]) {
        if let data = try? JSONEncoder().encode(store) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }
}
