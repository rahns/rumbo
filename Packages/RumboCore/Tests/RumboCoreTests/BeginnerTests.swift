import Foundation
import Testing
@testable import RumboCore

/// Complete beginners: A1.1 (from zero) and A1.2. See docs/10-beginners.md.
@Suite struct BeginnerTests {
    let planner = DayPlanner(calendar: TestCalendar.utc)
    let today = TestCalendar.day(2026, 10, 26)

    func plan(_ budget: Int, _ learner: LearnerSnapshot) -> DayPlan {
        planner.plan(budget: budget, learner: learner, history: [], today: today)
    }

    @Test func levelsStartFromZero() {
        #expect(Band.allCases.first == .a1_1)
        #expect(Band.a1_1 < .a1_2 && Band.a1_2 < .a2_1)
        #expect(LanguagePack.spanish.levels.threshold(.a1_1) == 0)
        #expect(LanguagePack.spanish.levels.threshold(.a1_2) == 90, "Dreaming's level 2 (50 h of listening) ÷ 55%")
        #expect(LanguagePack.french.levels.threshold(.a1_2) == 100)
        #expect(LanguagePack.spanish.levels.band(forHours: 0) == .a1_1)
        #expect(LanguagePack.spanish.levelName(.a1_1) == "Novato")
        #expect(LanguagePack.french.levelName(.a1_2) == "Apprenti")
    }

    @Test func beginnersStudyMoreAndSpeakLess() {
        #expect(Band.a1_1.strandTargets[.languageFocused]! > Band.a1_2.strandTargets[.languageFocused]!)
        #expect(Band.a1_2.strandTargets[.languageFocused]! > Band.a2_1.strandTargets[.languageFocused]!)
        #expect(Band.a1_1.strandTargets[.output]! < Band.a1_2.strandTargets[.output]!)
        #expect(Band.a1_2.strandTargets[.output]! < Band.a2_1.strandTargets[.output]!)
    }

    @Test func noWeeklyAnchorsAtTheVeryStart() {
        for pack in LanguagePack.all {
            #expect(pack.anchorTargets(for: .a1_1) == AnchorTargets())
            let a12 = pack.anchorTargets(for: .a1_2)
            #expect(a12.writing == 1 && a12.exchanges == 1 && a12.seriesIntensiveParts == 0)
        }
    }

    @Test func beginnersDontGetTasksMadeForLater() {
        for band in [Band.a1_1, .a1_2] {
            let learner = LearnerSnapshot(band: band, speakingStage: .text)
            #expect(!learner.isEligible(.seriesIntensive), "Extra waits for A2")
            #expect(!learner.isEligible(.seriesExtensive))
            #expect(!learner.isEligible(.writeQuick))
            #expect(!learner.isEligible(.fluency432) && !learner.isEligible(.exchangeVoice))
            #expect(learner.isEligible(.courseTrack) && learner.isEligible(.drillLesson) && learner.isEligible(.gradedWatch))
            for budget in DayPlanner.budgetChoices {
                let kinds = plan(budget, learner).kinds
                #expect(!kinds.contains(.seriesIntensive) && !kinds.contains(.writeQuick), "\(band.rawValue) \(budget) min: \(kinds)")
            }
        }
    }

    @Test func aCompleteBeginnersDayStartsWithTheCourseAndListening() {
        let learner = LearnerSnapshot(band: .a1_1)
        let day = plan(30, learner)
        #expect((5...15).contains(day.task(.drillLesson)?.minutes ?? 0), "at least a five-minute Duolingo lesson: \(day.tasks.map { "\($0.kind.rawValue) \($0.minutes)" })")
        #expect(day.task(.courseTrack)?.detail == .track(1))
        #expect(day.task(.gradedWatch) != nil)
        #expect(day.totalMinutes == 30)
    }

