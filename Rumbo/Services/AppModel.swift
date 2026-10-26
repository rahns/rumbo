import Foundation
import Network
import Observation
import RumboCore
import SwiftData

/// Connects SwiftData to the RumboCore engine. Views read from it and call its actions.
@MainActor
@Observable
final class AppModel {
    let context: ModelContext
    let calendar = Calendar.current
    private(set) var isOnline = true
    /// Bumped after every change so views depending on fetched data refresh.
    private(set) var revision = 0
    /// A one-off message shown on Today, e.g. a new speaking stage.
    var banner: Banner?

    private let pathMonitor = NWPathMonitor()

    struct Banner: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
    }

    init(context: ModelContext) {
        self.context = context
        pathMonitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in self?.isOnline = path.status == .satisfied }
        }
        pathMonitor.start(queue: DispatchQueue(label: "rumbo.network"))
    }

    // MARK: - Reading

    var profile: LearnerProfile? {
        _ = revision
        return try? context.fetch(FetchDescriptor<LearnerProfile>()).first
    }

    var logs: [ActivityLog] {
        _ = revision
        return (try? context.fetch(FetchDescriptor<ActivityLog>(sortBy: [SortDescriptor(\.date)]))) ?? []
    }

    var history: [ActivityRecord] { logs.map(\.record) }

    var inputHours: Double {
        let minutes = logs.filter { $0.task.countsAsInput }.reduce(0) { $0 + $1.minutes }
        return (profile?.baselineInputHours ?? 0) + Double(minutes) / 60
    }

    var todayPlan: DayPlanRecord? {
        _ = revision
        let start = calendar.startOfDay(for: .now)
        let end = calendar.date(byAdding: .day, value: 1, to: start)!
        let descriptor = FetchDescriptor<DayPlanRecord>(predicate: #Predicate { $0.day >= start && $0.day < end })
        return try? context.fetch(descriptor).first
    }

    func snapshot(for profile: LearnerProfile) -> LearnerSnapshot {
        LearnerSnapshot(
            band: profile.band,
            enabledSources: profile.enabledSources,
            speakingStage: profile.speakingStage,
            languageTransferLastTrack: profile.languageTransferLastTrack,
            languageTransferRepeatPending: profile.languageTransferRepeatPending,
            extraEpisodesWatched: profile.extraEpisodesWatched,
            extraPartsDoneInEpisode: profile.extraPartsDoneInEpisode,
            keepDuolingoInB2: profile.keepDuolingoInB2,
            dueReviewCards: 0,
            travelMode: profile.travelMode,
            isOnline: isOnline,
            dsDifficulty: profile.dsDifficulty
        )
    }

    var streak: StreakCalculator.Status {
        StreakCalculator(weeklyGoalMinutes: profile?.weeklyGoalMinutes ?? 150, calendar: calendar)
            .status(history: history, today: .now)
    }

    var xp: Int {
        let completedCards = (try? context.fetchCount(FetchDescriptor<PlannedTaskRecord>(
            predicate: #Predicate { $0.statusRaw == "done" }
        ))) ?? 0
        _ = revision
        return XP.total(minutes: logs.reduce(0) { $0 + $1.minutes }, completedCards: completedCards, rewrites: 0, gatesPassed: 0)
    }

    var minutesToday: Int {
        logs.filter { calendar.isDateInToday($0.date) }.reduce(0) { $0 + $1.minutes }
    }

    /// A suggested new Dreaming Spanish range, from recent comprehension ratings (§2.6).
    var difficultySuggestion: ClosedRange<Int>? {
        guard let profile else { return nil }
        let range = profile.dsDifficulty
        let ratings = logs
            .filter { $0.difficultyLow == range.lowerBound && $0.difficultyHigh == range.upperBound }
            .compactMap { $0.comprehension.flatMap(ComprehensionTuner.Rating.init(rawValue:)) }
        return ComprehensionTuner.suggestion(for: ratings, current: range)
    }

    // MARK: - Onboarding

    func completeOnboarding(with draft: OnboardingDraft) {
        let profile = LearnerProfile()
        draft.apply(to: profile)
        context.insert(profile)
        save()
        Reminders.schedule(for: profile)
    }

    func reset() {
        LiveActivities.endAll()
        Reminders.cancel()
        try? context.delete(model: PlannedTaskRecord.self)
        try? context.delete(model: DayPlanRecord.self)
        try? context.delete(model: ActivityLog.self)
        try? context.delete(model: WritingEntry.self)
        try? context.delete(model: LearnerProfile.self)
        save()
    }

    // MARK: - Planning

    /// Whether the budget can still be changed (nothing done yet today).
    var canChangeBudget: Bool {
        !(todayPlan?.sortedTasks.contains { $0.status == .done || $0.status == .active } ?? false)
    }

    func makeTodayPlan(budget: Int) {
        guard let profile, canChangeBudget else { return }
        if let existing = todayPlan {
            context.delete(existing)
        }
        let today = Date.now
        let plan = DayPlanner(calendar: calendar).plan(
            budget: budget,
            learner: snapshot(for: profile),
            history: history,
            today: today
        )
        let record = DayPlanRecord(day: calendar.startOfDay(for: today), budgetMinutes: budget, band: profile.band)
        context.insert(record)
        for (index, task) in plan.tasks.enumerated() {
            let taskRecord = PlannedTaskRecord(task: task, order: index, prompt: prompt(for: task.kind, band: profile.band, focus: plan.focus, on: today))
            context.insert(taskRecord)
            taskRecord.plan = record
        }
        save()
    }

    private func prompt(for kind: TaskKind, band: Band, focus: TaskDetail?, on date: Date) -> String {
        var text: String
        switch kind {
        case .writeGuided: text = Prompts.writing(for: band, on: date, calendar: calendar)
        case .tandemText, .tandemVoice, .tandemCall: text = Prompts.tandem(for: band, on: date, calendar: calendar)
        case .writeQuick: text = Prompts.quickWrite(on: date, calendar: calendar)
        case .fluency432: text = Prompts.fluencyStory(on: date, calendar: calendar)
        case .missionTravel: text = Prompts.travelMission(on: date, calendar: calendar)
        default: return ""
        }
        // Output reuses today's structure (R4).
        if kind.strand == .output, kind != .missionTravel, let focus, let reuse = TaskCopy.reuseHint(for: focus) {
            text += " " + reuse
        }
        return text
    }

    // MARK: - Doing tasks

    func start(_ task: PlannedTaskRecord) {
        task.status = .active
        task.startedAt = .now
        save()
        LiveActivities.start(task: task)
    }

    func cancelActive(_ task: PlannedTaskRecord) {
        task.status = .planned
        task.startedAt = nil
        save()
        LiveActivities.endAll()
    }

    func skip(_ task: PlannedTaskRecord) {
        task.status = .skipped
        save()
    }

    struct Completion {
        var minutes: Int
        var comprehension: ComprehensionTuner.Rating?
        var trackRating: SourceProgress.TrackRating?
        var tandemFeeling: String?
    }

    func complete(_ task: PlannedTaskRecord, with completion: Completion) {
        guard let profile else { return }
        let log = ActivityLog(date: .now, task: task.task, minutes: completion.minutes)
        log.comprehension = completion.comprehension?.rawValue
        log.rating = completion.trackRating?.rawValue ?? completion.tandemFeeling
        if task.task == .dsWatch {
            log.difficultyLow = profile.dsDifficultyLow
            log.difficultyHigh = profile.dsDifficultyHigh
        }
        context.insert(log)
        task.status = .done

        var progress = profile.sourceProgress
        progress.record(task.task, trackRating: completion.trackRating)
        profile.sourceProgress = progress

        save()
        LiveActivities.endAll()
        updateSpeakingStage()
    }

    func logBonusInput(minutes: Int) {
        let log = ActivityLog(date: .now, task: .contentWatch, minutes: minutes)
        log.isBonus = true
        context.insert(log)
        save()
    }

    func acceptDifficultySuggestion() {
        guard let profile, let suggestion = difficultySuggestion else { return }
        profile.dsDifficulty = suggestion
        save()
    }

    /// Unlocks voice notes / calls when the evidence supports it (§2.4).
    private func updateSpeakingStage() {
        guard let profile else { return }
        let tandemLogs = logs.filter(\.task.isTandemExchange)
        let textLogs = tandemLogs.filter { $0.task == .tandemText }
        let span = textLogs.first.flatMap { first in
            textLogs.last.map { calendar.dateComponents([.day], from: first.date, to: $0.date).day ?? 0 }
        } ?? 0
        let evidence = SpeakingProgress.Evidence(
            inputHours: inputHours,
            textExchanges: textLogs.count,
            textExchangeSpanDays: span,
            comfortableWithText: ["easy", "ok"].contains(textLogs.last?.rating ?? ""),
            voiceNotes: tandemLogs.filter { $0.task == .tandemVoice }.count
        )
        let stage = SpeakingProgress.stage(for: evidence, current: profile.speakingStage)
        guard stage > profile.speakingStage else { return }
        profile.speakingStage = stage
        save()
        banner = stage == .calls
            ? Banner(title: "Live calls unlocked", message: "Once a week Rumbo will plan a short call with your Tandem partner.")
            : Banner(title: "Voice notes unlocked", message: "Plan a few bullet points, then record a 1–2 minute voice note. Planning first makes speaking easier.")
    }

    func unlockNextSpeakingStage() {
        guard let profile, let next = SpeakingStage(rawValue: profile.speakingStage.rawValue + 1) else { return }
        profile.speakingStage = next
        save()
    }

    func save() {
        try? context.save()
        revision += 1
    }
}
