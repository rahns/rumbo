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
        #expect(status.lastFreezeUsed == TestCalendar.utc.startOfDay(for: TestCalendar.adding(days: 8, to: monday)),
                "the app shows that the freeze saved the streak")
    }

    @Test func noFreezeReportedWithoutOneOrAfterTheStreakBreaks() {
        #expect(calculator.status(history: log([20, 20, 20], from: monday), today: TestCalendar.adding(days: 2, to: monday)).lastFreezeUsed == nil)
        // The freeze saves day 8, then days 10–11 are missed with none left: the streak resets, so nothing to show.
        let history = log([30, 30, 30, 30, 30, 30, 30, 20, 0, 20, 0, 0, 20], from: monday)
        let status = calculator.status(history: history, today: TestCalendar.adding(days: 12, to: monday))
        #expect(status.streak == 1)
        #expect(status.lastFreezeUsed == nil)
    }

    @Test func freezesAreCappedAtThree() {
        let history = log(Array(repeating: 30, count: 35), from: monday)
        #expect(calculator.status(history: history, today: TestCalendar.adding(days: 35, to: monday)).freezes == 3)
    }

    // MARK: Goal pace

    @Test func weeklyGoalSetsTheArrivalDate() {
        // 290 h → B2.1 (1,090 h): 800 h at 150 min = 2.5 h a week = 320 weeks.
        let arrival = GoalPace.arrival(of: .b2_1, currentHours: 290, weeklyMinutes: 150, from: monday, calendar: TestCalendar.utc)
        #expect(TestCalendar.utc.dateComponents([.day], from: TestCalendar.utc.startOfDay(for: monday), to: arrival).day == 2240)
        // Twice the goal, half the time.
        let faster = GoalPace.arrival(of: .b2_1, currentHours: 290, weeklyMinutes: 300, from: monday, calendar: TestCalendar.utc)
        #expect(faster < arrival)
    }

    @Test func targetDateSetsTheWeeklyGoalAndTheTwoAgree() {
        let date = TestCalendar.adding(days: 7 * 90, to: monday)
        let minutes = GoalPace.weeklyMinutes(toReach: .b2_1, by: date, currentHours: 290, from: monday, calendar: TestCalendar.utc)
        #expect(minutes % GoalPace.step == 0)
        // 800 h over 90 weeks ≈ 8.9 h a week ≈ 533 min → 540.
        #expect(minutes == 540)
        // Going back the other way lands on or just before the chosen date.
        let back = GoalPace.arrival(of: .b2_1, currentHours: 290, weeklyMinutes: minutes, from: monday, calendar: TestCalendar.utc)
        #expect(back <= TestCalendar.utc.startOfDay(for: date))
    }

    @Test func goalPaceStaysInRange() {
        let tomorrow = TestCalendar.adding(days: 1, to: monday)
        #expect(GoalPace.weeklyMinutes(toReach: .b2_1, by: tomorrow, currentHours: 290, from: monday) == GoalPace.minutes.upperBound)
        #expect(GoalPace.isOutOfReach(.b2_1, by: tomorrow, currentHours: 290, from: monday, calendar: TestCalendar.utc))
        let farAway = TestCalendar.adding(days: 365 * 100, to: monday)
        #expect(GoalPace.weeklyMinutes(toReach: .b2_1, by: farAway, currentHours: 290, from: monday) == GoalPace.minutes.lowerBound)
        // Already there: no extra time needed.
        #expect(GoalPace.weeklyMinutes(toReach: .b1_1, by: farAway, currentHours: 600, from: monday) == GoalPace.minutes.lowerBound)
    }

}

@Suite struct ProjectionTests {
    let projection = Projection(calendar: TestCalendar.utc)
    let today = TestCalendar.day(2026, 10, 26)

    @Test func weeklyHoursAverageFourWeeksOfAllTraining() {
        let history = (0..<28).flatMap { offset in
            [ActivityRecord(date: TestCalendar.adding(days: -offset, to: today), kind: .dsWatch, minutes: 30),
             ActivityRecord(date: TestCalendar.adding(days: -offset, to: today), kind: .writeGuided, minutes: 30)]
        }
        // Listening and writing both count: 60 min a day = 7 h a week.
        #expect(abs(projection.weeklyHours(history: history, today: today) - 7) < 0.001)
    }

