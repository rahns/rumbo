import Foundation
import Observation
import RumboCore

/// Answers collected during onboarding, applied to a new `LearnerProfile` at the end.
@MainActor
@Observable
final class OnboardingDraft {
    var name = ""
    var goal = "B2"
    /// Set from the weekly goal when the goal step first opens; the two stay linked from then on.
    var targetDate = Date.now
    var targetDateSet = false

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

    var reminderEnabled = true
    var reminderTime = Calendar.current.date(from: DateComponents(hour: 8, minute: 30)) ?? .now
    var weeklyGoalMinutes = 150
    var weekStartsOnSunday = false
    /// Saved to the Keychain when onboarding finishes, not to the profile.
    var geminiKey = ""


    /// Listening hours before Rumbo (Dreaming Spanish's counter, or an estimate).
    var inputHours: Double {
        Double(sources.contains(.dreamingSpanish) ? dreamingHours : otherListeningHours)
    }

    /// Listening before Rumbo as training hours (÷ the listening share), which is what levels are measured in.
    var trainingHours: Double { Band.trainingHours(fromListening: inputHours) }

    var bandByHours: Band { Band.forHours(trainingHours) }

    /// The first time the goal step opens: the date the default weekly goal leads to.
    func prepareGoal() {
        guard !targetDateSet else { return }
        targetDate = GoalPace.arrival(of: GoalEditor.goalBand(for: goal), currentHours: trainingHours,
                                      weeklyMinutes: weeklyGoalMinutes, from: .now)
        targetDateSet = true
    }

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
        return Placement.place(hours: trainingHours, ownBandYes: ownYes, nextBandYes: nextYes, statementsPerBand: CanDo.placementSampleSize)
    }

    func apply(to profile: LearnerProfile) {
        let calendar = Calendar.current
        profile.displayName = name.trimmingCharacters(in: .whitespaces)
        profile.goal = goal
        profile.targetDate = targetDate
        profile.enabledSources = sources
        profile.baselineInputHours = inputHours
        profile.band = placement.band
        profile.dsDifficulty = dreamingDifficultyLow...(dreamingDifficultyLow + LearnerProfile.dreamingRangeWidth)
        profile.languageTransferLastTrack = languageTransferLastTrack
        profile.extraEpisodesWatched = extraEpisodesWatched
        profile.duolingoSection = duolingoSection
        profile.duolingoUnit = duolingoUnit
        profile.reminderEnabled = reminderEnabled
        profile.reminderHour = calendar.component(.hour, from: reminderTime)
        profile.reminderMinute = calendar.component(.minute, from: reminderTime)
        profile.weeklyGoalMinutes = weeklyGoalMinutes
        profile.weekStartsOnSunday = weekStartsOnSunday
    }
}
