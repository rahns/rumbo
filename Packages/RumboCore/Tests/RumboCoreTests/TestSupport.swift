import Foundation
@testable import RumboCore

enum TestCalendar {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Noon UTC on the given day, so dates sit well inside their day.
    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        utc.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    static func adding(days: Int, to date: Date) -> Date {
        utc.date(byAdding: .day, value: days, to: date)!
    }
}

extension DayPlan {
    func minutes(in strand: Strand) -> Int {
        tasks.filter { $0.kind.strand == strand }.reduce(0) { $0 + $1.minutes }
    }

    func task(_ kind: TaskKind) -> PlannedTask? {
        tasks.first { $0.kind == kind }
    }

    var kinds: [TaskKind] { tasks.map(\.kind) }
}

/// The author's starting point: 154 h, Language Transfer track 12 done, one Extra episode watched.
let authorAtStart = LearnerSnapshot(
    band: .a2_1,
    languageTransferLastTrack: 12,
    extraEpisodesWatched: 1,
    dsDifficulty: 40...48
)
