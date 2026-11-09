import Foundation

/// Tutoring or classroom lessons on set days of the week (Settings → Lessons). See docs/02-learning-engine.md §2.5.
/// Each lesson day uses the usual length and type unless that day has its own.
public struct LessonSchedule: Codable, Equatable, Sendable {
    /// One weekday's lesson. Nil fields use the usual length and type.
    public struct Day: Codable, Equatable, Sendable {
        public var minutes: Int?
        public var strand: Strand?

        public init(minutes: Int? = nil, strand: Strand? = nil) {
            self.minutes = minutes
            self.strand = strand
        }
    }

    /// Lesson days by weekday number (1 = Sunday … 7 = Saturday, as `Calendar` counts them).
    public var days: [Int: Day]
    public var usualMinutes: Int
    /// Speaking & writing, listening or language study.
    public var usualStrand: Strand

    public static let strands: [Strand] = [.output, .input, .languageFocused]

    public init(days: [Int: Day] = [:], usualMinutes: Int = 60, usualStrand: Strand = .output) {
        self.days = days
        self.usualMinutes = usualMinutes
        self.usualStrand = usualStrand
    }

    public var isEmpty: Bool { days.isEmpty }

    /// The length and type of `weekday`'s lesson, with that day's own settings winning over the usual ones.
    public func lesson(weekday: Int) -> (minutes: Int, strand: Strand)? {
        guard let day = days[weekday] else { return nil }
        return (day.minutes ?? usualMinutes, day.strand ?? usualStrand)
    }

    /// The lesson on `date`, as a task to plan.
    public func lesson(on date: Date, calendar: Calendar) -> PlannedTask? {
        guard let lesson = lesson(weekday: calendar.component(.weekday, from: date)) else { return nil }
        return PlannedTask(kind: .lesson(for: lesson.strand), minutes: lesson.minutes, detail: .none, isAnchor: false)
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
