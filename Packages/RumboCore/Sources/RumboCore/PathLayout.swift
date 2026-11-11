import Foundation

/// The scrolling path: one node per calendar day since onboarding, in weeks of 7 that start on the
/// learner's week start (the calendar's `firstWeekday`), running on into the future with projected
/// level-ups. Future days stay locked.
/// See docs/03-experience.md §3.4 "Path".
public struct PathNode: Equatable, Sendable, Identifiable {
    public enum Status: String, Codable, Equatable, Sendable {
        /// Enough practice: at least what the weekly goal needed that day (with a goal), else a finished
        /// session or ≥ 10 minutes logged.
        case done
        /// A past (or finished) day with some practice, but less than it needed.
        case partial
        case missed
        /// A past day with nothing logged that a streak freeze covered.
        case frozen
        /// Today, not finished yet.
        case current
        case upcoming
        /// A day in the first week before the learner started.
        case beforeStart
    }

    /// 1-based day number since onboarding.
    public let number: Int
    public let date: Date
    public let minutes: Int
    public let status: Status
    public let isToday: Bool

    public var id: Int { number }
}

/// A streak freeze on the path, shown after the day the streak earned it (or will).
public struct PathFreezeMarker: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable {
        /// Earned on this day, when the streak reached `streak` days.
        case earned(streak: Int)
        /// The next one, `daysLeft` streak days away.
        case next(daysLeft: Int)
    }

    public let kind: Kind
    public let day: Date
    public let afterNode: Int

    public var id: String { "\(kind)-\(afterNode)" }
}

/// A projected level-up, shown after the day it's expected.
public struct PathMilestone: Equatable, Sendable, Identifiable {
    public let band: Band
    public let expectedDate: Date
    public let afterNode: Int

    public var id: String { band.rawValue }
}

public struct PathUnit: Equatable, Sendable, Identifiable {
    public let number: Int
    public let nodes: [PathNode]

    public var id: Int { number }
    /// The week is over: every day is in the past (shown as "Semana completa").
    public var isPast: Bool {
        nodes.allSatisfy { $0.status != .current && $0.status != .upcoming }
    }

    /// Gold: every day had some practice or a streak freeze (done, partly done or frozen) and none was missed.
    /// Days before the learner started don't count against it. Today counts once it's finished.
    public var isComplete: Bool {
        nodes.contains { $0.status == .done || $0.status == .partial }
            && nodes.allSatisfy { [.done, .partial, .frozen, .beforeStart].contains($0.status) }
    }
}

public struct PathMap: Equatable, Sendable {
    public let units: [PathUnit]
    public let milestones: [PathMilestone]
    /// Level-ups projected beyond the end of the drawn path. They move onto it as they get closer.
    public let laterMilestones: [PathMilestone]
    public let freezeMarkers: [PathFreezeMarker]

    public init(units: [PathUnit], milestones: [PathMilestone], laterMilestones: [PathMilestone] = [], freezeMarkers: [PathFreezeMarker] = []) {
        self.units = units
        self.milestones = milestones
        self.laterMilestones = laterMilestones
        self.freezeMarkers = freezeMarkers
    }

    public var allNodes: [PathNode] { units.flatMap(\.nodes) }
    /// Today while it's unfinished.
    public var focusNode: PathNode? { allNodes.first { $0.status == .current } }
    public var todayNode: PathNode? { allNodes.first(where: \.isToday) }
}

public enum PathLayout {
    public static let nodesPerUnit = 7
    /// With no plan, a day with this much logged shows as done (less is partly done). The streak counts any practice.
    public static let minutesForDoneDay = 10
    /// Always show at least this many units after today's.
    public static let minimumUnitsAhead = 4
    /// Never draw more than this many units after today's (about two years).
    public static let maximumUnitsAhead = 104

    public enum SessionState: Equatable, Sendable {
        case none
        case unfinished
        case finished
    }

