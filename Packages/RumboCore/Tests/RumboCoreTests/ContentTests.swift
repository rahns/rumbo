import Foundation
import Testing
@testable import RumboCore

@Suite struct SourceProgressTests {
    @Test func solidTrackMovesOn() {
        var progress = SourceProgress(languageTransferLastTrack: 12)
        progress.record(.ltTrack, trackRating: .solid)
        #expect(progress.languageTransferLastTrack == 13)
        #expect(!progress.languageTransferRepeatPending)
    }

    @Test func shakyTrackIsRepeatedOnceThenMovesOn() {
        var progress = SourceProgress(languageTransferLastTrack: 12)
        progress.record(.ltTrack, trackRating: .shaky)
        #expect(progress.languageTransferLastTrack == 13)
        #expect(progress.languageTransferRepeatPending, "next session repeats track 13")

        progress.record(.ltTrack, trackRating: .shaky)
        #expect(progress.languageTransferLastTrack == 13)
        #expect(!progress.languageTransferRepeatPending, "only one repeat")

        progress.record(.ltTrack, trackRating: .solid)
        #expect(progress.languageTransferLastTrack == 14)
    }

    @Test func plannerShowsTheRepeatedTrack() {
        var progress = SourceProgress(languageTransferLastTrack: 12)
        progress.record(.ltTrack, trackRating: .shaky)
        let learner = LearnerSnapshot(band: .a2_1, languageTransferLastTrack: progress.languageTransferLastTrack,
                                      languageTransferRepeatPending: progress.languageTransferRepeatPending)
        let plan = DayPlanner(calendar: TestCalendar.utc).plan(budget: 60, learner: learner, history: [], today: TestCalendar.day(2026, 10, 26))
        #expect(plan.task(.ltTrack)?.detail == .languageTransferTrack(13))
    }

    @Test func twoIntensivePartsFinishAnEpisode() {
        var progress = SourceProgress(extraEpisodesWatched: 1)
        progress.record(.extraIntensive)
        #expect(progress.extraEpisodesWatched == 1 && progress.extraPartsDoneInEpisode == 1)
        progress.record(.extraIntensive)
        #expect(progress.extraEpisodesWatched == 2 && progress.extraPartsDoneInEpisode == 0)
    }

    @Test func undoRestoresOnlyThatTasksCourse() {
        let start = SourceProgress(languageTransferLastTrack: 12, extraEpisodesWatched: 1, extraPartsDoneInEpisode: 1)
        var progress = start
        progress.record(.ltTrack, trackRating: .solid)
        progress.record(.extraIntensive)
        let afterExtra = progress
        progress.undo(.ltTrack, before: start)
        #expect(progress.languageTransferLastTrack == 12)
        #expect(progress.extraEpisodesWatched == afterExtra.extraEpisodesWatched, "Extra progress is kept")
        progress.undo(.extraIntensive, before: start)
        #expect(progress == start)
    }

    @Test func coursesStopAtTheirLastEpisodeAndTrack() {
        var progress = SourceProgress(languageTransferLastTrack: 90, extraEpisodesWatched: 13)
        progress.record(.ltTrack, trackRating: .solid)
        progress.record(.extraExtensive)
        #expect(progress.languageTransferLastTrack == 90 && progress.extraEpisodesWatched == 13)
    }
}

@Suite struct CanDoTests {
    @Test(arguments: Band.allCases)
    func everyBandHasTenDistinctStatements(band: Band) {
        let statements = CanDo.statements(for: band)
        #expect(statements.count == CanDo.perBand)
        #expect(Set(statements).count == statements.count)
    }

    @Test func placementSampleIsFivePlusFive() {
        let sample = CanDo.placementStatements(for: .a2_1)
        #expect(sample.own.count == 5 && sample.next.count == 5)
        #expect(CanDo.placementStatements(for: .b2_2).next.isEmpty)
    }

    @Test func placementWorksWithTheFivePlusFiveSample() {
        #expect(Placement.place(hours: 280, ownBandYes: 5, nextBandYes: 4, statementsPerBand: 5).band == .a2_2)
        #expect(Placement.place(hours: 280, ownBandYes: 5, nextBandYes: 3, statementsPerBand: 5).band == .a2_1)
        #expect(Placement.place(hours: 582, ownBandYes: 2, nextBandYes: 0, statementsPerBand: 5).band == .a2_2)
    }
}

@Suite struct PromptTests {
    @Test func sameDaySamePromptAndDaysVary() {
        let calendar = TestCalendar.utc
        let day = TestCalendar.day(2026, 10, 26)
        #expect(Prompts.writing(for: .a2_1, on: day, calendar: calendar) == Prompts.writing(for: .a2_2, on: day, calendar: calendar))
        let week = (0..<7).map { Prompts.writing(for: .a2_1, on: TestCalendar.adding(days: $0, to: day), calendar: calendar) }
        #expect(Set(week).count == 7)
    }

    @Test func wordTargetsGrowWithLevel() {
        #expect(Prompts.wordTarget(for: .a2_1) == 50...100)
        #expect(Prompts.wordTarget(for: .b1_2) == 120...180)
        #expect(Prompts.wordTarget(for: .b2_2) == 200...300)
    }
}
