import Foundation

/// Streaks and freezes. See docs/02-learning-engine.md §2.8.
public struct StreakCalculator: Sendable {
    /// Any logged practice keeps the streak going: a partial day (even just Duolingo) counts.
    public static let minutesForStreakDay = 1
    /// Freezes held at most.
    public static let maxFreezes = 2
    /// Every learner starts with one.
    public static let startingFreezes = 1
    /// Every second week the weekly goal is met earns a freeze.
    public static let goalWeeksPerFreeze = 2

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
        /// The last day a freeze covered, if the streak it saved is still going.
        public var lastFreezeUsed: Date? = nil
        /// Every day a freeze covered (start of day), for the path.
        public var frozenDays: [Date] = []
        /// The last day of each week that earned a freeze (start of day), for the path.
        public var freezesEarned: [Date] = []
        /// Weeks with the goal met since the last freeze was earned (0 or 1).
        public var goalWeeksTowardFreeze: Int = 0
    }

    /// Replays the whole history day by day. Today only counts once something is logged, and an
    /// unfinished today never breaks the streak. A missed day uses a freeze only if there's a streak to save.
    public func status(history: [ActivityRecord], today: Date) -> Status {
        let todayStart = calendar.startOfDay(for: today)
        var minutesByDay: [Date: Int] = [:]
        for record in history {
            minutesByDay[calendar.startOfDay(for: record.date), default: 0] += record.minutes
        }
        guard let first = minutesByDay.keys.min(), first <= todayStart else {
            return Status(streak: 0, freezes: Self.startingFreezes, minutesThisWeek: 0)
        }

        var status = Status(streak: 0, freezes: Self.startingFreezes, minutesThisWeek: 0)
        var day = first
        while day <= todayStart {
            let minutes = minutesByDay[day] ?? 0
            status.minutesThisWeek += minutes
            if minutes >= Self.minutesForStreakDay {
                status.streak += 1
            } else if day < todayStart && status.streak > 0 {
                if status.freezes > 0 {
                    status.freezes -= 1
                    status.lastFreezeUsed = day
                    status.frozenDays.append(day)
                } else {
                    status.streak = 0
                    status.lastFreezeUsed = nil
                }
            }

            let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
            let weekEnds = !calendar.isDate(nextDay, equalTo: day, toGranularity: .weekOfYear)
            if weekEnds && day < todayStart {
                if status.minutesThisWeek >= weeklyGoalMinutes {
                    status.goalWeeksTowardFreeze += 1
                    if status.goalWeeksTowardFreeze >= Self.goalWeeksPerFreeze {
                        status.goalWeeksTowardFreeze = 0
                        // With the inventory full, the reward is skipped and counting starts again.
                        if status.freezes < Self.maxFreezes {
                            status.freezes += 1
                            status.freezesEarned.append(day)
                        }
                    }
                }
                status.minutesThisWeek = 0
            }
            day = nextDay
        }
        return status
    }

    /// The last day of the week that would earn the next freeze if the goal is met until then
    /// (this week if one goal week is already banked, otherwise next week), or nil with the inventory full.
    public func nextFreezeWeekEnd(_ status: Status, today: Date) -> Date? {
        guard status.freezes < Self.maxFreezes,
              let week = calendar.dateInterval(of: .weekOfYear, for: today) else { return nil }
        let weeksAhead = Self.goalWeeksPerFreeze - 1 - status.goalWeeksTowardFreeze
        let lastDay = calendar.date(byAdding: .day, value: -1, to: week.end)!
        return calendar.startOfDay(for: calendar.date(byAdding: .weekOfYear, value: weeksAhead, to: lastDay)!)
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

    /// Training hours per week (every logged minute), averaged over the last 4 weeks.
    /// A newer learner's average covers only the days since their first log, so one short
    /// session on day one isn't read as a pace kept up for a month.
    public func weeklyHours(history: [ActivityRecord], today: Date) -> Double {
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: today)!)
        let windowStart = calendar.date(byAdding: .day, value: -7 * Self.averagingWeeks, to: end)!
        guard let firstLog = history.map(\.date).min() else { return 0 }
        let start = max(windowStart, calendar.startOfDay(for: firstLog))
        let days = max(Double(Self.minimumDaysOfHistory), Double(calendar.dateComponents([.day], from: start, to: end).day ?? 0))
        let minutes = history
            .filter { $0.date >= start && $0.date < end }
            .reduce(0) { $0 + $1.minutes }
        return Double(minutes) / 60 / days * 7
    }

    /// Whether there's enough history for `weeklyHours` to mean something.
    public func hasEnoughHistory(_ history: [ActivityRecord], today: Date) -> Bool {
        guard let firstLog = history.map(\.date).min() else { return false }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: firstLog), to: calendar.startOfDay(for: today)).day ?? 0
        return days + 1 >= Self.minimumDaysOfHistory
    }

    /// The pace a learner would keep by meeting their weekly goal, used until there's a week of history.
    public static func weeklyHours(atGoalMinutes goal: Int) -> Double {
        Double(goal) / 60
    }

    /// The date each remaining band threshold is reached at `weeklyHours`, or nil if the pace is zero.
    public func arrivalDates(hours: Double, weeklyHours: Double, from today: Date) -> [Band: Date] {
        guard weeklyHours > 0 else { return [:] }
        var dates: [Band: Date] = [:]
        for band in Band.allCases where band.hoursThreshold > hours {
            let weeks = (band.hoursThreshold - hours) / weeklyHours
            dates[band] = calendar.date(byAdding: .day, value: Int((weeks * 7).rounded(.up)), to: today)
        }
        return dates
    }

    /// Training hours expected by `date` at the current pace plus `extraMinutesPerDay`.
    public func hours(by date: Date, from today: Date, current: Double, weeklyHours: Double, extraMinutesPerDay: Int = 0) -> Double {
        let days = Double(calendar.dateComponents([.day], from: today, to: date).day ?? 0)
        let perDay = weeklyHours / 7 + Double(extraMinutesPerDay) / 60
        return current + max(0, days) * perDay
    }
}