    @Test func aNewLearnersPaceIsNotSpreadOverFourWeeks() {
        // One 15-minute session today: averaged over a week minimum, not four.
        let history = [ActivityRecord(date: today, kind: .dsWatch, minutes: 15)]
        #expect(abs(projection.weeklyHours(history: history, today: today) - 0.25) < 0.001)
        #expect(!projection.hasEnoughHistory(history, today: today))
    }

    @Test func twoWeeksOfHistoryUseTwoWeeks() {
        let history = (0..<14).map { ActivityRecord(date: TestCalendar.adding(days: -$0, to: today), kind: .dsWatch, minutes: 30) }
        #expect(abs(projection.weeklyHours(history: history, today: today) - 3.5) < 0.001)
        #expect(projection.hasEnoughHistory(history, today: today))
    }

    @Test func goalPaceCountsEveryMinute() {
        #expect(abs(Projection.weeklyHours(atGoalMinutes: 150) - 2.5) < 0.001)
    }

    @Test func levelHoursAreListeningMilestonesOverTheListeningShare() {
        for (band, listening) in zip(Band.allCases, [150.0, 225, 300, 450, 600, 800]) {
            #expect(abs(band.hoursThreshold - (listening / Band.listeningShare / 10).rounded() * 10) < 0.001, "\(band.rawValue)")
            #expect(abs((band.strandTargets[.input] ?? 0) - Band.listeningShare) < 0.001)
        }
        #expect(abs(Band.trainingHours(fromListening: 150) - 272.7) < 0.1)
    }

    @Test func arrivalDatesFollowThePace() {
        let dates = projection.arrivalDates(hours: 280, weeklyHours: 2, from: today)
        #expect(dates[.a2_1] == nil, "already reached")
        // 130 h to A2.2 at 2 h/week = 65 weeks = 455 days.
        #expect(dates[.a2_2] == TestCalendar.adding(days: 455, to: today))
        #expect(projection.arrivalDates(hours: 280, weeklyHours: 0, from: today).isEmpty)
    }

    @Test func extraMinutesPerDayRaiseTheForecast() {
        let target = TestCalendar.adding(days: 365, to: today)
        let base = projection.hours(by: target, from: today, current: 154, weeklyHours: 2.1)
        let more = projection.hours(by: target, from: today, current: 154, weeklyHours: 2.1, extraMinutesPerDay: 30)
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

@Suite struct WeekStartTests {
    func calendar(firstWeekday: Int) -> Calendar {
        var calendar = TestCalendar.utc
        calendar.firstWeekday = firstWeekday
        return calendar
    }

    // 1 Nov 2026 is a Sunday.
    let sunday = TestCalendar.day(2026, 11, 1)

    @Test func sundayStartMakesSundayTheFirstDayOfTheWeek() {
        #expect(BudgetAdvisor.advice(weeklyGoal: 140, minutesThisWeek: 0, today: sunday, calendar: calendar(firstWeekday: 1)).daysLeft == 7)
        #expect(BudgetAdvisor.advice(weeklyGoal: 140, minutesThisWeek: 0, today: sunday, calendar: calendar(firstWeekday: 2)).daysLeft == 1)
    }

    @Test func weeklyMinutesResetOnTheChosenDay() {
        let saturday = TestCalendar.adding(days: -1, to: sunday)
        let history = [ActivityRecord(date: saturday, kind: .dsWatch, minutes: 30)]
        let sundayStart = StreakCalculator(weeklyGoalMinutes: 150, calendar: calendar(firstWeekday: 1)).status(history: history, today: sunday)
        let mondayStart = StreakCalculator(weeklyGoalMinutes: 150, calendar: calendar(firstWeekday: 2)).status(history: history, today: sunday)
        #expect(sundayStart.minutesThisWeek == 0, "Saturday belongs to last week when weeks start on Sunday")
        #expect(mondayStart.minutesThisWeek == 30)
    }
}
