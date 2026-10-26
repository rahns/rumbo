import Foundation
import Testing
@testable import RumboCore

@Suite struct PathLayoutTests {
    let calendar = TestCalendar.utc
    let today = TestCalendar.day(2026, 10, 30)

    func session(daysAgo: Int, minutes: Int = 30, complete: Bool = true) -> PathLayout.Session {
        PathLayout.Session(date: TestCalendar.adding(days: -daysAgo, to: today), minutes: minutes, isComplete: complete)
    }

    func map(_ sessions: [PathLayout.Session], inProgress: Bool = false, arrivals: [Band: Date] = [:]) -> PathMap {
        PathLayout.map(sessions: sessions, todayInProgress: inProgress, arrivals: arrivals, today: today, calendar: calendar)
    }

    @Test func aNewLearnerStartsAtNodeOneWithUnitsAhead() {
        let path = map([])
        #expect(path.allNodes.first?.status == .current)
        #expect(path.focusNode?.number == 1)
        #expect(path.units.count == 1 + PathLayout.minimumUnitsAhead)
        #expect(path.allNodes.dropFirst().allSatisfy { $0.status == .upcoming })
    }

    @Test func pastSessionsAreDoneOrPartialWithNoGapsForMissedDays() {
        // Sessions 5 and 2 days ago only: two nodes, no gaps for the missed days.
        let path = map([session(daysAgo: 5), session(daysAgo: 2, minutes: 8, complete: false)])
        #expect(path.allNodes.prefix(3).map(\.status) == [.done, .partial, .current])
    }

    @Test func finishingTodayUnlocksTheNextNode() {
        let path = map([session(daysAgo: 1), session(daysAgo: 0)])
        #expect(path.allNodes.prefix(3).map(\.status) == [.done, .done, .unlocked])
        #expect(path.focusNode?.number == 3)
    }

    @Test func todaysUnfinishedSessionIsTheCurrentNode() {
        let path = map([session(daysAgo: 1), session(daysAgo: 0, minutes: 5, complete: false)], inProgress: true)
        #expect(path.allNodes.prefix(3).map(\.status) == [.done, .current, .upcoming])
    }

    @Test func aSecondSessionTodayFollowsTheFirst() {
        let path = map([session(daysAgo: 0), session(daysAgo: 0, minutes: 5, complete: false)], inProgress: true)
        #expect(path.allNodes.prefix(2).map(\.status) == [.done, .current])
    }

    @Test func milestonesSitAboutOneNodePerDayAheadAndExtendThePath() {
        let arrivals: [Band: Date] = [
            .a2_2: TestCalendar.adding(days: 30, to: today),
            .b1_1: TestCalendar.adding(days: 120, to: today),
        ]
        let path = map([session(daysAgo: 1)], arrivals: arrivals)
        #expect(path.milestones.map(\.band) == [.a2_2, .b1_1])
        // Focus is node 2; 30 days later is about node 31.
        #expect(path.milestones[0].afterNode == 31)
        #expect(path.allNodes.count >= path.milestones[1].afterNode + PathLayout.nodesPerUnit)
    }

    @Test func farAwayMilestonesAreCappedAtTwoYears() {
        let path = map([], arrivals: [.b2_2: TestCalendar.adding(days: 3650, to: today)])
        #expect(path.milestones.isEmpty)
        #expect(path.units.count <= 1 + PathLayout.maximumUnitsAhead)
    }

    @Test func unitsHoldSevenNodes() {
        let path = map((0..<9).map { session(daysAgo: 9 - $0) })
        #expect(path.units.allSatisfy { $0.nodes.count == PathLayout.nodesPerUnit })
        #expect(path.units[0].isComplete)
        #expect(!path.units[1].isComplete)
    }
}
