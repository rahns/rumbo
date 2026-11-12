import Foundation
import Testing
@testable import RumboCore

@Suite struct LessonTests {
    let calendar = TestCalendar.utc
    let planner = DayPlanner(calendar: TestCalendar.utc)
    // A Monday (weekday 2); Wednesday is weekday 4.
    let monday = TestCalendar.day(2026, 10, 26)
    var wednesday: Date { TestCalendar.adding(days: 2, to: monday) }

    /// Tuesday and Thursday: 60 min speaking as usual; Thursday is 45 min of study instead.
    var schedule: LessonSchedule {
        LessonSchedule(days: [3: .init(), 5: .init(minutes: 45, type: .languageFocused)], usualMinutes: 60, usualType: .output)
    }

    func learner(_ lessons: LessonSchedule, duolingo: Bool = true) -> LearnerSnapshot {
        LearnerSnapshot(band: .a2_1, courseLastTrack: 13, alwaysIncludeDrillApp: duolingo, lessons: lessons)
    }

    @Test func aLessonDayAlwaysHasTheLessonAtItsLength() {
        let tuesday = TestCalendar.adding(days: 1, to: monday)
        for budget in DayPlanner.budgetChoices(lessonMinutes: 60) {
            let plan = planner.plan(budget: budget, learner: learner(schedule), history: [], today: tuesday)
            let lesson = plan.tasks.first { $0.kind.isLesson }
            #expect(lesson?.kind == .lessonOutput, "\(budget) min")
            #expect(lesson?.minutes == 60, "\(budget) min")
        }
        #expect(planner.plan(budget: 60, learner: learner(schedule), history: [], today: monday).tasks.allSatisfy { !$0.kind.isLesson },
                "no lesson on Monday")
    }

    @Test func aDaysOwnSettingsWinOverTheUsualOnes() {
        let thursday = TestCalendar.adding(days: 3, to: monday)
        let lesson = planner.plan(budget: 60, learner: learner(schedule), history: [], today: thursday).tasks.first { $0.kind.isLesson }
        #expect(lesson?.kind == .lessonStudy)
        #expect(lesson?.minutes == 45)
        #expect(schedule.lesson(weekday: 3)?.minutes == 60 && schedule.lesson(weekday: 3)?.type == .output)
    }

    @Test func theLessonUsesUpPartOfTheDaysTime() {
        let tuesday = TestCalendar.adding(days: 1, to: monday)
        let plan = planner.plan(budget: 90, learner: learner(schedule), history: [], today: tuesday)
        #expect(plan.totalMinutes <= 90)
        #expect(plan.tasks.first?.kind == .drillLesson, "Duolingo stays first")
        #expect(plan.tasks.dropFirst().first?.kind.isLesson == true, "then the lesson")
        // The lesson covers speaking, so the rest of the day isn't more speaking.
        #expect(plan.tasks.filter { $0.kind.strand == .output && !$0.kind.isLesson }.isEmpty)
        // When the lesson takes the whole time, the plan is the lesson and the daily Duolingo lesson.
        let short = planner.plan(budget: 30, learner: learner(schedule), history: [], today: tuesday)
        #expect(short.tasks.map(\.kind) == [.drillLesson, .lessonOutput])
    }

    @Test func lessonsAreNeverKeepGoingOptions() {
        let tuesday = TestCalendar.adding(days: 1, to: monday)
        let extras = planner.extraTasks(learner: learner(schedule), history: [], today: tuesday, excluding: [])
        #expect(extras.allSatisfy { !$0.kind.isLesson })
    }

    @Test func lessonTypesCountTowardTheirStrand() {
        #expect(TaskKind.lesson(for: .output).strand == .output)
        #expect(TaskKind.lesson(for: .input).strand == .input && TaskKind.lessonInput.countsAsInput)
        #expect(TaskKind.lesson(for: .languageFocused).strand == .languageFocused)
    }

    @Test func duolingoIsOnlyForcedInWhenTheToggleIsOn() {
        // On: a busy day is the 3-minute Duolingo lesson plus one task. Off: one task for the whole 10 minutes
        // (Duolingo can still be picked as a study task, but nothing reserves room for it).
        let on = planner.plan(budget: 10, learner: learner(LessonSchedule()), history: [], today: monday)
        #expect(on.tasks.first?.kind == .drillLesson && on.tasks.first?.minutes == 3)
        let off = planner.plan(budget: 10, learner: learner(LessonSchedule(), duolingo: false), history: [], today: monday)
        #expect(off.tasks.count == 1 && off.tasks.first?.minutes == 10)
    }

    @Test func adviceBalancesTheDaysLeftAroundLessons() {
        // Monday, 150-min goal, nothing done; lessons Tue 60 and Thu 45 over 7 days left.
        // Even level x with 5·x + max(x, 60) + max(x, 45) = 150 → x = 9 (rounded up from 9),
        // so Tue and Thu are just their lessons and the other five days need about 9 each.
        let advice = BudgetAdvisor.advice(weeklyGoal: 150, minutesThisWeek: 0, today: monday, lessons: schedule, calendar: calendar)
        #expect(advice.minutesPerDay == 9)
        #expect(advice.minutesToday == 9)
        #expect(advice.upcomingLessonMinutes == 105)
        #expect(advice.recommended == 10)
        // On Tuesday the recommendation covers the lesson.
        let tuesday = TestCalendar.adding(days: 1, to: monday)
        let lessonDay = BudgetAdvisor.advice(weeklyGoal: 150, minutesThisWeek: 9, today: tuesday, lessons: schedule, calendar: calendar)
        #expect(lessonDay.minutesToday == 60 && lessonDay.recommended == 60)
        #expect(lessonDay.upcomingLessonMinutes == 45)
        // A bigger goal lifts the other days above Thursday's lesson: 6 days left need 300; Tuesday's 60 binds,
        // so the other five share 240 → 48 each (Thursday's 45 is below that, so it's a normal day).
        let big = BudgetAdvisor.advice(weeklyGoal: 309, minutesThisWeek: 9, today: tuesday, lessons: schedule, calendar: calendar)
        #expect(big.minutesPerDay == 48 && big.minutesToday == 60)
        // Without lessons it's the plain share.
        let plain = BudgetAdvisor.advice(weeklyGoal: 140, minutesThisWeek: 0, today: monday, calendar: calendar)
        #expect(plain.minutesPerDay == 20 && plain.upcomingLessonMinutes == 0)
        #expect(DayPlanner.budgetChoices(lessonMinutes: 60).contains(90))
        #expect(!DayPlanner.budgetChoices(lessonMinutes: nil).contains(90))
        let done = BudgetAdvisor.advice(weeklyGoal: 150, minutesThisWeek: 200, today: tuesday, lessons: schedule, calendar: calendar)
        #expect(done.goalAlreadyMet && done.recommended >= 60)
    }

    @Test func levelSharesWhatsLeftEvenly() {
        #expect(BudgetAdvisor.level(remaining: 150, lessons: [0, 60, 0, 45, 0, 0, 0]) == 9)
        #expect(BudgetAdvisor.level(remaining: 100, lessons: [60, 60]) == 0, "the lessons cover it")
        #expect(BudgetAdvisor.level(remaining: 70, lessons: [0, 0]) == 35)
        #expect(BudgetAdvisor.level(remaining: 300, lessons: [60, 0, 45, 0, 0, 0]) == 48)
    }

    @Test func allInOneLessonsSplitEvenlyAcrossThreeAreas() {
        #expect(LessonType.split(minutes: 60).map(\.minutes) == [20, 20, 20])
        #expect(LessonType.split(minutes: 50).map(\.minutes) == [17, 17, 16])
        #expect(LessonType.split(minutes: 50).map(\.kind) == [.lessonOutput, .lessonInput, .lessonStudy])
        #expect(LessonType.split(minutes: 2).map(\.minutes) == [1, 1], "no empty parts")
        #expect(LessonType.splitOther(minutes: 30).map(\.kind) == [.otherOutput, .contentWatch, .otherStudy])
        #expect(LessonType.splitOther(minutes: 31).map(\.minutes) == [11, 10, 10])
        #expect(TaskKind.lesson(for: LessonType.allInOne) == .lessonMixed)
        #expect(TaskKind.lesson(for: LessonType.input) == .lessonInput)
    }

    @Test func anAllInOneLessonIsPlannedAsOneCardAndSharedInTheMix() {
        let tuesday = TestCalendar.adding(days: 1, to: monday)
        let mixed = LessonSchedule(days: [3: .init()], usualMinutes: 60, usualType: .allInOne)
        let plan = planner.plan(budget: 90, learner: learner(mixed), history: [], today: tuesday)
        #expect(plan.tasks.filter(\.kind.isLesson).map(\.kind) == [.lessonMixed])
        #expect(plan.tasks.first { $0.kind == .lessonMixed }?.minutes == 60)
        #expect(plan.totalMinutes <= 90)
    }

    @Test func schedulesSavedBeforeAllInOneStillDecode() throws {
        let old = Data(#"{"days":{"3":{"minutes":45,"strand":"languageFocused"}},"usualMinutes":60,"usualStrand":"output"}"#.utf8)
        let schedule = try JSONDecoder().decode(LessonSchedule.self, from: old)
        #expect(schedule.usualType == .output && schedule.lesson(weekday: 3)?.type == .languageFocused)
    }

    @Test func scheduleRoundTripsThroughJSON() throws {
        let data = try JSONEncoder().encode(schedule)
        #expect(try JSONDecoder().decode(LessonSchedule.self, from: data) == schedule)
    }
}
