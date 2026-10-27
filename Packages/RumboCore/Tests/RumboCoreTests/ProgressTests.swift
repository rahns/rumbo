import Foundation
import Testing
@testable import RumboCore

@Suite struct StreakTests {
    let calculator = StreakCalculator(weeklyGoalMinutes: 150, calendar: TestCalendar.utc)
    // A Monday, so ISO weeks are easy to reason about.
    let monday = TestCalendar.day(2026, 10, 26)

    func log(_ minutesPerDay: [Int], from start: Date) -> [ActivityRecord] {
        minutesPerDay.enumerated().compactMap { offset, minutes in
            minutes > 0 ? ActivityRecord(date: TestCalendar.adding(days: offset, to: start), kind: .dsWatch, minutes: minutes) : nil
        }
    }

    @Test func tenMinuteDaysCount() {
        let history = log([10, 15, 30], from: monday)
        #expect(calculator.status(history: history, today: TestCalendar.adding(days: 2, to: monday)).streak == 3)
    }

    @Test func aShortDayBreaksTheStreakWithoutAFreeze() {
        let history = log([20, 9, 20], from: monday)
        #expect(calculator.status(history: history, today: TestCalendar.adding(days: 2, to: monday)).streak == 1)
    }

    @Test func anUnfinishedTodayDoesNotBreakTheStreak() {
        let history = log([20, 20, 5], from: monday)
        #expect(calculator.status(history: history, today: TestCalendar.adding(days: 2, to: monday)).streak == 2)
    }

    @Test func meetingTheWeeklyGoalEarnsAFreezeThatSavesAMissedDay() {
        // Week 1: 7 × 30 = 210 min ≥ 150 → one freeze. Then one missed day in week 2.
        let history = log([30, 30, 30, 30, 30, 30, 30, 20, 0, 20], from: monday)
        let status = calculator.status(history: history, today: TestCalendar.adding(days: 9, to: monday))
        #expect(status.streak == 9, "the missed day is covered, not counted")
        #expect(status.freezes == 0)
    }

    @Test func freezesAreCappedAtThree() {
        let history = log(Array(repeating: 30, count: 35), from: monday)
        #expect(calculator.status(history: history, today: TestCalendar.adding(days: 35, to: monday)).freezes == 3)
    }

    @Test func xpAddsUp() {
        #expect(XP.total(minutes: 30, completedCards: 3, rewrites: 1, gatesPassed: 1) == 30 + 30 + 25 + 50)
    }
}

@Suite struct ProjectionTests {
    let projection = Projection(calendar: TestCalendar.utc)
    let today = TestCalendar.day(2026, 10, 26)

    @Test func weeklyHoursAverageFourWeeksOfInputOnly() {
        let history = (0..<28).flatMap { offset in
            [ActivityRecord(date: TestCalendar.adding(days: -offset, to: today), kind: .dsWatch, minutes: 30),
             ActivityRecord(date: TestCalendar.adding(days: -offset, to: today), kind: .writeGuided, minutes: 30)]
        }
        #expect(abs(projection.weeklyInputHours(history: history, today: today) - 3.5) < 0.001)
    }

    @Test func aNewLearnersPaceIsNotSpreadOverFourWeeks() {
        // One 15-minute session today: averaged over a week minimum, not four.
        let history = [ActivityRecord(date: today, kind: .dsWatch, minutes: 15)]
        #expect(abs(projection.weeklyInputHours(history: history, today: today) - 0.25) < 0.001)
        #expect(!projection.hasEnoughHistory(history, today: today))
    }

    @Test func twoWeeksOfHistoryUseTwoWeeks() {
        let history = (0..<14).map { ActivityRecord(date: TestCalendar.adding(days: -$0, to: today), kind: .dsWatch, minutes: 30) }
        #expect(abs(projection.weeklyInputHours(history: history, today: today) - 3.5) < 0.001)
        #expect(projection.hasEnoughHistory(history, today: today))
    }

    @Test func goalPaceUsesTheInputShare() {
        #expect(abs(Projection.weeklyInputHours(atGoalMinutes: 150, band: .a2_1) - 1.125) < 0.001)
    }

    @Test func arrivalDatesFollowThePace() {
        let dates = projection.arrivalDates(inputHours: 154, weeklyHours: 2, from: today)
        #expect(dates[.a2_1] == nil, "already reached")
        // 71 h to A2.2 at 2 h/week = 35.5 weeks = 248.5 days → 249.
        #expect(dates[.a2_2] == TestCalendar.adding(days: 249, to: today))
        #expect(projection.arrivalDates(inputHours: 154, weeklyHours: 0, from: today).isEmpty)
    }