/// Links the weekly goal and the target date (docs/02-learning-engine.md §2.9): at a weekly goal, when the
/// goal level is reached; for a target date, the weekly goal that gets there. Every minute of the weekly
/// goal counts toward level hours.
public enum GoalPace {
    /// The weekly goal moves in 10-minute steps.
    public static let step = 10
    public static let minutes = 30...900

    /// When `goal` is reached at `weeklyMinutes`; `today` if it already has been.
    public static func arrival(of goal: Band, currentHours: Double, weeklyMinutes: Int,
                               from today: Date, calendar: Calendar = .current) -> Date {
        let remaining = goal.hoursThreshold - currentHours
        let weekly = Projection.weeklyHours(atGoalMinutes: weeklyMinutes)
        guard remaining > 0, weekly > 0 else { return calendar.startOfDay(for: today) }
        let days = Int((remaining / weekly * 7).rounded(.up))
        return calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: today))!
    }

    /// The weekly goal (rounded up to a step, within `minutes`) that reaches `goal` by `date`.
    public static func weeklyMinutes(toReach goal: Band, by date: Date, currentHours: Double,
                                     from today: Date, calendar: Calendar = .current) -> Int {
        let remaining = goal.hoursThreshold - currentHours
        guard remaining > 0 else { return minutes.lowerBound }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: today), to: calendar.startOfDay(for: date)).day ?? 0
        let weeks = max(Double(days) / 7, 1)
        let needed = remaining / weeks * 60
        let rounded = Int((needed / Double(step)).rounded(.up)) * step
        return min(max(rounded, minutes.lowerBound), minutes.upperBound)
    }

    /// Whether `date` needs more than the largest weekly goal.
    public static func isOutOfReach(_ goal: Band, by date: Date, currentHours: Double,
                                    from today: Date, calendar: Calendar = .current) -> Bool {
        arrival(of: goal, currentHours: currentHours, weeklyMinutes: minutes.upperBound, from: today, calendar: calendar)
            > calendar.startOfDay(for: date)
    }
}

/// Which daily budget keeps the learner on track for their weekly goal: what's left of the goal,
/// spread over the days left this week (today included), rounded up to a budget choice.
public enum BudgetAdvisor {
    public struct Advice: Equatable, Sendable {
        /// Minutes a day needed from today to the end of the week.
        public let minutesPerDay: Int
        /// The budget chip to pick.
        public let recommended: Int
        public let daysLeft: Int
        public let goalAlreadyMet: Bool
    }

    public static func advice(
        weeklyGoal: Int,
        minutesThisWeek: Int,
        today: Date,
        choices: [Int] = DayPlanner.budgetChoices,
        calendar: Calendar = .current
    ) -> Advice {
        let todayStart = calendar.startOfDay(for: today)
        let weekEnd = calendar.dateInterval(of: .weekOfYear, for: today)?.end ?? todayStart
        let daysLeft = max(1, calendar.dateComponents([.day], from: todayStart, to: weekEnd).day ?? 1)
        let remaining = weeklyGoal - minutesThisWeek
        let smallest = choices.min() ?? 10
        guard remaining > 0 else {
            return Advice(minutesPerDay: 0, recommended: smallest, daysLeft: daysLeft, goalAlreadyMet: true)
        }
        let perDay = Int((Double(remaining) / Double(daysLeft)).rounded(.up))
        let recommended = choices.sorted().first { $0 >= perDay } ?? (choices.max() ?? perDay)
        return Advice(minutesPerDay: perDay, recommended: recommended, daysLeft: daysLeft, goalAlreadyMet: false)
    }
}
