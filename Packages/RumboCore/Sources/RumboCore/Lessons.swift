import Foundation

/// What a lesson covers. All-in-one is split evenly across the other three when it's logged.
public enum LessonType: String, CaseIterable, Codable, Sendable {
    // Raw values match `Strand`'s, so schedules saved before all-in-one existed still decode.
    case output, input, languageFocused
    case allInOne

    /// The strand it counts toward, or nil for all-in-one.
    public var strand: Strand? {
        switch self {
        case .output: .output
        case .input: .input
        case .languageFocused: .languageFocused
        case .allInOne: nil
        }
    }

    /// An all-in-one lesson's minutes as three logs: speaking & writing, listening, grammar & vocab.
    /// Spread evenly; any extra minute goes to the first parts (50 → 17, 17, 16).
    public static func split(minutes: Int) -> [(kind: TaskKind, minutes: Int)] {
        let kinds: [TaskKind] = [.lessonOutput, .lessonInput, .lessonStudy]
        return kinds.enumerated().compactMap { index, kind in
            let share = minutes / 3 + (index < minutes % 3 ? 1 : 0)
            return share > 0 ? (kind, share) : nil
        }
    }
}

/// Tutoring or classroom lessons on set days of the week (Settings → Lessons). See docs/02-learning-engine.md §2.5.
/// Each lesson day uses the usual length and type unless that day has its own.
public struct LessonSchedule: Codable, Equatable, Sendable {
    /// One weekday's lesson. Nil fields use the usual length and type.
    public struct Day: Codable, Equatable, Sendable {
        public var minutes: Int?
        public var type: LessonType?

        public init(minutes: Int? = nil, type: LessonType? = nil) {
            self.minutes = minutes
            self.type = type
        }

        // "strand" is the key schedules were saved with before all-in-one existed.
        enum CodingKeys: String, CodingKey { case minutes, type = "strand" }
    }

    /// Lesson days by weekday number (1 = Sunday … 7 = Saturday, as `Calendar` counts them).
    public var days: [Int: Day]
    public var usualMinutes: Int
    /// Speaking & writing, listening, grammar & vocab, or all-in-one.
    public var usualType: LessonType

    enum CodingKeys: String, CodingKey { case days, usualMinutes, usualType = "usualStrand" }

    public init(days: [Int: Day] = [:], usualMinutes: Int = 60, usualType: LessonType = .output) {
        self.days = days
        self.usualMinutes = usualMinutes
        self.usualType = usualType
    }

    public var isEmpty: Bool { days.isEmpty }

    /// The length and type of `weekday`'s lesson, with that day's own settings winning over the usual ones.
    public func lesson(weekday: Int) -> (minutes: Int, type: LessonType)? {
        guard let day = days[weekday] else { return nil }
        return (day.minutes ?? usualMinutes, day.type ?? usualType)
    }

    /// The lesson on `date`, as a task to plan.
    public func lesson(on date: Date, calendar: Calendar) -> PlannedTask? {
        guard let lesson = lesson(weekday: calendar.component(.weekday, from: date)) else { return nil }
        return PlannedTask(kind: .lesson(for: lesson.type), minutes: lesson.minutes, detail: .none, isAnchor: false)
    }

    /// Lesson minutes still to come this week, after `today` (today's lesson is part of today's budget).
    public func minutesLaterThisWeek(after today: Date, calendar: Calendar) -> Int {
        guard !isEmpty, let week = calendar.dateInterval(of: .weekOfYear, for: today) else { return 0 }
        var minutes = 0
        var day = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!
        while day < week.end {
            minutes += lesson(weekday: calendar.component(.weekday, from: day))?.minutes ?? 0
            day = calendar.date(byAdding: .day, value: 1, to: day)!
        }
        return minutes
    }
}
