import Foundation

/// The scrolling path: one node per session (a full daily plan), like lessons on a Duolingo path,
/// grouped into units of 7, continuing into the future with projected level-ups.
/// See docs/03-experience.md §3.4 "Path".
public struct PathNode: Equatable, Sendable, Identifiable {
    public enum Status: Equatable, Sendable {
        /// A finished session.
        case done
        /// A session from an earlier day that was started but not finished.
        case partial
        /// The session to do now (not started or in progress).
        case current
        /// Today's session is finished: the next one is open early, if the learner wants more.
        case unlocked
        case upcoming
    }

    /// 1-based position on the path.
    public let number: Int
    public let status: Status
    /// When the session happened (past nodes only).
    public let date: Date?
    public let minutes: Int

    public var id: Int { number }
}

/// A projected level-up, shown after the node where it's expected.
public struct PathMilestone: Equatable, Sendable, Identifiable {
    public let band: Band
    public let expectedDate: Date
    /// The node it follows.
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

    public var allNodes: [PathNode] { units.flatMap(\.nodes) }
    public var focusNode: PathNode? { allNodes.first { $0.status == .current || $0.status == .unlocked } }
}

public enum PathLayout {
    public static let nodesPerUnit = 7
    /// Always show at least this many units ahead of the learner.
    public static let minimumUnitsAhead = 4
    /// Never draw more than this many units ahead (about two years).
    public static let maximumUnitsAhead = 104

    public struct Session: Equatable, Sendable {
        public let date: Date
        public let minutes: Int
        public let isComplete: Bool

        public init(date: Date, minutes: Int, isComplete: Bool) {
            self.date = date
            self.minutes = minutes
            self.isComplete = isComplete
        }
    }

    /// - Parameters:
    ///   - sessions: past and today's sessions, oldest first. Earlier days' unfinished sessions show as partial.
    ///   - todayInProgress: today's latest session exists but isn't finished (it becomes the current node).
    ///   - arrivals: projected dates for upcoming bands; at about one session a day, they set where milestones sit.
    public static func map(
        sessions: [Session],
        todayInProgress: Bool,
        arrivals: [Band: Date],
        today: Date,
        calendar: Calendar = .current
    ) -> PathMap {
        var nodes: [PathNode] = []
        let todayStart = calendar.startOfDay(for: today)

        for session in sessions {
            let status: PathNode.Status = session.isComplete ? .done : .partial
            nodes.append(PathNode(number: nodes.count + 1, status: status, date: session.date, minutes: session.minutes))
        }

        let finishedToday = sessions.last.map { $0.isComplete && calendar.startOfDay(for: $0.date) == todayStart } ?? false
        if todayInProgress, let last = nodes.popLast() {
            // Today's unfinished session is the current node, not a partial one.
            nodes.append(PathNode(number: last.number, status: .current, date: last.date, minutes: last.minutes))
        } else {
            nodes.append(PathNode(number: nodes.count + 1, status: finishedToday ? .unlocked : .current, date: nil, minutes: 0))
        }
        let focus = nodes.count

        // Milestones at roughly one session per day from today.
        var milestones: [PathMilestone] = []
        for band in Band.allCases {
            guard let date = arrivals[band] else { continue }
            let days = max(1, calendar.dateComponents([.day], from: todayStart, to: calendar.startOfDay(for: date)).day ?? 1)
            milestones.append(PathMilestone(band: band, expectedDate: date, afterNode: focus + days - 1))
        }

        // Draw ahead to the last milestone (plus a unit), within limits.
        let lastMilestoneNode = milestones.map(\.afterNode).max() ?? focus
        let minimumEnd = (focus / nodesPerUnit + 1 + minimumUnitsAhead) * nodesPerUnit
        let maximumEnd = (focus / nodesPerUnit + 1 + maximumUnitsAhead) * nodesPerUnit
        var end = max(minimumEnd, ((lastMilestoneNode / nodesPerUnit) + 2) * nodesPerUnit)
        end = min(end, maximumEnd)
        milestones = milestones.filter { $0.afterNode <= end }

        while nodes.count < end {
            nodes.append(PathNode(number: nodes.count + 1, status: .upcoming, date: nil, minutes: 0))
        }

        let units = stride(from: 0, to: nodes.count, by: nodesPerUnit).map { start in
            PathUnit(number: start / nodesPerUnit + 1, nodes: Array(nodes[start..<min(start + nodesPerUnit, nodes.count)]))
        }
        return PathMap(units: units, milestones: milestones)
    }
}
