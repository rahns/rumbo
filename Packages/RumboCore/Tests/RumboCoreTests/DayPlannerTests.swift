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
        let learner = LearnerSnapshot(band: band, speakingStage: .calls, courseLastTrack: 40, dueReviewCards: 8)
        let plan = plan(budget, learner)

        #expect(plan.tasks.count <= DayPlanner.maxCards)
        #expect(plan.totalMinutes <= budget)
        #expect(plan.totalMinutes >= budget - 4, "\(band.rawValue) \(budget) min planned only \(plan.totalMinutes)")
        #expect(Set(plan.kinds).count == plan.tasks.count, "repeated tasks must be merged")
        for task in plan.tasks {
            #expect(task.minutes >= learner.minuteRange(for: task.kind).min && task.minutes <= learner.minuteRange(for: task.kind).max,
                    "\(task.kind.rawValue) has \(task.minutes) min")
            #expect(learner.isEligible(task.kind))
        }
    }

    @Test func tasksFollowSessionOrder() {
        let learner = LearnerSnapshot(band: .b1_1, speakingStage: .voiceNotes, courseLastTrack: 60, dueReviewCards: 6)
        for budget in DayPlanner.budgetChoices {
            let ranks = plan(budget, learner).tasks.map { task -> Int in
                switch task.kind {
                case .drillLesson: 0
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
            #expect(plan(budget).kinds.first == .drillLesson, "\(budget) min")
        }
        #expect(plan(15).task(.drillLesson)?.minutes == 3)
        #expect(plan(10).task(.drillLesson)?.minutes == 3)
    }

    @Test func duolingoFadesOutAtB2() {
        #expect(plan(30, LearnerSnapshot(band: .b1_2)).task(.drillLesson) != nil)
        #expect(plan(30, LearnerSnapshot(band: .b2_1)).task(.drillLesson) == nil)
        #expect(plan(30, LearnerSnapshot(band: .b2_1, keepDrillAppLate: true)).task(.drillLesson) != nil)
        #expect(plan(30, LearnerSnapshot(band: .b2_2, keepDrillAppLate: true)).task(.drillLesson) == nil)
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
        #expect(plan.kinds.first == .drillLesson)
        #expect(plan.tasks.count == 2)
        #expect(plan.totalMinutes == 10)
        #expect(plan.tasks.last?.kind.strand == .input, "with no history, input has the biggest deficit")
        // Without Duolingo, the one task takes the whole 10 minutes.
        #expect(self.plan(10, LearnerSnapshot(band: .b2_1)).tasks.count == 1)
    }

    // MARK: Deficits (steps 2–3)

    @Test func balancesAcrossTheWeek() {
        // Six days of only Dreaming Spanish: today should skip input entirely.
        let history = (1...6).map { ActivityRecord(date: TestCalendar.adding(days: -$0, to: today), kind: .gradedWatch, minutes: 30) }
        let plan = plan(30, history: history)
        #expect(plan.minutes(in: .input) == 0)
        #expect(plan.minutes(in: .languageFocused) > 0)
    }

    @Test func ignoresHistoryOlderThanSixDaysAndTodaysOwnLogs() {
        let old = ActivityRecord(date: TestCalendar.adding(days: -7, to: today), kind: .gradedWatch, minutes: 600)
        let todayLog = ActivityRecord(date: today, kind: .gradedWatch, minutes: 600)
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
            if plan.task(.courseTrack) != nil { learner.courseLastTrack += 1 }
        }
        return history
    }

    static let irregularFortnight = [15, 45, 20, 30, 10, 45, 30, 30, 15, 45, 20, 30, 10, 45]

    @Test(arguments: [
        // A complete beginner: Language Transfer from track 1, nothing else done yet.
        LearnerSnapshot(band: .a1_1),
        LearnerSnapshot(band: .a1_2, courseLastTrack: 20),
        LearnerSnapshot(band: .a2_1, courseLastTrack: 12, seriesEpisodesWatched: 1),
        LearnerSnapshot(band: .b1_1, speakingStage: .voiceNotes, courseLastTrack: 60, seriesEpisodesWatched: 5),
        // By B2.2 the courses are done, so language-focused time comes from the mistake deck.
        LearnerSnapshot(band: .b2_2, speakingStage: .calls, courseLastTrack: 90, seriesEpisodesWatched: 13, dueReviewCards: 8),
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
        #expect(days(.courseTrack) >= 4, "Language Transfer is the A2 grammar backbone")
        #expect((1...3).contains(days(.seriesIntensive)), "about one Extra part a week, for variety")
        #expect(days(.writeGuided) >= 2, "1 guided writing a week")
        #expect(history.filter(\.kind.isExchange).count >= 3, "about 2 Tandem exchanges a week at A2")
        #expect(days(.gradedWatch) >= 7)
    }

    // MARK: Progression details

    @Test func languageTransferTakesTheTracksRealLength() {
        #expect(LanguagePack.spanish.course?.trackSeconds.count == 90)
        // Track 13 is 9:38, so 10 minutes; track 14 is 15:10, so 16.
        #expect(LanguagePack.spanish.course?.minutes(track: 13) == 10)
        #expect(LanguagePack.spanish.course?.minutes(track: 14) == 16)
        for budget in [30, 45, 60] {
            if let task = plan(budget).task(.courseTrack) {
                #expect(task.minutes == 10, "\(budget) min: track 13 planned for \(task.minutes)")
            }
        }
        var learner = authorAtStart
        learner.courseLastTrack = 13
        let extras = planner.extraTasks(learner: learner, history: [], today: today, excluding: [])
        #expect(extras.first { $0.kind == .courseTrack }?.minutes == 16)
    }

    @Test func travelModeAlwaysPlansAMissionOnlineOrNot() {
        for online in [true, false] {
            var learner = authorAtStart
            learner.travelMode = true
            learner.isOnline = online
            for budget in DayPlanner.budgetChoices {
                let tasks = plan(budget, learner).tasks
                let missions = tasks.filter { $0.kind == .missionTravel }
                #expect(missions.count == 1, "\(budget) min, online: \(online)")
                #expect(missions.allSatisfy { $0.minutes == 3 }, "a mission is a short exchange, never stretched: \(budget) min")
                #expect(tasks.reduce(0) { $0 + $1.minutes } <= budget)
            }
        }
        #expect(plan(30, authorAtStart).tasks.allSatisfy { $0.kind != .missionTravel }, "not without travel mode")
    }

    @Test func otherPracticeIsLoggedNeverPlanned() {
        let others: [TaskKind] = [.otherStudy, .otherOutput, .otherFluency]
        for budget in DayPlanner.budgetChoices {
            #expect(plan(budget, authorAtStart).tasks.allSatisfy { !others.contains($0.kind) })
        }
        let extras = planner.extraTasks(learner: authorAtStart, history: [], today: today, excluding: [])
        #expect(extras.allSatisfy { !others.contains($0.kind) })
        for strand in Strand.allCases { #expect(TaskKind.other(for: strand).strand == strand) }
    }

    @Test func languageTransferPlansTheNextTrackOrRepeatsAShakyOne() {
        let fresh = plan(45).task(.courseTrack)
        #expect(fresh?.detail == .track(13))

        var learner = authorAtStart
        learner.courseRepeatPending = true
        #expect(plan(45, learner).task(.courseTrack)?.detail == .track(12))

        learner.courseLastTrack = 90
        #expect(plan(45, learner).task(.courseTrack) == nil)
    }

    @Test func extraIsIntensiveAtA2AndExtensiveAtB1() {
        let a2 = plan(45)
        #expect(a2.task(.seriesIntensive)?.detail == .seriesPart(episode: 2, part: 1))
        #expect(a2.task(.seriesIntensive)?.isAnchor == true)
        #expect(a2.task(.seriesExtensive) == nil)

        let b1 = plan(45, LearnerSnapshot(band: .b1_1, seriesEpisodesWatched: 4))
        #expect(b1.task(.seriesExtensive)?.detail == .seriesEpisode(5))
        #expect(b1.task(.seriesIntensive) == nil)
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
        let history = (0...6).map { ActivityRecord(date: TestCalendar.adding(days: -$0, to: today), kind: .gradedWatch, minutes: 30) }
        let extras = planner.extraTasks(learner: authorAtStart, history: history, today: today, excluding: [])
        #expect(extras.first?.kind.strand != .input)
        #expect(extras.last?.kind.strand == .input)
    }

    @Test func keepGoingPointsAtTheNextLessonAndEpisode() {
        let extras = planner.extraTasks(learner: authorAtStart, history: [], today: today, excluding: [])
        #expect(extras.first { $0.kind == .courseTrack }?.detail == .track(13))
        #expect(extras.first { $0.kind == .seriesIntensive }?.detail == .seriesPart(episode: 2, part: 1))
    }

    @Test func duolingoIsNeverMoreThanFiveMinutes() {
        for budget in DayPlanner.budgetChoices {
            #expect((plan(budget).task(.drillLesson)?.minutes ?? 0) <= 5, "\(budget) min")
        }
        // Even when only Duolingo is left in the language strand.
        var learner = authorAtStart
        learner.courseLastTrack = 90
        for budget in DayPlanner.budgetChoices {
            #expect((plan(budget, learner).task(.drillLesson)?.minutes ?? 0) <= 5, "\(budget) min, LT finished")
        }
    }

    @Test func dreamingSpanishLeadsAndExtraIsOccasional() {
        // Short days are Dreaming Spanish, even with Extra due.
        #expect(plan(15).task(.seriesIntensive) == nil)
        #expect(plan(15).task(.gradedWatch) != nil)
        // Over a fortnight, Dreaming Spanish clearly outnumbers Extra.
        let history = simulate(authorAtStart, budgets: Self.irregularFortnight)
        let ds = history.filter { $0.kind == .gradedWatch }.count
        let extra = history.filter { $0.kind == .seriesIntensive }.count
        #expect(ds >= 3 * extra && extra >= 1, "DS \(ds), Extra \(extra)")
    }

    @Test func extraAnchorStopsOnceThisWeeksPartsAreDone() {
        let history = [1, 3].map { ActivityRecord(date: TestCalendar.adding(days: -$0, to: today), kind: .seriesIntensive, minutes: 12) }
        #expect(plan(45, history: history).task(.seriesIntensive)?.isAnchor != true)
    }

    @Test func suggestedContentReplacesExtraOnceFinished() {
        let learner = LearnerSnapshot(band: .b1_2, seriesEpisodesWatched: 13)
        #expect(!learner.isEligible(.seriesExtensive))
        #expect(learner.isEligible(.contentWatch))
        #expect(!LearnerSnapshot(band: .a2_1).isEligible(.contentWatch))
    }

    @Test func dreamingCardsCarryTheDifficultyRange() {
        var learner = authorAtStart
        learner.enabledSources.remove(.learnerSeries)
        #expect(plan(45, learner).task(.gradedWatch)?.detail == .difficulty(40...48))
        #expect(plan(10, learner).task(.gradedWatch)?.detail == .difficulty(40...48))
        learner.band = .b1_1
        // Everything but fluency was covered this week, so a 10-minute day is one easy video.
        let history = (1...6).flatMap { offset in
            [(TaskKind.gradedWatch, 25), (.courseTrack, 8), (.exchangeText, 6)].map {
                ActivityRecord(date: TestCalendar.adding(days: -offset, to: today), kind: $0.0, minutes: $0.1)
            }
        }
        #expect(plan(10, learner, history: history).task(.gradedEasy)?.detail == .difficulty(25...30),
                "easy videos are 10–15 points below the current range")
    }

    @Test func focusPointsAtTodaysStructure() {
        #expect(plan(45).focus == .track(13))
    }

    // MARK: Sources, stages, travel

    @Test func disabledSourcesAreNeverPlanned() {
        var learner = authorAtStart
        learner.enabledSources.subtract([.gradedVideo, .drillApp])
        for budget in DayPlanner.budgetChoices {
            let plan = plan(budget, learner)
            #expect(!plan.tasks.contains { $0.kind.source == .gradedVideo || $0.kind.source == .drillApp })
            #expect(plan.totalMinutes > 0)
        }
    }

    @Test func speakingTasksFollowTheStage() {
        let text = LearnerSnapshot(band: .b1_1, speakingStage: .text)
        #expect(!text.isEligible(.exchangeVoice) && !text.isEligible(.fluency432) && !text.isEligible(.exchangeCall))
        let voice = LearnerSnapshot(band: .b1_1, speakingStage: .voiceNotes)
        #expect(voice.isEligible(.exchangeVoice) && voice.isEligible(.fluency432) && !voice.isEligible(.exchangeCall))
        #expect(LearnerSnapshot(band: .b1_1, speakingStage: .calls).isEligible(.exchangeCall))
    }

    @Test func oneCallAWeekOnceCallsAreUnlocked() {
        let learner = LearnerSnapshot(band: .b2_1, speakingStage: .calls, courseLastTrack: 90, seriesEpisodesWatched: 13, dueReviewCards: 8)
        let history = simulate(learner, budgets: [30, 30, 30, 30, 30, 30, 30])
        #expect(history.filter { $0.kind == .exchangeCall }.count == 1)
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
