import Foundation
import Testing
@testable import RumboCore

@Suite struct PathLayoutTests {
    let calendar = TestCalendar.utc
    let start = TestCalendar.day(2026, 10, 26)

    func day(_ offset: Int) -> Date { calendar.startOfDay(for: TestCalendar.adding(days: offset, to: start)) }

    func map(today offset: Int, _ days: [Int: PathLayout.Day] = [:], arrivals: [Band: Date] = [:]) -> PathMap {
        PathLayout.map(
            start: start,
            today: TestCalendar.adding(days: offset, to: start),
            days: Dictionary(uniqueKeysWithValues: days.map { (day($0.key), $0.value) }),
            arrivals: arrivals,
            calendar: calendar
        )
    }

    let finished = PathLayout.Day(minutes: 30, session: .finished)

    @Test func firstDayIsTodayWithUnitsAhead() {
        let path = map(today: 0)
        #expect(path.allNodes.first?.status == .current)
        #expect(path.allNodes.first?.isToday == true)
        #expect(path.units.count == 1 + PathLayout.minimumUnitsAhead)
        #expect(path.allNodes.dropFirst().allSatisfy { $0.status == .upcoming })
    }

    @Test func oneNodePerCalendarDayIncludingMissedOnes() {
        let path = map(today: 4, [
            0: finished,
            1: PathLayout.Day(minutes: 5, session: .unfinished),
            3: PathLayout.Day(minutes: 20, session: .none),
        ])
        #expect(path.allNodes.prefix(6).map(\.status) == [.done, .partial, .missed, .done, .current, .upcoming])
    }

    @Test func finishingTodayMakesItDoneAndOpensTomorrow() {
        let path = map(today: 2, [2: finished])
        #expect(path.todayNode?.status == .done)
        #expect(path.allNodes[3].status == .unlocked)
        #expect(path.focusNode?.number == 4)
        #expect(path.allNodes[4].status == .upcoming)
    }

    @Test func daysDoneEarlyStayDoneAndOpenTheNextOne() {
        let path = map(today: 2, [2: finished, 3: finished])
        #expect(path.allNodes[2...4].map(\.status) == [.done, .done, .unlocked])
    }

    @Test func nothingOpensEarlyWhileTodayIsUnfinished() {
        let path = map(today: 2, [2: PathLayout.Day(minutes: 5, session: .unfinished)])
        #expect(path.todayNode?.status == .current)
        #expect(!path.allNodes.contains { $0.status == .unlocked })
    }

    @Test func milestonesSitOnTheirExpectedDayAndExtendThePath() {
        let path = map(today: 0, arrivals: [.a2_2: day(30), .b1_1: day(120)])
        #expect(path.milestones.map(\.afterNode) == [31, 121])
        #expect(path.allNodes.count >= 121 + PathLayout.nodesPerUnit)
    }

    @Test func farAwayMilestonesAreCappedAtTwoYearsButStillReported() {
        let path = map(today: 0, arrivals: [.a2_2: day(60), .b2_2: day(3650)])
        #expect(path.milestones.map(\.band) == [.a2_2])
        #expect(path.laterMilestones.map(\.band) == [.b2_2])
        #expect(path.units.count == 1 + PathLayout.maximumUnitsAhead)
    }

    @Test func aMilestoneMovesOntoThePathAsItGetsCloser() {
        let far = map(today: 0, arrivals: [.b1_1: day(900)])
        #expect(far.milestones.isEmpty && far.laterMilestones.count == 1)
        let closer = map(today: 300, arrivals: [.b1_1: day(900)])
        #expect(closer.milestones.map(\.band) == [.b1_1])
        #expect(closer.laterMilestones.isEmpty)
    }

    @Test func aCompleteUnitIsSevenDoneDays() {
        let week = Dictionary(uniqueKeysWithValues: (0..<7).map { ($0, finished) })
        let path = map(today: 7, week)
        #expect(path.units[0].isComplete)
        #expect(!path.units[1].isComplete)
    }
}
