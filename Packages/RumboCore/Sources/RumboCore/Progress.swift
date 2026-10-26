import Foundation

/// Streaks, freezes and XP. See docs/02-learning-engine.md §2.8.
public struct StreakCalculator: Sendable {
    public static let minutesForStreakDay = 10
    public static let maxFreezes = 3

    public var calendar: Calendar
    public var weeklyGoalMinutes: Int

    public init(weeklyGoalMinutes: Int, calendar: Calendar = .current) {
        self.weeklyGoalMinutes = weeklyGoalMinutes
        self.calendar = calendar
    }

    public struct Status: Equatable, Sendable {
        public var streak: Int
        public var freezes: Int
        public var minutesThisWeek: Int
    }

    /// Replays the whole history day by day. Today only counts once it reaches the threshold,
    /// and an unfinished today never breaks the streak.
    public func status(history: [ActivityRecord], today: Date) -> Status {
        let todayStart = calendar.startOfDay(for: today)
        var minutesByDay: [Date: Int] = [:]
        for record in history {
            minutesByDay[calendar.startOfDay(for: record.date), default: 0] += record.minutes
        }
        guard let first = minutesByDay.keys.min(), first <= todayStart else {
            return Status(streak: 0, freezes: 0, minutesThisWeek: 0)
        }

        var streak = 0
        var freezes = 0
        var weekMinutes = 0
        var day = first
        while day <= todayStart {
            let minutes = minutesByDay[day] ?? 0
            weekMinutes += minutes
            if minutes >= Self.minutesForStreakDay {
                streak += 1
            } else if day < todayStart {
                if freezes > 0 {
                    freezes -= 1
                } else {
                    streak = 0
                }
            }

            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            let weekEnds = !calendar.isDate(nextDay, equalTo: day, toGranularity: .weekOfYear)
            if weekEnds && day < todayStart {
                if weekMinutes >= weeklyGoalMinutes {
                    freezes = min(Self.maxFreezes, freezes + 1)
                }
                weekMinutes = 0
            }
            day = nextDay
        }
        return Status(streak: streak, freezes: freezes, minutesThisWeek: weekMinutes)
    }
}

public enum XP {
    public static let perMinute = 1
    public static let perCompletedCard = 10
    public static let perRewrite = 25
    public static let perGatePassed = 50

    public static func total(minutes: Int, completedCards: Int, rewrites: Int, gatesPassed: Int) -> Int {
        minutes * perMinute + completedCards * perCompletedCard + rewrites * perRewrite + gatesPassed * perGatePassed
    }
}

/// Projects when the learner reaches each band. See docs/02-learning-engine.md §2.9.
public struct Projection: Sendable {
    public static let averagingWeeks = 4

    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    /// Days of history needed before the forecast uses the learner's own pace.
    public static let minimumDaysOfHistory = 7

    /// Input hours per week, averaged over the last 4 weeks (bonus input included).
    /// A newer learner's average covers only the days since their first log, so one short
    /// session on day one isn't read as a pace kept up for a month.
    public func weeklyInputHours(history: [ActivityRecord], today: Date) -> Double {
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: today)!)
        let windowStart = calendar.date(byAdding: .day, value: -7 * Self.averagingWeeks, to: end)!
        guard let firstLog = history.map(\.date).min() else { return 0 }
        let start = max(windowStart, calendar.startOfDay(for: firstLog))
        let days = max(Double(Self.minimumDaysOfHistory), Double(calendar.dateComponents([.day], from: start, to: end).day ?? 0))
        let minutes = history
            .filter { $0.kind.countsAsInput && $0.date >= start && $0.date < end }
            .reduce(0) { $0 + $1.minutes }
        return Double(minutes) / 60 / days * 7
    }

    /// Whether there's enough history for `weeklyInputHours` to mean something.
    public func hasEnoughHistory(_ history: [ActivityRecord], today: Date) -> Bool {
        guard let firstLog = history.map(\.date).min() else { return false }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: firstLog), to: calendar.startOfDay(for: today)).day ?? 0
        return days + 1 >= Self.minimumDaysOfHistory
    }

    /// The pace a learner would keep by meeting their weekly goal, used until there's a week of history.
    public static func weeklyInputHours(atGoalMinutes goal: Int, band: Band) -> Double {
        Double(goal) * (band.strandTargets[.input] ?? 0) / 60
    }

    /// The date each remaining band threshold is reached at `weeklyHours`, or nil if the pace is zero.
    public func arrivalDates(inputHours: Double, weeklyHours: Double, from today: Date) -> [Band: Date] {
        guard weeklyHours > 0 else { return [:] }
        var dates: [Band: Date] = [:]
        for band in Band.allCases where band.inputHoursThreshold > inputHours {
            let weeks = (band.inputHoursThreshold - inputHours) / weeklyHours
            dates[band] = calendar.date(byAdding: .day, value: Int((weeks * 7).rounded(.up)), to: today)
        }
        return dates
    }

    /// Input hours expected by `date` at the current pace plus `extraMinutesPerDay`.
    public func inputHours(by date: Date, from today: Date, current: Double, weeklyHours: Double, extraMinutesPerDay: Int = 0) -> Double {
        let days = Double(calendar.dateComponents([.day], from: today, to: date).day ?? 0)
        let perDay = weeklyHours / 7 + Double(extraMinutesPerDay) / 60
        return current + max(0, days) * perDay
    }
}
