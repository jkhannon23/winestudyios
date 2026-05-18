//
//  StreakManager.swift
//  winestudyios
//
//  Created by JILL HANNON on 14/03/26.
//

import Foundation

struct StreakManager {

    private static let lastDateKey = "streak_lastCompletedDate"
    private static let countKey = "streak_currentCount"

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.calendar = Calendar.current
        formatter.timeZone = TimeZone.current
        return formatter
    }()

    // MARK: - Public

    /// Returns the current streak count, resetting to 0 if more than a day has been missed.
    static var currentStreak: Int {
        guard let lastDate = UserDefaults.standard.string(forKey: lastDateKey) else {
            return 0
        }

        let today = todayString()

        if lastDate == today || lastDate == yesterdayString() {
            return UserDefaults.standard.integer(forKey: countKey)
        }

        // Streak has expired
        UserDefaults.standard.set(0, forKey: countKey)
        return 0
    }

    /// Records a quiz completion. Returns the updated streak count.
    /// Multiple completions on the same day only count once.
    @discardableResult
    static func recordCompletion() -> Int {
        let today = todayString()
        let lastDate = UserDefaults.standard.string(forKey: lastDateKey)
        var count = UserDefaults.standard.integer(forKey: countKey)

        if lastDate == today {
            // Already played today — no change
            return count
        }

        if lastDate == yesterdayString() {
            // Consecutive day — extend streak
            count += 1
        } else {
            // First ever play or missed a day — start fresh
            count = 1
        }

        UserDefaults.standard.set(today, forKey: lastDateKey)
        UserDefaults.standard.set(count, forKey: countKey)
        return count
    }

    // MARK: - Private Helpers

    private static func todayString() -> String {
        dateFormatter.string(from: Date())
    }

    private static func yesterdayString() -> String {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        return dateFormatter.string(from: yesterday)
    }
}
