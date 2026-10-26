import Foundation
import Observation
import RumboCore

/// Answers collected during onboarding, applied to a new `LearnerProfile` at the end.
@MainActor
@Observable
final class OnboardingDraft {
    var name = ""
    var goal = "B2"
    var hasTargetDate = false
    var targetDate = Calendar.current.date(from: DateComponents(year: 2028, month: 1, day: 1)) ?? .now

    var sources: Set<SourceKind> = Set(SourceKind.allCases)

    var dreamingHours = 150
    var otherListeningHours = 150
    var dreamingDifficultyLow = 40
    var languageTransferLastTrack = 0
    var duolingoSection = 1
    var duolingoUnit = 1
    var extraEpisodesWatched = 0

    /// Answers to the can-do statements, keyed by statement.
    var canDoAnswers: [String: Bool] = [:]

    var habitCue = "After breakfast"
    var reminderEnabled = true
    var reminderTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 30)) ?? .now
    var weeklyGoalMinutes = 150

    static let habitCues = ["After breakfast", "On my commute", "At lunch", "After work", "Before bed"]
    static let weeklyGoals = [60, 100, 150, 210, 300]
    static let dreamingDifficultyWidth = 8

    var inputHours: Double {
        Double(sources.contains(.dreamingSpanish) ? dreamingHours : otherListeningHours)
    }

    var bandByHours: Band { Band.forInputHours(inputHours) }

    /// Statements to show: 5 from the band the hours point to, 5 from the next, interleaved.
    var canDoStatements: [(text: String, isNextBand: Bool)] {
        let sample = CanDo.placementStatements(for: bandByHours)
        var result: [(text: String, isNextBand: Bool)] = []
        for index in 0..<max(sample.own.count, sample.next.count) {
            if index < sample.own.count { result.append((text: sample.own[index], isNextBand: false)) }
            if index < sample.next.count { result.append((text: sample.next[index], isNextBand: true)) }
        }
        return result
    }

    var placement: Placement.Result {
        let statements = canDoStatements
        let ownYes = statements.filter { !$0.isNextBand && canDoAnswers[$0.text] == true }.count
        let nextYes = statements.filter { $0.isNextBand && canDoAnswers[$0.text] == true }.count
        return Placement.place(inputHours: inputHours, ownBandYes: ownYes, nextBandYes: nextYes, statementsPerBand: CanDo.placementSampleSize)
    }

    func apply(to profile: LearnerProfile) {
        let calendar = Calendar.current
        profile.displayName = name.trimmingCharacters(in: .whitespaces)
        profile.goal = goal
        profile.targetDate = hasTargetDate ? targetDate : nil
        profile.enabledSources = sources
        profile.baselineInputHours = inputHours
        profile.band = placement.band
        profile.dsDifficulty = dreamingDifficultyLow...(dreamingDifficultyLow + Self.dreamingDifficultyWidth)
        profile.languageTransferLastTrack = languageTransferLastTrack
        profile.extraEpisodesWatched = extraEpisodesWatched
        profile.duolingoSection = duolingoSection
        profile.duolingoUnit = duolingoUnit
        profile.habitCue = habitCue
        profile.reminderEnabled = reminderEnabled
        profile.reminderHour = calendar.component(.hour, from: reminderTime)
        profile.reminderMinute = calendar.component(.minute, from: reminderTime)
        profile.weeklyGoalMinutes = weeklyGoalMinutes
    }
}
