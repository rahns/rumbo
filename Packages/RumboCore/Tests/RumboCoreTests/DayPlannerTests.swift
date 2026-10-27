import Foundation
import Testing
@testable import RumboCore

@Suite struct DayPlannerTests {
    let planner = DayPlanner(calendar: TestCalendar.utc)
    let today = TestCalendar.day(2026, 10, 26)

    func plan(_ budget: Int, _ learner: LearnerSnapshot = authorAtStart, history: [ActivityRecord] = []) -> DayPlan {
        planner.plan(budget: budget, learner: learner, history: history, today: today)
    }

    // MARK: Structural rules (§2.5 steps 4–5)

    @Test(arguments: Band.allCases, DayPlanner.budgetChoices)
    func plansAreWellFormed(band: Band, budget: Int) {
        let learner = LearnerSnapshot(band: band, speakingStage: .calls, languageTransferLastTrack: 40, dueReviewCards: 8)
        let plan = plan(budget, learner)

        #expect(plan.tasks.count <= DayPlanner.maxCards)
        #expect(plan.totalMinutes <= budget)
        #expect(plan.totalMinutes >= budget - 4, "\(band.rawValue) \(budget) min planned only \(plan.totalMinutes)")
        #expect(Set(plan.kinds).count == plan.tasks.count, "repeated tasks must be merged")
        for task in plan.tasks {
            #expect(task.minutes >= task.kind.minutes.min && task.minutes <= task.kind.minutes.max,
                    "\(task.kind.rawValue) has \(task.minutes) min")
            #expect(learner.isEligible(task.kind))
        }
    }

    @Test func tasksFollowSessionOrder() {
        let learner = LearnerSnapshot(band: .b1_1, speakingStage: .voiceNotes, languageTransferLastTrack: 60, dueReviewCards: 6)
        for budget in DayPlanner.budgetChoices {
            let ranks = plan(budget, learner).tasks.map { task -> Int in
                switch task.kind {
                case .duoLesson: 0
                case .reviewMistakes: 1
                default: [Strand.languageFocused: 2, .input: 3, .output: 4, .fluency: 5][task.kind.strand]!
                }
            }
            #expect(ranks == ranks.sorted(), "budget \(budget): \(ranks)")
        }
    }

    // MARK: Warm-up (step 1)

    @Test func duolingoEveryDayForTheStreak() {
        // One lesson (3 min) every day, first, including busy 10-minute days.
        for budget in DayPlanner.budgetChoices {
            #expect(plan(budget).kinds.first == .duoLesson, "\(budget) min")
        }
        #expect(plan(15).task(.duoLesson)?.minutes == 3)
        #expect(plan(10).task(.duoLesson)?.minutes == 3)
    }

    @Test func duolingoFadesOutAtB2() {
        #expect(plan(30, LearnerSnapshot(band: .b1_2)).task(.duoLesson) != nil)
        #expect(plan(30, LearnerSnapshot(band: .b2_1)).task(.duoLesson) == nil)
        #expect(plan(30, LearnerSnapshot(band: .b2_1, keepDuolingoInB2: true)).task(.duoLesson) != nil)
        #expect(plan(30, LearnerSnapshot(band: .b2_2, keepDuolingoInB2: true)).task(.duoLesson) == nil)
    }

    @Test func mistakeReviewWarmUpNeedsFiveDueCardsAndTwentyMinutes() {
        var learner = authorAtStart
        learner.dueReviewCards = 5
        #expect(plan(20, learner).task(.reviewMistakes)?.minutes == 3)
        #expect(plan(30, learner).task(.reviewMistakes)?.minutes == 5)
        #expect(plan(15, learner).task(.reviewMistakes) == nil)
        learner.dueReviewCards = 0
        #expect(!learner.isEligible(.reviewMistakes))
    }

    // MARK: Tiny days (step 7)

    @Test func tenMinuteDayIsDuolingoAndOneTask() {
        let plan = plan(10)
        #expect(plan.kinds.first == .duoLesson)
        #expect(plan.tasks.count == 2)
        #expect(plan.totalMinutes == 10)
        #expect(plan.tasks.last?.kind.strand == .input, "with no history, input has the biggest deficit")
        // Without Duolingo, the one task takes the whole 10 minutes.
        #expect(self.plan(10, LearnerSnapshot(band: .b2_1)).tasks.count == 1)
    }

    // MARK: Deficits (steps 2–3)

    @Test func balancesAcrossTheWeek() {
        // Six days of only Dreaming Spanish: today should skip input entirely.
        let history = (1...6).map { ActivityRecord(date: TestCalendar.adding(days: -$0, to: today), kind: .dsWatch, minutes: 30) }
        let plan = plan(30, history: history)
        #expect(plan.minutes(in: .input) == 0)
        #expect(plan.minutes(in: .languageFocused) > 0)
    }

    @Test func ignoresHistoryOlderThanSixDaysAndTodaysOwnLogs() {
        let old = ActivityRecord(date: TestCalendar.adding(days: -7, to: today), kind: .dsWatch, minutes: 600)
        let todayLog = ActivityRecord(date: today, kind: .dsWatch, minutes: 600)
        #expect(plan(30, history: [old, todayLog]) == plan(30))
    }

    /// Simulates following the plan every day, feeding each day's plan back in as history.
    func simulate(_ start: LearnerSnapshot, budgets: [Int]) -> [ActivityRecord] {
        var learner = start
        var history: [ActivityRecord] = []
        for (offset, budget) in budgets.enumerated() {
            let day = TestCalendar.adding(days: offset, to: today)
            let plan = planner.plan(budget: budget, learner: learner, history: history, today: day)
            history += plan.tasks.map { ActivityRecord(date: day, kind: $0.kind, minutes: $0.minutes) }
            if plan.task(.ltTrack) != nil { learner.languageTransferLastTrack += 1 }
        }
        return history
    }

    static let irregularFortnight = [15, 45, 20, 30, 10, 45, 30, 30, 15, 45, 20, 30, 10, 45]

    @Test(arguments: [
        LearnerSnapshot(band: .a2_1, languageTransferLastTrack: 12, extraEpisodesWatched: 1),
        LearnerSnapshot(band: .b1_1, speakingStage: .voiceNotes, languageTransferLastTrack: 60, extraEpisodesWatched: 5),
        // By B2.2 the courses are done, so language-focused time comes from the mistake deck.
        LearnerSnapshot(band: .b2_2, speakingStage: .calls, languageTransferLastTrack: 90, extraEpisodesWatched: 13, dueReviewCards: 8),
    ])
    func irregularDaysLandNearTheTargets(learner: LearnerSnapshot) {
        let history = simulate(learner, budgets: Self.irregularFortnight)
        let total = Double(history.reduce(0) { $0 + $1.minutes })
        for strand in Strand.allCases {
            let share = Double(history.filter { $0.kind.strand == strand }.reduce(0) { $0 + $1.minutes }) / total
            let target = learner.band.strandTargets[strand]!
            #expect(abs(share - target) <= 0.05, "\(learner.band.rawValue) \(strand): \(share) vs target \(target)")
        }
    }

    @Test func aFortnightAtA2CoversEveryRegularTask() {
        let history = simulate(authorAtStart, budgets: Self.irregularFortnight)
        func days(_ kind: TaskKind) -> Int { history.filter { $0.kind == kind }.count }
        #expect(days(.ltTrack) >= 4, "Language Transfer is the A2 grammar backbone")
        #expect((1...3).contains(days(.extraIntensive)), "about one Extra part a week, for variety")
        #expect(days(.writeGuided) >= 2, "1 guided writing a week")
        #expect(history.filter(\.kind.isTandemExchange).count >= 3, "about 2 Tandem exchanges a week at A2")
        #expect(days(.dsWatch) >= 7)
    }

    // MARK: Progression details

    @Test func languageTransferPlansTheNextTrackOrRepeatsAShakyOne() {
        let fresh = plan(45).task(.ltTrack)
        #expect(fresh?.detail == .languageTransferTrack(13))

        var learner = authorAtStart
        learner.languageTransferRepeatPending = true
        #expect(plan(45, learner).task(.ltTrack)?.detail == .languageTransferTrack(12))

        learner.languageTransferLastTrack = Course.languageTransferTracks
        #expect(plan(45, learner).task(.ltTrack) == nil)
    }

    @Test func extraIsIntensiveAtA2AndExtensiveAtB1() {
        let a2 = plan(45)
        #expect(a2.task(.extraIntensive)?.detail == .extraPart(episode: 2, part: 1))
        #expect(a2.task(.extraIntensive)?.isAnchor == true)
        #expect(a2.task(.extraExtensive) == nil)

        let b1 = plan(45, LearnerSnapshot(band: .b1_1, extraEpisodesWatched: 4))
        #expect(b1.task(.extraExtensive)?.detail == .extraEpisode(5))
        #expect(b1.task(.extraIntensive) == nil)
    }

    // MARK: Keep going (§2.5 step 8)

    @Test func keepGoingOffersEveryOtherEligibleTaskOnce() {
        let todays = plan(30)
        let extras = planner.extraTasks(learner: authorAtStart, history: [], today: today, excluding: Set(todays.kinds))
        #expect(Set(extras.map(\.kind)).isDisjoint(with: todays.kinds))
        #expect(Set(extras.map(\.kind)).count == extras.count)
        #expect(extras.allSatisfy { authorAtStart.isEligible($0.kind) && $0.minutes == $0.kind.minutes.standard && !$0.isAnchor })
        let everything = Set(TaskKind.allCases.filter(authorAtStart.isEligible))
        #expect(Set(extras.map(\.kind)).union(todays.kinds) == everything)
    }

    @Test func keepGoingLeadsWithTheMostBehindStrand() {
        // A week of nothing but listening, today included: study and output come before more input.
        let history = (0...6).map { ActivityRecord(date: TestCalendar.adding(days: -$0, to: today), kind: .dsWatch, minutes: 30) }
        let extras = planner.extraTasks(learner: authorAtStart, history: history, today: today, excluding: [])
        #expect(extras.first?.kind.strand != .input)
        #expect(extras.last?.kind.strand == .input)
    }

    @Test func keepGoingPointsAtTheNextLessonAndEpisode() {
        let extras = planner.extraTasks(learner: authorAtStart, history: [], today: today, excluding: [])
        #expect(extras.first { $0.kind == .ltTrack }?.detail == .languageTransferTrack(13))
        #expect(extras.first { $0.kind == .extraIntensive }?.detail == .extraPart(episode: 2, part: 1))
    }

    @Test func duolingoIsNeverMoreThanFiveMinutes() {
        for budget in DayPlanner.budgetChoices {
            #expect((plan(budget).task(.duoLesson)?.minutes ?? 0) <= 5, "\(budget) min")
        }
        // Even when only Duolingo is left in the language strand.
        var learner = authorAtStart
        learner.languageTransferLastTrack = Course.languageTransferTracks
        for budget in DayPlanner.budgetChoices {
            #expect((plan(budget, learner).task(.duoLesson)?.minutes ?? 0) <= 5, "\(budget) min, LT finished")
        }
    }

    @Test func dreamingSpanishLeadsAndExtraIsOccasional() {
        // Short days are Dreaming Spanish, even with Extra due.
        #expect(plan(15).task(.extraIntensive) == nil)
        #expect(plan(15).task(.dsWatch) != nil)
        // Over a fortnight, Dreaming Spanish clearly outnumbers Extra.
        let history = simulate(authorAtStart, budgets: Self.irregularFortnight)
        let ds = history.filter { $0.kind == .dsWatch }.count
        let extra = history.filter { $0.kind == .extraIntensive }.count
        #expect(ds >= 3 * extra && extra >= 1, "DS \(ds), Extra \(extra)")
    }

    @Test func extraAnchorStopsOnceThisWeeksPartsAreDone() {
        let history = [1, 3].map { ActivityRecord(date: TestCalendar.adding(days: -$0, to: today), kind: .extraIntensive, minutes: 12) }
        #expect(plan(45, history: history).task(.extraIntensive)?.isAnchor != true)
    }

    @Test func suggestedContentReplacesExtraOnceFinished() {
        let learner = LearnerSnapshot(band: .b1_2, extraEpisodesWatched: Course.extraEpisodes)
        #expect(!learner.isEligible(.extraExtensive))
        #expect(learner.isEligible(.contentWatch))
        #expect(!LearnerSnapshot(band: .a2_1).isEligible(.contentWatch))
    }

    @Test func dreamingCardsCarryTheDifficultyRange() {
        var learner = authorAtStart
        learner.enabledSources.remove(.extraEnEspanol)
        #expect(plan(45, learner).task(.dsWatch)?.detail == .dreamingDifficulty(40...48))
        #expect(plan(10, learner).task(.dsWatch)?.detail == .dreamingDifficulty(40...48))
        learner.band = .b1_1
        // Everything but fluency was covered this week, so a 10-minute day is one easy video.
        let history = (1...6).flatMap { offset in
            [(TaskKind.dsWatch, 25), (.ltTrack, 8), (.tandemText, 6)].map {
                ActivityRecord(date: TestCalendar.adding(days: -offset, to: today), kind: $0.0, minutes: $0.1)
            }
        }
        #expect(plan(10, learner, history: history).task(.dsEasy)?.detail == .dreamingDifficulty(25...30),
                "easy videos are 10–15 points below the current range")
    }

    @Test func focusPointsAtTodaysStructure() {
        #expect(plan(45).focus == .languageTransferTrack(13))
    }

    // MARK: Sources, stages, travel

    @Test func disabledSourcesAreNeverPlanned() {
        var learner = authorAtStart
        learner.enabledSources.subtract([.dreamingSpanish, .duolingo])
        for budget in DayPlanner.budgetChoices {
            let plan = plan(budget, learner)
            #expect(!plan.tasks.contains { $0.kind.source == .dreamingSpanish || $0.kind.source == .duolingo })
            #expect(plan.totalMinutes > 0)
        }
    }

    @Test func speakingTasksFollowTheStage() {
        let text = LearnerSnapshot(band: .b1_1, speakingStage: .text)
        #expect(!text.isEligible(.tandemVoice) && !text.isEligible(.fluency432) && !text.isEligible(.tandemCall))
        let voice = LearnerSnapshot(band: .b1_1, speakingStage: .voiceNotes)
        #expect(voice.isEligible(.tandemVoice) && voice.isEligible(.fluency432) && !voice.isEligible(.tandemCall))
        #expect(LearnerSnapshot(band: .b1_1, speakingStage: .calls).isEligible(.tandemCall))
    }

    @Test func oneCallAWeekOnceCallsAreUnlocked() {
        let learner = LearnerSnapshot(band: .b2_1, speakingStage: .calls, languageTransferLastTrack: 90, extraEpisodesWatched: 13, dueReviewCards: 8)
        let history = simulate(learner, budgets: [30, 30, 30, 30, 30, 30, 30])
        #expect(history.filter { $0.kind == .tandemCall }.count == 1)
    }

    @Test func travelModeOfflinePrefersMissionsAndSkipsOnlineTasks() {
        var learner = authorAtStart
        learner.travelMode = true
        learner.isOnline = false
        let plan = plan(45, learner)
        #expect(plan.task(.missionTravel) != nil)
        #expect(plan.tasks.allSatisfy { $0.kind.isOfflineCapable })
    }

    @Test func emptyPlanWhenNothingIsEnabled() {
        var learner = authorAtStart
        learner.enabledSources = []
        #expect(plan(30, learner).tasks.isEmpty)
    }
}
