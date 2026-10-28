import Foundation

/// A suggested show, podcast, film or channel. See docs/06-content-catalog.md.
public struct ContentItem: Codable, Equatable, Sendable, Identifiable {
    public enum Kind: String, Codable, Sendable {
        case series, film, podcast, youtube
    }

    public var id: String
    public var title: String
    public var kind: Kind
    /// Lowest and highest band it suits, e.g. "A2.2" and "B1.1".
    public var from: Band
    public var to: Band
    /// Accent / country, e.g. "Mexico", "Colombia", "Spain", "Various".
    public var country: String
    public var whereToFind: String
    public var url: String?
    public var why: String

    public init(id: String, title: String, kind: Kind, from: Band, to: Band, country: String, whereToFind: String, url: String?, why: String) {
        self.id = id
        self.title = title
        self.kind = kind
        self.from = from
        self.to = to
        self.country = country
        self.whereToFind = whereToFind
        self.url = url
        self.why = why
    }

    public func suits(_ band: Band) -> Bool { from <= band && band <= to }
}

public struct ContentCatalog: Codable, Equatable, Sendable {
    /// Bumped whenever the list changes; a remote copy is used only if it's newer than the bundled one.
    public var version: Int
    public var items: [ContentItem]

    public init(version: Int, items: [ContentItem]) {
        self.version = version
        self.items = items
    }

    /// What suits the learner now, then what's coming next, easiest first.
    public func suggestions(for band: Band) -> (now: [ContentItem], next: [ContentItem]) {
        func ordered(_ items: [ContentItem]) -> [ContentItem] {
            items.sorted { lhs, rhs in
                if lhs.from != rhs.from { return lhs.from < rhs.from }
                return lhs.title < rhs.title
            }
        }
        let now = items.filter { $0.suits(band) }
        let next = band.next.map { upcoming in items.filter { $0.suits(upcoming) && !$0.suits(band) } } ?? []
        return (ordered(now), ordered(next))
    }

    public static func decode(_ data: Data) throws -> ContentCatalog {
        try JSONDecoder().decode(ContentCatalog.self, from: data)
    }
}

/// Day-by-day minutes and the last week's strand mix, for the Progress charts.
public enum ProgressStats {
    /// Minutes per strand over the 7 days ending today.
    public static func strandMinutes(history: [ActivityRecord], today: Date, calendar: Calendar = .current) -> [Strand: Int] {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!
        let start = calendar.date(byAdding: .day, value: -7, to: end)!
        var minutes = Dictionary(uniqueKeysWithValues: Strand.allCases.map { ($0, 0) })
        for record in history where record.date >= start && record.date < end {
            minutes[record.kind.strand, default: 0] += record.minutes
        }
        return minutes
    }

    public struct Day: Equatable, Sendable {
        public let date: Date
        public let minutes: Int
    }

    /// Whole weeks (in the calendar's week, oldest first) ending with this week, for a heat map.
    public static func weeks(_ count: Int, history: [ActivityRecord], today: Date, calendar: Calendar = .current) -> [[Day]] {
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: today) else { return [] }
        var minutesByDay: [Date: Int] = [:]
        for record in history {
            minutesByDay[calendar.startOfDay(for: record.date), default: 0] += record.minutes
        }
        return (0..<count).reversed().map { weeksAgo in
            let weekStart = calendar.date(byAdding: .weekOfYear, value: -weeksAgo, to: thisWeek.start)!
            return (0..<7).map { offset in
                let day = calendar.startOfDay(for: calendar.date(byAdding: .day, value: offset, to: weekStart)!)
                return Day(date: day, minutes: minutesByDay[day] ?? 0)
            }
        }
    }

    public struct Point: Equatable, Sendable {
        public let date: Date
        public let hours: Double
    }

    /// Expected input hours on each date, every `stepDays`, from today until `end`.
    public static func projection(currentHours: Double, weeklyHours: Double, from today: Date, until end: Date,
                                  stepDays: Int = 14, calendar: Calendar = .current) -> [Point] {
        let start = calendar.startOfDay(for: today)
        var points: [Point] = []
        var date = start
        while date <= end {
            let days = Double(calendar.dateComponents([.day], from: start, to: date).day ?? 0)
            points.append(Point(date: date, hours: currentHours + weeklyHours / 7 * days))
            date = calendar.date(byAdding: .day, value: stepDays, to: date)!
        }
        return points
    }
}

/// The Dreaming Spanish level watched over time, for the Progress chart (docs/03-experience.md "Progress tab").
public enum WatchedLevel {
    /// One logged session: the level watched and for how long.
    public struct Session: Equatable, Sendable {
        public let date: Date
        public let level: Double
        public let minutes: Int

        public init(date: Date, level: Double, minutes: Int) {
            self.date = date
            self.level = level
            self.minutes = minutes
        }
    }

    public enum Period: String, CaseIterable, Sendable {
        case twoWeeks = "14d", month = "1m", threeMonths = "3m", sixMonths = "6m", year = "1y", allTime = "All"

        /// How far back the chart looks; nil for all time, which starts at the first session.
        public var days: Int? {
            switch self {
            case .twoWeeks: 14
            case .month: 30
            case .threeMonths: 91
            case .sixMonths: 182
            case .year: 365
            case .allTime: nil
            }
        }
    }

    /// The span a chart covers and how many days each point averages.
    public struct Window: Equatable, Sendable {
        /// The first day shown.
        public let start: Date
        public let days: Int
        /// 1 (daily) up to a month, 7 (weekly) up to a year, 30 (monthly) beyond.
        public var bucketDays: Int { days <= 30 ? 1 : days <= 366 ? 7 : 30 }
    }

    /// The days ending today that `period` covers. All time starts at the first session (at least 14 days).
    public static func window(_ sessions: [Session], period: Period, today: Date, calendar: Calendar = .current) -> Window {
        let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!
        let days = period.days ?? max(14, sessions.map { session in
            calendar.dateComponents([.day], from: calendar.startOfDay(for: session.date), to: end).day ?? 0
        }.max() ?? 0)
        return Window(start: calendar.date(byAdding: .day, value: -days, to: end)!, days: days)
    }

    public struct Point: Equatable, Sendable {
        /// The start of the day, week or month.
        public let date: Date
        /// Average level, weighted by minutes watched.
        public let level: Double
        public let minutes: Int
    }

    /// Minute-weighted average level per day, week or month (see `Window.bucketDays`), oldest first.
    /// Days or weeks with nothing watched are left out rather than drawn as zero.
    public static func series(_ sessions: [Session], period: Period, today: Date, calendar: Calendar = .current) -> [Point] {
        let window = window(sessions, period: period, today: today, calendar: calendar)
        let start = window.start, size = window.bucketDays
        let end = calendar.date(byAdding: .day, value: window.days, to: start)!
        var buckets: [Date: (weighted: Double, minutes: Int)] = [:]
        for session in sessions where session.date >= start && session.date < end && session.minutes > 0 {
            let days = calendar.dateComponents([.day], from: start, to: calendar.startOfDay(for: session.date)).day ?? 0
            let bucket = calendar.date(byAdding: .day, value: days / size * size, to: start)!
            let current = buckets[bucket] ?? (0, 0)
            buckets[bucket] = (current.weighted + session.level * Double(session.minutes), current.minutes + session.minutes)
        }
        return buckets.keys.sorted().map { date in
            let bucket = buckets[date]!
            return Point(date: date, level: bucket.weighted / Double(bucket.minutes), minutes: bucket.minutes)
        }
    }
}