    @Test func theDrillAppCanCarryGrammarTimeForBeginners() {
        // No audio course: Duolingo is the beginner's study time, up to 15 minutes, not a 5-minute cap.
        var learner = LearnerSnapshot(band: .a1_1, enabledSources: Set(SourceKind.allCases).subtracting([.audioCourse]))
        #expect(learner.minuteRange(for: .drillLesson) == MinuteRange(min: 3, standard: 5, max: 15))
        let day = plan(45, learner)
        #expect((day.task(.drillLesson)?.minutes ?? 0) > 5, "\(day.tasks.map { "\($0.kind.rawValue) \($0.minutes)" })")
        #expect((day.task(.drillLesson)?.minutes ?? 0) <= 15)
        // From A2 it's a warm-up again.
        learner.band = .a2_1
        #expect(learner.minuteRange(for: .drillLesson) == TaskKind.drillLesson.minutes)
        #expect(plan(45, learner).task(.drillLesson)?.minutes ?? 0 <= 5)
    }

    @Test func easyVideosNearTheBottomAreTheEasiestWindow() {
        let graded = LanguagePack.spanish.graded!
        #expect(graded.easyRange(below: 0) == 0...5)
        #expect(graded.easyRange(below: 10) == 0...5)
        #expect(graded.easyRange(below: 40) == 25...30, "unchanged further up")
    }

    @Test func beginnerWritingIsShortAndHasItsOwnPrompts() {
        #expect(Prompts.wordTarget(for: .a1_1) == 15...40)
        #expect(Prompts.Level(.a1_2) == .a1)
        let writing = Prompts.writingPrompts[.a1]!, exchange = Prompts.exchangePrompts[.a1]!
        #expect(writing.count >= 60 && Set(writing).count == writing.count)
        #expect(exchange.count >= 40 && Set(exchange).count == exchange.count)
        #expect(Prompts.writing(for: .a1_1, on: today, pack: .french, calendar: TestCalendar.utc) != Prompts.writing(for: .a2_1, on: today, pack: .french, calendar: TestCalendar.utc))
    }

    @Test func placementForSomeoneStartingFromZero() {
        let levels = LanguagePack.spanish.levels
        // Zero hours and no can-dos: A1.1. A few hours and confident answers: up to A1.2.
        #expect(Placement.place(hours: 0, ownBandYes: 0, nextBandYes: 0, statementsPerBand: 5, levels: levels).band == .a1_1)
        #expect(Placement.place(hours: 40, ownBandYes: 5, nextBandYes: 4, statementsPerBand: 5, levels: levels).band == .a1_2)
        #expect(CanDo.statements(for: .a1_1, pack: .spanish).count == CanDo.perBand)
        #expect(CanDo.statements(for: .a1_2, pack: .french).count == CanDo.perBand)
        let sample = CanDo.placementStatements(for: .a1_1, pack: .spanish)
        #expect(sample.own.count == 5 && sample.next.count == 5)
        // The first level-up check comes at A1.2's hours.
        #expect(LevelGate.isOpen(band: .a1_1, hours: 90, lastFailedAttempt: nil, today: today, levels: levels))
        #expect(!LevelGate.isOpen(band: .a1_1, hours: 89, lastFailedAttempt: nil, today: today, levels: levels))
    }

    @Test func beginnersSeeTheAppInEnglishExceptPicosCheers() {
        for pack in LanguagePack.all {
            let beginner = pack.phrases(for: .a1_1)
            #expect(beginner.week == "Week" && beginner.today == "Today" && beginner.done == "Done!")
            // Greetings, level names and the reminder title stay in the language.
            #expect(beginner.greeting(hour: 9, name: "Ana") == pack.phrases.greeting(hour: 9, name: "Ana"))
            #expect(beginner.levelNames == pack.phrases.levelNames && beginner.reminderTitle == pack.phrases.reminderTitle)
            #expect(beginner.yes == "Yes!" && beginner.notYet == "Not yet")
            #expect(beginner.squawks == pack.phrases.squawks, "Pico still cheers in \(pack.name)")
            #expect(pack.dateLocale(for: .a1_1).identifier == "en")
            // From A1.2, the language's own words.
            #expect(pack.phrases(for: .a1_2) == pack.phrases)
            #expect(pack.phrases(for: .a2_1) == pack.phrases)
            #expect(pack.dateLocale(for: .a1_2).identifier == pack.localeIdentifier)
        }
        #expect(Band.a1_1.usesEnglishInterface && !Band.a1_2.usesEnglishInterface)
        #expect(Phrasebook.english.allStrings.allSatisfy { !$0.isEmpty })
    }

