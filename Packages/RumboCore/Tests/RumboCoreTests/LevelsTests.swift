import Foundation
import Testing
@testable import RumboCore

@Suite struct PlacementTests {
    @Test func hoursDecideTheBandWhenCanDosAgree() {
        let result = Placement.place(inputHours: 154, ownBandYes: 7, nextBandYes: 4)
        #expect(result.band == .a2_1)
        #expect(result.adjustment == 0)
    }

    @Test func strongNextBandAnswersMoveUpOne() {
        let result = Placement.place(inputHours: 154, ownBandYes: 10, nextBandYes: 8)
        #expect(result.band == .a2_2)
        #expect(result.adjustment == 1)
    }

    @Test func weakOwnBandAnswersMoveDownOne() {
        #expect(Placement.place(inputHours: 320, ownBandYes: 4, nextBandYes: 0).band == .a2_2)
    }

    @Test func neverLeavesTheBandRange() {
        #expect(Placement.place(inputHours: 50, ownBandYes: 0, nextBandYes: 0).band == .a2_1)
        #expect(Placement.place(inputHours: 2000, ownBandYes: 10, nextBandYes: 10).band == .b2_2)
    }
}

@Suite struct LevelGateTests {
    let calendar = TestCalendar.utc
    let today = TestCalendar.day(2026, 10, 26)

    @Test func opensAtTheNextThreshold() {
        #expect(!LevelGate.isOpen(band: .a2_1, inputHours: 224, lastFailedAttempt: nil, today: today, calendar: calendar))
        #expect(LevelGate.isOpen(band: .a2_1, inputHours: 225, lastFailedAttempt: nil, today: today, calendar: calendar))
        #expect(!LevelGate.isOpen(band: .b2_2, inputHours: 5000, lastFailedAttempt: nil, today: today, calendar: calendar))
    }

    @Test func reopensFourteenDaysAfterAFail() {
        let failed = TestCalendar.adding(days: -13, to: today)
        #expect(!LevelGate.isOpen(band: .a2_1, inputHours: 300, lastFailedAttempt: failed, today: today, calendar: calendar))
        #expect(LevelGate.isOpen(band: .a2_1, inputHours: 300, lastFailedAttempt: TestCalendar.adding(days: -14, to: today), today: today, calendar: calendar))
    }

    @Test func passMarkIsSevenOfTen() {
        #expect(!LevelGate.passes(yesAnswers: 6))
        #expect(LevelGate.passes(yesAnswers: 7))
    }
}

@Suite struct SpeakingProgressTests {
    let ready = SpeakingProgress.Evidence(inputHours: 250, textExchanges: 8, textExchangeSpanDays: 21, comfortableWithText: true, voiceNotes: 0)

    @Test func voiceNotesNeedHoursExchangesTimeAndComfort() {
        #expect(SpeakingProgress.stage(for: ready, current: .text) == .voiceNotes)
        var evidence = ready
        evidence.inputHours = 249
        #expect(SpeakingProgress.stage(for: evidence, current: .text) == .text)
        evidence = ready
        evidence.textExchangeSpanDays = 20
        #expect(SpeakingProgress.stage(for: evidence, current: .text) == .text)
        evidence = ready
        evidence.comfortableWithText = false
        #expect(SpeakingProgress.stage(for: evidence, current: .text) == .text)
    }

    @Test func callsNeedFourHundredHoursAndSixVoiceNotes() {
        var evidence = ready
        evidence.inputHours = 400
        evidence.voiceNotes = 5
        #expect(SpeakingProgress.stage(for: evidence, current: .voiceNotes) == .voiceNotes)
        evidence.voiceNotes = 6
        #expect(SpeakingProgress.stage(for: evidence, current: .voiceNotes) == .calls)
    }

    @Test func anEarlyUnlockIsKept() {
        let beginner = SpeakingProgress.Evidence(inputHours: 160, textExchanges: 1, textExchangeSpanDays: 0, comfortableWithText: false, voiceNotes: 0)
        #expect(SpeakingProgress.stage(for: beginner, current: .voiceNotes) == .voiceNotes)
    }
}

@Suite struct ComprehensionTunerTests {
    typealias R = ComprehensionTuner.Rating

    @Test func threeEasyRaisesTheRange() {
        #expect(ComprehensionTuner.suggestion(for: [.mostly, .easy, .easy, .easy], current: 40...48) == 45...53)
    }

    @Test func twoLostLowersTheRange() {
        #expect(ComprehensionTuner.suggestion(for: [.lost, .mostly, .lost], current: 40...48) == 35...43)
    }

    @Test func lostWinsOverEasy() {
        #expect(ComprehensionTuner.suggestion(for: [.easy, .easy, .easy, .lost, .lost], current: 40...48) == 35...43)
    }

    @Test func onlyTheLastFiveCount() {
        #expect(ComprehensionTuner.suggestion(for: [.lost, .lost, .mostly, .mostly, .mostly, .mostly, .mostly], current: 40...48) == nil)
    }

    @Test func neverGoesBelowZero() {
        #expect(ComprehensionTuner.suggestion(for: [.lost, .lost], current: 2...10) == 0...8)
    }
}
