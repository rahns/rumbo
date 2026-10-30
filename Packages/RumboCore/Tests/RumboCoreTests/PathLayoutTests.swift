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

    @Test func weeksStartOnTheLearnersWeekStart() {
        // Started on a Thursday: the first week runs from that Monday, with Mon–Wed before the start.
        let thursday = TestCalendar.adding(days: 3, to: start)
        let path = PathLayout.map(start: thursday, today: TestCalendar.adding(days: 5, to: start), days: [:], arrivals: [:], calendar: calendar)
        #expect(path.allNodes.first?.date == day(0))
        #expect(path.units[0].nodes.prefix(4).map(\.status) == [.beforeStart, .beforeStart, .beforeStart, .missed])
        #expect(path.todayNode?.date == day(5))
        // With Sunday as the week start, the first week begins the Sunday before.
        var sundayFirst = calendar
        sundayFirst.firstWeekday = 1
        let sundayPath = PathLayout.map(start: thursday, today: thursday, days: [:], arrivals: [:], calendar: sundayFirst)
        #expect(sundayPath.allNodes.first?.date == day(-1))
    }

    @Test func aWeekCanBeCompleteWithDaysBeforeTheStart() {
        let thursday = TestCalendar.adding(days: 3, to: start)
        let finished = PathLayout.Day(minutes: 30, session: .finished)
        let days = Dictionary(uniqueKeysWithValues: (3...6).map { (day($0), finished) })
        let path = PathLayout.map(start: thursday, today: TestCalendar.adding(days: 7, to: start), days: days, arrivals: [:], calendar: calendar)
        #expect(path.units[0].isComplete)
    }

    @Test func aFrozenDayShowsAsFrozenNotMissed() {
        let path = PathLayout.map(start: start, today: TestCalendar.adding(days: 3, to: start),
                                  days: [day(0): finished, day(2): finished], arrivals: [:],
                                  frozen: [day(1)], calendar: calendar)
        #expect(path.allNodes.prefix(4).map(\.status) == [.done, .frozen, .done, .current])
    }

    @Test func freezeMarkersSitAfterTheirWeekEnd() {
        let path = PathLayout.map(start: start, today: TestCalendar.adding(days: 9, to: start), days: [:], arrivals: [:],
                                  freezesEarned: [(day: day(6), streak: 14)], nextFreeze: (day: day(20), daysLeft: 11), calendar: calendar)
        #expect(path.freezeMarkers.map(\.afterNode) == [7, 21])
        #expect(path.freezeMarkers.map(\.kind) == [.earned(streak: 14), .next(daysLeft: 11)])
        let beforeStart = PathLayout.map(start: start, today: start, days: [:], arrivals: [:], freezesEarned: [(day: day(-3), streak: 14)], calendar: calendar)
        #expect(beforeStart.freezeMarkers.isEmpty, "weeks before the path started aren't drawn")
    }

    @Test func finishingTodayMakesItDoneAndTomorrowStaysLocked() {
        let path = map(today: 2, [2: finished])
        #expect(path.todayNode?.status == .done)
        #expect(path.allNodes[3].status == .upcoming)
        #expect(path.focusNode == nil)
    }

    @Test func aDayFinishedEarlyInAnOlderVersionStillShowsDone() {
        let path = map(today: 2, [2: finished, 3: finished])
        #expect(path.allNodes[2...4].map(\.status) == [.done, .done, .upcoming])
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

    @Test func partlyDoneAndFrozenDaysStillMakeAWeekGold() {
        var days = Dictionary(uniqueKeysWithValues: (0..<7).map { (day($0), finished) })
        days[day(2)] = PathLayout.Day(minutes: 3, session: .unfinished)
        days[day(4)] = nil
        let path = PathLayout.map(start: start, today: TestCalendar.adding(days: 8, to: start), days: days, arrivals: [:],
                                  frozen: [day(4)], calendar: calendar)
        #expect(path.units[0].isComplete)
        #expect(path.units[0].isPast)
    }

    @Test func aPastWeekWithAMissedDayIsOverButNotGold() {
        var week = Dictionary(uniqueKeysWithValues: (0..<7).map { ($0, finished) })
        week[3] = nil
        let path = map(today: 8, week)
        #expect(path.units[0].isPast)
        #expect(!path.units[0].isComplete)
        #expect(!path.units[1].isPast, "this week isn't over yet")
    }
}