    @Test func noFluencyPracticeAtA1() {
        for band in [Band.a1_1, .a1_2] {
            #expect(band.strandTargets[.fluency] == 0)
            let learner = LearnerSnapshot(band: band, speakingStage: .calls)
            #expect(learner.strandTargets[.fluency] == 0)
            for budget in DayPlanner.budgetChoices {
                #expect(plan(budget, learner).tasks.allSatisfy { $0.kind.strand != .fluency }, "\(band.rawValue) \(budget) min")
            }
            let extras = planner.extraTasks(learner: learner, history: [], today: today, excluding: [])
            #expect(!extras.isEmpty && extras.allSatisfy { $0.kind.strand != .fluency }, "not offered in Keep going either")
        }
        #expect(Band.a2_1.strandTargets[.fluency]! > 0)
    }

    @Test func noSeparateSpeakingOrWritingAtA1_1() {
        #expect(Band.a1_1.strandTargets[.output] == 0)
        let learner = LearnerSnapshot(band: .a1_1, speakingStage: .calls)
        for budget in DayPlanner.budgetChoices {
            #expect(plan(budget, learner).tasks.allSatisfy { $0.kind.strand != .output }, "\(budget) min")
        }
        // Travel mode still plans its mission: that's the learner's own choice.
        var traveller = learner
        traveller.travelMode = true
        #expect(plan(30, traveller).task(.missionTravel) != nil)
        #expect(Band.a1_1.firstBand(including: .output) == .a1_2)
        #expect(Band.a1_1.firstBand(including: .fluency) == .a2_1)
        #expect(Band.a1_2.firstBand(including: .fluency) == .a2_1)
        #expect(Band.b1_1.firstBand(including: .fluency) == .b1_1)
    }

    @Test func aCompleteBeginnerStudiesMoreThanTheyListen() {
        #expect(Band.a1_1.strandTargets[.input] == 0.45 && Band.a1_1.strandTargets[.languageFocused] == 0.55)
        let learner = LearnerSnapshot(band: .a1_1)
        // From 20 minutes the course track is always in, alongside Duolingo and some listening.
        for budget in DayPlanner.budgetChoices where budget >= 20 {
            let day = plan(budget, learner)
            #expect(day.task(.courseTrack) != nil && day.task(.gradedWatch) != nil, "\(budget) min: \(day.kinds)")
        }
        // A fortnight of irregular days lands near 45 / 55.
        var history: [ActivityRecord] = []
        var current = learner
        for (offset, budget) in [15, 45, 20, 30, 10, 45, 30, 30, 15, 45, 20, 30, 10, 45].enumerated() {
            let day = TestCalendar.adding(days: offset, to: today)
            let p = planner.plan(budget: budget, learner: current, history: history, today: day)
            history += p.tasks.map { ActivityRecord(date: day, kind: $0.kind, minutes: $0.minutes) }
            if p.task(.courseTrack) != nil { current.courseLastTrack += 1 }
        }
        let total = Double(history.reduce(0) { $0 + $1.minutes })
        let study = Double(history.filter { $0.kind.strand == .languageFocused }.reduce(0) { $0 + $1.minutes }) / total
        #expect(abs(study - 0.55) <= 0.06, "study share \(study)")
    }

    @Test(arguments: [Band.a1_1, .a1_2])
    func alwaysIncludeDuolingoIsRespectedForBeginners(band: Band) {
        var learner = LearnerSnapshot(band: band)
        for budget in DayPlanner.budgetChoices {
            #expect(plan(budget, learner).task(.drillLesson) != nil, "\(band.rawValue) \(budget) min: Duolingo is always in")
        }
        // Switched off, it's one of the study options, not a daily fixture, and the course is still planned.
        learner.alwaysIncludeDrillApp = false
        #expect(plan(20, learner).task(.courseTrack) != nil)
    }
}
