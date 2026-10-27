import Foundation

/// The scrolling path: one node per calendar day since onboarding, in units of 7, running on into
/// the future with projected level-ups. Future days stay locked.
/// See docs/03-experience.md §3.4 "Path".
public struct PathNode: Equatable, Sendable, Identifiable {
    public enum Status: Equatable, Sendable {
        /// The day's session is finished (or, with no saved session, ≥ 10 minutes were logged).
        case done
        /// A past day with some practice but an unfinished session.
        case partial
        case missed
        /// Today, not finished yet.
        case current
        case upcoming
    }

    /// 1-based day number since onboarding.
    public let number: Int
    public let date: Date
    public let minutes: Int
    public let status: Status
    public let isToday: Bool

    public var id: Int { number }
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
    public var isComplete: Bool { nodes.allSatisfy { $0.status == .done } }
}

public struct PathMap: Equatable, Sendable {
    public let units: [PathUnit]
    public let milestones: [PathMilestone]
    /// Level-ups projected beyond the end of the drawn path. They move onto it as they get closer.
    public let laterMilestones: [PathMilestone]

    public init(units: [PathUnit], milestones: [PathMilestone], laterMilestones: [PathMilestone] = []) {
        self.units = units
        self.milestones = milestones
        self.laterMilestones = laterMilestones
    }

    public var allNodes: [PathNode] { units.flatMap(\.nodes) }
    /// Today while it's unfinished.
    public var focusNode: PathNode? { allNodes.first { $0.status == .current } }
    public var todayNode: PathNode? { allNodes.first(where: \.isToday) }
}

public enum PathLayout {
    public static let nodesPerUnit = 7
    /// Always show at least this many units after today's.
    public static let minimumUnitsAhead = 4
    /// Never draw more than this many units after today's (about two years).
    public static let maximumUnitsAhead = 104

    public enum SessionState: Equatable, Sendable {
        case none
        case unfinished
        case finished
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
    public static func map(start: Date, today: Date, days: [Date: Day], arrivals: [Band: Date], calendar: Calendar = .current) -> PathMap {
        let first = calendar.startOfDay(for: min(start, today))
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

        var nodes: [PathNode] = []
        for index in 0..<((lastUnit + 1) * nodesPerUnit) {
            let day = date(at: index)
            let info = days[day] ?? Day(minutes: 0, session: .none)
            let status: PathNode.Status
            if info.session == .finished {
                status = .done
            } else if index < todayIndex {
                switch info.session {
                case .unfinished: status = .partial
                case .none: status = info.minutes >= StreakCalculator.minutesForStreakDay ? .done : info.minutes > 0 ? .partial : .missed
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
        return PathMap(units: units, milestones: milestones, laterMilestones: later)
    }
}