    /// What the weekly goal asked of a day: Today's goal advice for it, from the minutes logged earlier
    /// in its week (`BudgetAdvisor.minutesToday`). Once the week's goal is met, any practice is enough (1).
    public static func neededMinutes(on day: Date, days: [Date: Day], goal: Goal, calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: day)
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: start)?.start ?? start
        let before = days.filter { $0.key >= weekStart && $0.key < start }.reduce(0) { $0 + $1.value.minutes }
        let advice = BudgetAdvisor.advice(weeklyGoal: goal.weeklyMinutes, minutesThisWeek: before, today: start,
                                          lessons: goal.lessons, calendar: calendar)
        return advice.goalAlreadyMet ? 1 : max(1, advice.minutesToday)
    }

    /// Past days' colours, saved once each day is over, and each day's need as it stood on the day.
    /// Days are keyed "yyyy-MM-dd" in the learner's calendar.
    public struct PathHistory: Codable, Equatable, Sendable {
        public var statuses: [String: PathNode.Status] = [:]
        public var neededMinutes: [String: Int] = [:]

        public init() {}

        public static func key(_ day: Date, calendar: Calendar) -> String {
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        }

        public func status(on day: Date, calendar: Calendar) -> PathNode.Status? { statuses[Self.key(day, calendar: calendar)] }
        public func needed(on day: Date, calendar: Calendar) -> Int? { neededMinutes[Self.key(day, calendar: calendar)] }

        /// Records today's need (it can still change today) and settles every past day of `map` not settled yet.
        /// Returns whether anything changed.
        public mutating func update(with map: PathMap, todayNeeded: Int?, today: Date, calendar: Calendar) -> Bool {
            var changed = false
            let todayStart = calendar.startOfDay(for: today)
            if let todayNeeded {
                let key = Self.key(todayStart, calendar: calendar)
                if neededMinutes[key] != todayNeeded { neededMinutes[key] = todayNeeded; changed = true }
            }
            for node in map.allNodes where node.date < todayStart {
                guard [.done, .partial, .missed, .frozen].contains(node.status) else { continue }
                let key = Self.key(node.date, calendar: calendar)
                if statuses[key] == nil { statuses[key] = node.status; changed = true }
            }
            return changed
        }
    }

    /// The weekly goal, for judging each day against what it needed (see `map`).
    public struct Goal: Equatable, Sendable {
        public let weeklyMinutes: Int
        public let lessons: LessonSchedule

        public init(weeklyMinutes: Int, lessons: LessonSchedule = LessonSchedule()) {
            self.weeklyMinutes = weeklyMinutes
            self.lessons = lessons
        }
    }

    public struct Day: Equatable, Sendable {
        public let minutes: Int
        public let session: SessionState

        public init(minutes: Int, session: SessionState) {
            self.minutes = minutes
            self.session = session
        }
    }

    /// - Parameters:
    ///   - days: what happened on each day, keyed by start of day. A session done early is keyed by the day it's for.
    ///   - arrivals: projected dates for upcoming bands.
    ///   - frozen: days a streak freeze covered (start of day).
    ///   - freezesEarned: each day a freeze was earned, with the streak it reached.
    ///   - nextFreeze: the day the next freeze can be earned, and how many streak days away it is.
    public static func map(start: Date, today: Date, days: [Date: Day], arrivals: [Band: Date],
                           frozen: Set<Date> = [], freezesEarned: [(day: Date, streak: Int)] = [], nextFreeze: (day: Date, daysLeft: Int)? = nil,
                           goal: Goal? = nil, history: PathHistory = PathHistory(), calendar: Calendar = .current) -> PathMap {
        let startDay = calendar.startOfDay(for: min(start, today))
        // The path starts on the first day of the week the learner started in, so each "Semana" is a goal week.
        let first = calendar.dateInterval(of: .weekOfYear, for: startDay)?.start ?? startDay
        let todayStart = calendar.startOfDay(for: today)
        let todayIndex = calendar.dateComponents([.day], from: first, to: todayStart).day ?? 0

        func date(at index: Int) -> Date { calendar.date(byAdding: .day, value: index, to: first)! }
        func number(of day: Date) -> Int { (calendar.dateComponents([.day], from: first, to: calendar.startOfDay(for: day)).day ?? 0) + 1 }

        var milestones: [PathMilestone] = []
        for band in Band.allCases {
            guard let expected = arrivals[band] else { continue }
            milestones.append(PathMilestone(band: band, expectedDate: expected, afterNode: max(number(of: expected), todayIndex + 1)))
        }

        let todayUnit = todayIndex / nodesPerUnit
        let lastMilestoneUnit = milestones.map { ($0.afterNode - 1) / nodesPerUnit }.max() ?? todayUnit
        let lastUnit = min(max(todayUnit + minimumUnitsAhead, lastMilestoneUnit + 1), todayUnit + maximumUnitsAhead)
        let pathEnd = (lastUnit + 1) * nodesPerUnit
        let later = milestones.filter { $0.afterNode > pathEnd }
        milestones = milestones.filter { $0.afterNode <= pathEnd }

        /// What the weekly goal asked of a day: Today's goal advice for it, from the minutes logged earlier
        /// in its week (`BudgetAdvisor.minutesToday`). Once the week's goal is met, any practice is enough.
        /// A day's need as recorded on the day itself, if it was, so later goal changes don't move it.
        func needed(on day: Date) -> Int? {
            guard let goal else { return nil }
            if let saved = history.needed(on: day, calendar: calendar), day < todayStart { return saved }
            return neededMinutes(on: day, days: days, goal: goal, calendar: calendar)
        }

        var nodes: [PathNode] = []
        for index in 0..<((lastUnit + 1) * nodesPerUnit) {
            let day = date(at: index)
            let info = days[day] ?? Day(minutes: 0, session: .none)
            let status: PathNode.Status
            if index < todayIndex, let saved = history.status(on: day, calendar: calendar) {
                // A past day keeps the colour it was given once it ended (see `PathHistory`).
                status = saved
            } else if day < startDay && info.minutes == 0 && info.session == .none {
                status = .beforeStart
            } else if let needed = needed(on: day), index < todayIndex || (index == todayIndex && info.session == .finished) {
                // With a goal, time decides: green once the day reached what the goal needed, yellow below it.
                status = info.minutes >= needed ? .done : info.minutes > 0 ? .partial : frozen.contains(day) ? .frozen : .missed
            } else if info.session == .finished {
                status = .done
            } else if index < todayIndex {
                switch info.session {
                case .unfinished: status = .partial
                case .none:
                    status = info.minutes >= minutesForDoneDay ? .done : info.minutes > 0 ? .partial : frozen.contains(day) ? .frozen : .missed
                case .finished: status = .done
                }
            } else if index == todayIndex {
                status = .current
            } else {
                // Future days stay locked; extra practice after finishing today happens on Today
                // ("Keep going"). A day finished early in an older version still shows as done.
                status = .upcoming
            }
            nodes.append(PathNode(number: index + 1, date: day, minutes: info.minutes, status: status, isToday: index == todayIndex))
        }

        let units = stride(from: 0, to: nodes.count, by: nodesPerUnit).map { start in
            PathUnit(number: start / nodesPerUnit + 1, nodes: Array(nodes[start..<min(start + nodesPerUnit, nodes.count)]))
        }
        var markers = freezesEarned.map { PathFreezeMarker(kind: .earned(streak: $0.streak), day: $0.day, afterNode: number(of: $0.day)) }
        if let nextFreeze {
            markers.append(PathFreezeMarker(kind: .next(daysLeft: nextFreeze.daysLeft), day: nextFreeze.day, afterNode: number(of: nextFreeze.day)))
        }
        markers = markers.filter { $0.afterNode >= 1 && $0.afterNode <= nodes.count }
        return PathMap(units: units, milestones: milestones, laterMilestones: later, freezeMarkers: markers)
    }
}