    @Test func extraMinutesPerDayRaiseTheForecast() {
        let target = TestCalendar.adding(days: 365, to: today)
        let base = projection.inputHours(by: target, from: today, current: 154, weeklyHours: 2.1)
        let more = projection.inputHours(by: target, from: today, current: 154, weeklyHours: 2.1, extraMinutesPerDay: 30)
        #expect(abs(base - (154 + 2.1 / 7 * 365)) < 0.001)
        #expect(abs(more - base - 182.5) < 0.001)
    }
}

@Suite struct FSRSTests {
    let fsrs = FSRS()
    let start = TestCalendar.day(2026, 10, 26)

    @Test func aNewCardAnsweredGoodComesBackInThreeDays() {
        let card = fsrs.review(FSRS.Card(due: start), rating: .good, now: start)
        #expect(card.state == .review)
        #expect(card.due == TestCalendar.adding(days: 3, to: start))
        #expect(card.difficulty >= 1 && card.difficulty <= 10)
    }

    @Test func easyGivesALongerIntervalThanGood() {
        let good = fsrs.review(FSRS.Card(due: start), rating: .good, now: start)
        let easy = fsrs.review(FSRS.Card(due: start), rating: .easy, now: start)
        #expect(easy.due > good.due)
        #expect(easy.difficulty < good.difficulty)
    }

    @Test func againComesBackInTenMinutes() {
        let card = fsrs.review(FSRS.Card(due: start), rating: .again, now: start)
        #expect(card.state == .learning)
        #expect(card.due == start.addingTimeInterval(600))
    }

    @Test func successfulReviewsGrowTheInterval() {
        var card = fsrs.review(FSRS.Card(due: start), rating: .good, now: start)
        var previousInterval = card.due.timeIntervalSince(start)
        for _ in 0..<4 {
            let now = card.due
            card = fsrs.review(card, rating: .good, now: now)
            let interval = card.due.timeIntervalSince(now)
            #expect(interval > previousInterval)
            previousInterval = interval
        }
    }

    @Test func aLapseShrinksStabilityAndCountsALapse() {
        let learned = fsrs.review(FSRS.Card(due: start), rating: .good, now: start)
        let lapsed = fsrs.review(learned, rating: .again, now: learned.due)
        #expect(lapsed.lapses == 1)
        #expect(lapsed.state == .relearning)
        #expect(lapsed.stability < learned.stability)
        #expect(lapsed.difficulty > learned.difficulty)
    }

    @Test func retrievabilityIsNinetyPercentAtOneStability() {
        #expect(abs(fsrs.retrievability(elapsedDays: 10, stability: 10) - 0.9) < 0.0001)
        #expect(fsrs.intervalDays(stability: 10) == 10)
    }
}

@Suite struct BudgetAdvisorTests {
    // ISO weeks start on Monday; 26 Oct 2026 is a Monday.
    let calendar = TestCalendar.utc
    let monday = TestCalendar.day(2026, 10, 26)

    @Test func aFreshWeekSpreadsTheGoalOverSevenDays() {
        let advice = BudgetAdvisor.advice(weeklyGoal: 150, minutesThisWeek: 0, today: monday, calendar: calendar)
        #expect(advice.daysLeft == 7)
        #expect(advice.minutesPerDay == 22)
        #expect(advice.recommended == 30)
    }

    @Test func fallingBehindRaisesTheRecommendation() {
        let thursday = TestCalendar.adding(days: 3, to: monday)
        let advice = BudgetAdvisor.advice(weeklyGoal: 150, minutesThisWeek: 30, today: thursday, calendar: calendar)
        #expect(advice.daysLeft == 4)
        #expect(advice.minutesPerDay == 30)
        #expect(advice.recommended == 30)
        let sunday = TestCalendar.adding(days: 6, to: monday)
        #expect(BudgetAdvisor.advice(weeklyGoal: 150, minutesThisWeek: 30, today: sunday, calendar: calendar).recommended == 60,
                "more than an hour left on the last day still recommends the largest choice")
    }

    @Test func gettingAheadLowersIt() {
        let wednesday = TestCalendar.adding(days: 2, to: monday)
        let advice = BudgetAdvisor.advice(weeklyGoal: 150, minutesThisWeek: 120, today: wednesday, calendar: calendar)
        #expect(advice.minutesPerDay == 6)
        #expect(advice.recommended == 10)
    }

    @Test func aMetGoalRecommendsTheSmallestChoice() {
        let advice = BudgetAdvisor.advice(weeklyGoal: 150, minutesThisWeek: 160, today: monday, calendar: calendar)
        #expect(advice.goalAlreadyMet)
        #expect(advice.recommended == 10)
    }
}
