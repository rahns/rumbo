import Foundation
import Testing
@testable import RumboCore

@Suite struct PathLayoutTests {
    let calendar = TestCalendar.utc
    let start = TestCalendar.day(2026, 10, 26)

    @Test func firstDayIsOneUnitWithTodayFirst() {
        let units = PathLayout.units(start: start, today: start, history: [], calendar: calendar)
        #expect(units.count == 1)
        #expect(units[0].days.count == 7)
        #expect(units[0].days[0].status == .today)
        #expect(units[0].days[1...].allSatisfy { $0.status == .upcoming })
    }

    @Test func pastDaysAreDonePartialOrMissed() {
        let today = TestCalendar.adding(days: 3, to: start)
        let history = [
            ActivityRecord(date: start, kind: .dsWatch, minutes: 20),
            ActivityRecord(date: TestCalendar.adding(days: 1, to: start), kind: .duoLesson, minutes: 5),
        ]
        let days = PathLayout.units(start: start, today: today, history: history, calendar: calendar)[0].days
        #expect(days.map(\.status) == [.done, .partial, .missed, .today, .upcoming, .upcoming, .upcoming])
        #expect(days[0].minutes == 20)
    }

    @Test func unitsRollOverEverySevenDays() {
        let today = TestCalendar.adding(days: 7, to: start)
        let units = PathLayout.units(start: start, today: today, history: [], calendar: calendar)
        #expect(units.count == 2)
        #expect(units[1].days[0].status == .today)
        #expect(units[1].days[0].number == 8)
    }

    @Test func aCompleteUnitNeedsSevenDoneDays() {
        let history = (0..<7).map { ActivityRecord(date: TestCalendar.adding(days: $0, to: start), kind: .dsWatch, minutes: 15) }
        let units = PathLayout.units(start: start, today: TestCalendar.adding(days: 7, to: start), history: history, calendar: calendar)
        #expect(units[0].isComplete)
        #expect(!units[1].isComplete)
    }
}
