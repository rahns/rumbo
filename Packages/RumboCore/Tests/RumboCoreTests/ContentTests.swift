import Foundation
import Testing
@testable import RumboCore

@Suite struct SourceProgressTests {
    @Test func solidTrackMovesOn() {
        var progress = SourceProgress(courseLastTrack: 12)
        progress.record(.courseTrack, trackRating: .solid, pack: .spanish)
        #expect(progress.courseLastTrack == 13)
        #expect(!progress.courseRepeatPending)
    }

    @Test func shakyTrackIsRepeatedOnceThenMovesOn() {
        var progress = SourceProgress(courseLastTrack: 12)
        progress.record(.courseTrack, trackRating: .shaky, pack: .spanish)
        #expect(progress.courseLastTrack == 13)
        #expect(progress.courseRepeatPending, "next session repeats track 13")

        progress.record(.courseTrack, trackRating: .shaky, pack: .spanish)
        #expect(progress.courseLastTrack == 13)
        #expect(!progress.courseRepeatPending, "only one repeat")

        progress.record(.courseTrack, trackRating: .solid, pack: .spanish)
        #expect(progress.courseLastTrack == 14)
    }

    @Test func plannerShowsTheRepeatedTrack() {
        var progress = SourceProgress(courseLastTrack: 12)
        progress.record(.courseTrack, trackRating: .shaky, pack: .spanish)
        let learner = LearnerSnapshot(band: .a2_1, courseLastTrack: progress.courseLastTrack,
                                      courseRepeatPending: progress.courseRepeatPending)
        let plan = DayPlanner(calendar: TestCalendar.utc).plan(budget: 60, learner: learner, history: [], today: TestCalendar.day(2026, 10, 26))
        #expect(plan.task(.courseTrack)?.detail == .track(13))
    }

    @Test func twoIntensivePartsFinishAnEpisode() {
        var progress = SourceProgress(seriesEpisodesWatched: 1)
        progress.record(.seriesIntensive, pack: .spanish)
        #expect(progress.seriesEpisodesWatched == 1 && progress.seriesPartsDone == 1)
        progress.record(.seriesIntensive, pack: .spanish)
        #expect(progress.seriesEpisodesWatched == 2 && progress.seriesPartsDone == 0)
    }

    @Test func undoRestoresOnlyThatTasksCourse() {
        let start = SourceProgress(courseLastTrack: 12, seriesEpisodesWatched: 1, seriesPartsDone: 1)
        var progress = start
        progress.record(.courseTrack, trackRating: .solid, pack: .spanish)
        progress.record(.seriesIntensive, pack: .spanish)
        let afterExtra = progress
        progress.undo(.courseTrack, before: start)
        #expect(progress.courseLastTrack == 12)
        #expect(progress.seriesEpisodesWatched == afterExtra.seriesEpisodesWatched, "Extra progress is kept")
        progress.undo(.seriesIntensive, before: start)
        #expect(progress == start)
    }

    @Test func coursesStopAtTheirLastEpisodeAndTrack() {
        var progress = SourceProgress(courseLastTrack: 90, seriesEpisodesWatched: 13)
        progress.record(.courseTrack, trackRating: .solid, pack: .spanish)
        progress.record(.seriesExtensive, pack: .spanish)
        #expect(progress.courseLastTrack == 90 && progress.seriesEpisodesWatched == 13)
    }
}

@Suite struct CanDoTests {
    @Test(arguments: Band.allCases)
    func everyBandHasTenDistinctStatements(band: Band) {
        let statements = CanDo.statements(for: band, pack: .spanish)
        #expect(statements.count == CanDo.perBand)
        #expect(Set(statements).count == statements.count)
    }

    @Test func placementSampleIsFivePlusFive() {
        let sample = CanDo.placementStatements(for: .a2_1, pack: .spanish)
        #expect(sample.own.count == 5 && sample.next.count == 5)
        #expect(CanDo.placementStatements(for: .b2_2, pack: .spanish).next.isEmpty)
    }

    @Test func placementWorksWithTheFivePlusFiveSample() {
        #expect(Placement.place(hours: 280, ownBandYes: 5, nextBandYes: 4, statementsPerBand: 5, levels: LanguagePack.spanish.levels).band == .a2_2)
        #expect(Placement.place(hours: 280, ownBandYes: 5, nextBandYes: 3, statementsPerBand: 5, levels: LanguagePack.spanish.levels).band == .a2_1)
        #expect(Placement.place(hours: 582, ownBandYes: 2, nextBandYes: 0, statementsPerBand: 5, levels: LanguagePack.spanish.levels).band == .a2_2)
    }
}

@Suite struct PromptTests {
    @Test func sameDaySamePromptAndDaysVary() {
        let calendar = TestCalendar.utc
        let day = TestCalendar.day(2026, 10, 26)
        #expect(Prompts.writing(for: .a2_1, on: day, pack: .spanish, calendar: calendar) == Prompts.writing(for: .a2_2, on: day, pack: .spanish, calendar: calendar))
        let week = (0..<7).map { Prompts.writing(for: .a2_1, on: TestCalendar.adding(days: $0, to: day), pack: .spanish, calendar: calendar) }
        #expect(Set(week).count == 7)
    }

    @Test func librariesAreBigAndHaveNoDuplicates() {
        for level in [Prompts.Level.a2, .b1, .b2] {
            let writing = Prompts.writingPrompts[level]!
            #expect(writing.count >= 100, "guided writing: \(writing.count)")
            #expect(Set(writing).count == writing.count)
            let tandem = Prompts.exchangePrompts[level]!
            #expect(tandem.count >= 60, "tandem: \(tandem.count)")
            #expect(Set(tandem).count == tandem.count)
        }
        #expect(Prompts.quickWriteTopics.count >= 100 && Set(Prompts.quickWriteTopics).count == Prompts.quickWriteTopics.count)
        #expect(Prompts.fluencyStories.count >= 60 && Set(Prompts.fluencyStories).count == Prompts.fluencyStories.count)
        #expect(Prompts.travelMissions.count >= 75 && Set(Prompts.travelMissions).count == Prompts.travelMissions.count)
        // No prompt is a prefix of another, so "already used" can't match the wrong one.
        let all = Prompts.writingPrompts.values.flatMap { $0 }
        for prompt in all {
            #expect(all.filter { $0.hasPrefix(prompt) }.count == 1, "\(prompt)")
        }
    }

    @Test func usedPromptsDontComeBackUntilAllAreUsed() {
        let calendar = TestCalendar.utc
        var used: [String] = []
        // A whole year of daily writing at A2: every prompt once before any repeats.
        for offset in 0..<Prompts.writingA2.count {
            let prompt = Prompts.writing(for: .a2_1, on: TestCalendar.adding(days: offset, to: TestCalendar.day(2026, 10, 26)), used: used, pack: .spanish, calendar: calendar)
            #expect(!used.contains(prompt))
            // Stored prompts can carry a reuse hint after them.
            used.append(prompt + " Try to use something from Language Transfer track 13.")
        }
        #expect(Set(used).count == Prompts.writingA2.count)
        // Once all are used, it starts again rather than failing.
        _ = Prompts.writing(for: .a2_1, on: TestCalendar.day(2027, 6, 1), used: used, pack: .spanish, calendar: calendar)
    }

    @Test func wordTargetsGrowWithLevel() {
        #expect(Prompts.wordTarget(for: .a2_1) == 50...100)
        #expect(Prompts.wordTarget(for: .b1_2) == 120...180)
        #expect(Prompts.wordTarget(for: .b2_2) == 200...300)
    }
}
