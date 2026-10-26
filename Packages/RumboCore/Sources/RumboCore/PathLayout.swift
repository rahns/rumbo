import Foundation

/// The scrolling path: one node per day since onboarding, grouped into 7-day units.
/// See docs/03-experience.md §3.4 "Path".
public struct PathDay: Equatable, Sendable, Identifiable {
    public enum Status: Equatable, Sendable {
        /// At least `StreakCalculator.minutesForStreakDay` minutes.
        case done
        /// Some practice, but under the streak threshold.
        case partial
        case missed
        case today
        case upcoming
    }

    public let date: Date
    /// 1-based day number since onboarding.
    public let number: Int
    public let minutes: Int
    public let status: Status

    public var id: Date { date }
}

public struct PathUnit: Equatable, Sendable, Identifiable {
    public let number: Int
    public let days: [PathDay]

    public var id: Int { number }
    public var isComplete: Bool { days.allSatisfy { $0.status == .done } }
}

public enum PathLayout {
    public static let daysPerUnit = 7

    /// Units from the onboarding day up to the end of the unit containing `today`.
    public static func units(start: Date, today: Date, history: [ActivityRecord], calendar: Calendar = .current) -> [PathUnit] {
        let first = calendar.startOfDay(for: min(start, today))
        let todayStart = calendar.startOfDay(for: today)
        var minutesByDay: [Date: Int] = [:]
        for record in history {
            minutesByDay[calendar.startOfDay(for: record.date), default: 0] += record.minutes
        }

        let elapsed = calendar.dateComponents([.day], from: first, to: todayStart).day ?? 0
        let unitCount = elapsed / daysPerUnit + 1
        return (0..<unitCount).map { unitIndex in
            let days = (0..<daysPerUnit).map { offset -> PathDay in
                let dayIndex = unitIndex * daysPerUnit + offset
                let date = calendar.date(byAdding: .day, value: dayIndex, to: first)!
                let minutes = minutesByDay[date] ?? 0
                let status: PathDay.Status
                if date == todayStart {
                    status = .today
                } else if date > todayStart {
                    status = .upcoming
                } else if minutes >= StreakCalculator.minutesForStreakDay {
                    status = .done
                } else if minutes > 0 {
                    status = .partial
                } else {
                    status = .missed
                }
                return PathDay(date: date, number: dayIndex + 1, minutes: minutes, status: status)
            }
            return PathUnit(number: unitIndex + 1, days: days)
        }
    }
}
