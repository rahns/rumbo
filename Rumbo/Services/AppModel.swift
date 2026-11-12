import Foundation
import Network
import Observation
import RumboCore
import SwiftData
import WidgetKit

/// Connects SwiftData to the RumboCore engine. Views read from it and call its actions.
@MainActor
@Observable
final class AppModel {
    let context: ModelContext
    /// The user's calendar, with the week starting on the day they chose (Monday by default).
    var calendar: Calendar {
        var calendar = Calendar.current
        calendar.firstWeekday = weekStartsOnSunday ? 1 : 2
        return calendar
    }

    /// Mirrors the profile setting; read directly so `calendar` doesn't fetch the profile each time.
    private(set) var weekStartsOnSunday = false

    func setWeekStartsOnSunday(_ value: Bool) {
        profile?.weekStartsOnSunday = value
        weekStartsOnSunday = value
        save()
    }
    private(set) var isOnline = true

    /// The language being learned now. Each language has its own profile, history, plan and streak; every
    /// fetch below is for this language only. See docs/09-multi-language.md.
    private(set) var languageCode = ActiveLanguage.code
    var pack: LanguagePack { LanguagePack.pack(for: languageCode) }

    /// Switches to another language (one with a profile, or a new one about to be onboarded).
    func setLanguage(_ code: String) {
        LiveActivities.endAll()
        ActiveLanguage.set(code)
        languageCode = ActiveLanguage.code
        selectedPlanDay = nil
        weekStartsOnSunday = profile?.weekStartsOnSunday ?? false
        catalog = ContentLibrary.load(pack)
        revision += 1
        if profile != nil {
            bringProfileUpToDate()
            refreshReminders()
        }
        publishWidgets()
    }

    /// Saves a new record as belonging to the language being learned.
    private func insert<Record: PersistentModel & LanguageTagged>(_ record: Record) {
        record.languageCode = languageCode
        context.insert(record)
    }
    /// Bumped after every change so views depending on fetched data refresh.
    private(set) var revision = 0
    /// A one-off message shown on Today, e.g. a new speaking stage.
    var banner: Banner?
    /// Bumped on every completed task; Pico loops and cards celebrate when it changes.
    private(set) var celebrations = 0
    /// Bumped on bigger moments (all of today done, level up) for confetti.
    private(set) var confettiBursts = 0

    // One-off moments (docs/03-experience.md §3.5); views animate when these change.
    struct TimeGain: Equatable {
        let id: Int
        let minutes: Int
    }
    /// The minutes just logged, for the "+22 min" fly-up into the training-hours badge.
    private(set) var timeGain: TimeGain?
    /// Bumped the moment this week's minutes pass the weekly goal (at most once a week).
    private(set) var goalReachedBursts = 0
    struct StreakMilestone: Equatable {
        let id = UUID()
        let days: Int
    }
    private(set) var streakMilestone: StreakMilestone?
    static let streakMilestones: Set<Int> = [7, 30, 100, 365]

    private let pathMonitor = NWPathMonitor()
    /// Library suggestions; the bundled list, replaced by a newer download when there is one.
    private(set) var catalog = ContentLibrary.load(ActiveLanguage.pack)

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
        // If the remembered language has no profile but another does (a restored phone, say), use that one.
        if profile == nil, let other = profiles.first {
            ActiveLanguage.set(other.languageCode)
            languageCode = ActiveLanguage.code
            catalog = ContentLibrary.load(pack)
        }
        weekStartsOnSunday = profile?.weekStartsOnSunday ?? false
        bringProfileUpToDate()
        // No task screen is open at launch, so any timer still showing is left over from a closed app.
        LiveActivities.endAll()
        publishWidgets()
    }

    // MARK: - Reading

    /// Every language's profile, oldest first.
    var profiles: [LearnerProfile] {
        _ = revision
        return (try? context.fetch(FetchDescriptor<LearnerProfile>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
    }

    /// The profile for the language being learned; nil until it has been onboarded.
    var profile: LearnerProfile? {
        let code = languageCode
        return profiles.first { $0.languageCode == code }
    }

    var logs: [ActivityLog] {
        _ = revision
        let code = languageCode
        return (try? context.fetch(FetchDescriptor<ActivityLog>(predicate: #Predicate { $0.languageCode == code }, sortBy: [SortDescriptor(\.date)]))) ?? []
    }

    var history: [ActivityRecord] { logs.map(\.record) }

    /// Training hours toward levels (docs/02-learning-engine.md §2.1): every logged minute, plus listening
    /// done before Rumbo converted at the plan's listening share (150 h of Dreaming Spanish ≈ 273 h).
    var trainingHours: Double {
        let minutes = logs.reduce(0) { $0 + $1.minutes }
        return Band.trainingHours(fromListening: profile?.baselineInputHours ?? 0) + Double(minutes) / 60
    }

    /// Listening hours only (before Rumbo plus logged listening): for speaking-stage unlocks and the Dreaming Spanish row.
    var listeningHours: Double {
        let minutes = logs.filter { $0.task.countsAsInput }.reduce(0) { $0 + $1.minutes }
        return (profile?.baselineInputHours ?? 0) + Double(minutes) / 60
    }

    /// The day Today is showing. Normally today; a later day only to revisit a day finished early in
    /// an older version (working ahead has been replaced by "Keep going" extras).
    var selectedPlanDay: Date?

    var planDay: Date {
        let today = calendar.startOfDay(for: .now)
        guard let selected = selectedPlanDay.map({ calendar.startOfDay(for: $0) }), selected > today else { return today }
        return selected
    }

    var isWorkingAhead: Bool { planDay > calendar.startOfDay(for: .now) }

    /// Every day's plan, oldest first. `day` is the start of the calendar day the plan is for.
    var sessions: [DayPlanRecord] {
        _ = revision
        let code = languageCode
        return (try? context.fetch(FetchDescriptor<DayPlanRecord>(predicate: #Predicate { $0.languageCode == code }, sortBy: [SortDescriptor(\.day)]))) ?? []
    }

    func session(for day: Date) -> DayPlanRecord? {
        sessions.last { calendar.isDate($0.day, inSameDayAs: day) }
    }

    /// The plan Today shows: the one for `planDay`.
    var todayPlan: DayPlanRecord? {
        session(for: planDay)
    }

    func showToday() {
        selectedPlanDay = nil
    }

    func snapshot(for profile: LearnerProfile) -> LearnerSnapshot {
        LearnerSnapshot(
            band: profile.band,
            enabledSources: profile.enabledSources,
            speakingStage: profile.speakingStage,
            courseLastTrack: profile.languageTransferLastTrack,
            courseRepeatPending: profile.languageTransferRepeatPending,
            seriesEpisodesWatched: profile.extraEpisodesWatched,
            seriesPartsDone: profile.extraPartsDoneInEpisode,
            keepDrillAppLate: profile.keepDuolingoInB2,
            dueReviewCards: dueCards.count,
            travelMode: profile.travelMode,
            isOnline: isOnline,
            gradedDifficulty: profile.dsDifficulty,
            alwaysIncludeDrillApp: profile.alwaysIncludeDuolingo,
            lessons: profile.lessonSchedule,
            balance: profile.strandBalance,
            pack: profile.pack
        )
    }

    var streak: StreakCalculator.Status {
        StreakCalculator(weeklyGoalMinutes: profile?.weeklyGoalMinutes ?? 150, calendar: calendar)
            .status(history: history, today: .now)
    }

    /// Today's lesson length, if today is a lesson day (Settings → Lessons).
    var todaysLessonMinutes: Int? {
        profile?.lessonSchedule.lesson(on: .now, calendar: calendar)?.minutes
    }

    /// The time chips for today: longer ones on a lesson day, since the lesson is part of the day's time.
    var budgetChoices: [Int] { DayPlanner.budgetChoices(lessonMinutes: todaysLessonMinutes) }

    /// Which budget keeps the learner on track for this week's goal.
    var budgetAdvice: BudgetAdvisor.Advice {
        BudgetAdvisor.advice(weeklyGoal: profile?.weeklyGoalMinutes ?? 150, minutesThisWeek: streak.minutesThisWeek, today: .now,
                             lessons: profile?.lessonSchedule ?? LessonSchedule(), calendar: calendar)
    }

    /// Dreaming Spanish sessions with the level watched, for the Progress chart.
    var watchedLevels: [WatchedLevel.Session] { logs.compactMap(\.watchedLevel) }

    var minutesToday: Int {
        logs.filter { calendar.isDateInToday($0.date) }.reduce(0) { $0 + $1.minutes }
    }

    /// A suggested new Dreaming Spanish range, from recent comprehension ratings (§2.6).
    var difficultySuggestion: ClosedRange<Int>? {
        // Only for a graded library with a difficulty scale.
        guard let profile, profile.pack.graded != nil else { return nil }
        let range = profile.dsDifficulty
        let ratings = logs
            .filter { $0.difficultyLow == range.lowerBound && $0.difficultyHigh == range.upperBound }
            .compactMap { $0.comprehension.flatMap(ComprehensionTuner.Rating.init(rawValue:)) }
        return ComprehensionTuner.suggestion(for: ratings, current: range)
    }

    // MARK: - Onboarding

    func completeOnboarding(with draft: OnboardingDraft) {
        // The language chosen in onboarding becomes the one being learned.
        ActiveLanguage.set(draft.languageCode)
        languageCode = ActiveLanguage.code
        catalog = ContentLibrary.load(pack)
        let profile = LearnerProfile()
        draft.apply(to: profile)
        insert(profile)
        weekStartsOnSunday = profile.weekStartsOnSunday
        save()
        refreshReminders()
    }

    /// Start over: removes everything for the language being learned. Another language's profile, if there
    /// is one, becomes the active one; otherwise onboarding starts again.
    func reset() {
        LiveActivities.endAll()
        Reminders.cancel()
        deleteActiveLanguage()
        weekStartsOnSunday = false
        try? context.save()
        if let other = profiles.first {
            setLanguage(other.languageCode)
        }
        save()
    }

    private func deleteActiveLanguage() {
        let code = languageCode
        // One by one (not a batch delete), so each plan takes its tasks with it.
        sessions.forEach(context.delete)
        logs.forEach(context.delete)
        allCards.forEach(context.delete)
        ((try? context.fetch(FetchDescriptor<WritingEntry>(predicate: #Predicate { $0.languageCode == code }))) ?? []).forEach(context.delete)
        profiles.filter { $0.languageCode == code }.forEach(context.delete)
    }

    private func deleteAll() {
        try? context.delete(model: PlannedTaskRecord.self)
        try? context.delete(model: DayPlanRecord.self)
        try? context.delete(model: ActivityLog.self)
        try? context.delete(model: WritingEntry.self)
        try? context.delete(model: ReviewCard.self)
        try? context.delete(model: LearnerProfile.self)
    }

    // MARK: - Backup

    func makeBackup() throws -> BackupDocument {
        guard let profile else { throw BackupError.unreadable }
        // A backup holds every language, not only the one being learned.
        let everyLog = (try? context.fetch(FetchDescriptor<ActivityLog>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let writing = (try? context.fetch(FetchDescriptor<WritingEntry>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let cards = (try? context.fetch(FetchDescriptor<ReviewCard>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
        let file = BackupFile(
            version: BackupFile.currentVersion,
            exportedAt: .now,
            appVersion: DiagnosticsModel.appVersion,
            profile: BackupFile.ProfileData(profile),
            logs: everyLog.map(BackupFile.LogData.init),
            writing: writing.map {
                BackupFile.WritingData(date: $0.date, task: $0.taskRaw, prompt: $0.prompt, text: $0.text,
                                       rewrite: $0.rewrite, feedback: $0.feedbackJSON, id: $0.id, language: $0.languageCode)
            },
            cards: cards.map(BackupFile.CardData.init),
            profiles: profiles.map(BackupFile.ProfileData.init),
            activeLanguage: languageCode,
            gemini: BackupFile.GeminiData(apiKey: GeminiKey.current, thinkingLevel: GeminiKey.thinkingLevel.rawValue,
                                          groqAPIKey: GroqKey.current, defaultChecker: WritingCheckers.defaultChecker.rawValue)
        )
        return BackupDocument(data: try BackupFile.encoder().encode(file))
    }

    /// Replaces everything with the backup's contents. The file is fully decoded before anything is deleted.
    func restore(from data: Data) throws {
        let file: BackupFile
        do {
            file = try BackupFile.decode(data)
        } catch let error as BackupError {
            throw error
        } catch {
            throw BackupError.unreadable
        }
        LiveActivities.endAll()
        deleteAll()
        // A backup without Gemini settings (older, or saved before a key was added) leaves the phone's as they are.
        if let key = file.gemini?.apiKey, !key.isEmpty { GeminiKey.save(key) }
        if let level = file.gemini?.thinkingLevel.flatMap(Gemini.ThinkingLevel.init(rawValue:)) { GeminiKey.thinkingLevel = level }
        if let checker = file.gemini?.defaultChecker.flatMap(WritingChecker.init(rawValue:)) { WritingCheckers.defaultChecker = checker }
        if let key = file.gemini?.groqAPIKey, !key.isEmpty { GroqKey.save(key) }
        // Version 2 lists every language's profile; version 1 has the one (Spanish) profile.
        for data in file.profiles ?? [file.profile] {
            context.insert(data.makeProfile())
        }
        ActiveLanguage.set(file.activeLanguage ?? file.profile.language ?? LanguagePack.defaultCode)
        languageCode = ActiveLanguage.code
        catalog = ContentLibrary.load(pack)
        for log in file.logs {
            context.insert(log.makeLog())
        }
        for entry in file.writing {
            let restored = WritingEntry(date: entry.date, task: TaskKind(rawValue: entry.task) ?? .writeGuided, prompt: entry.prompt, text: entry.text)
            restored.rewrite = entry.rewrite ?? ""
            restored.feedbackJSON = entry.feedback
            if let id = entry.id { restored.id = id }
            restored.languageCode = entry.language ?? LanguagePack.defaultCode
            context.insert(restored)
        }
        for card in file.cards ?? [] {
            context.insert(card.makeCard())
        }
        try? context.save()
        weekStartsOnSunday = profile?.weekStartsOnSunday ?? false
        save()
        bringProfileUpToDate()
        refreshReminders()
    }

    // MARK: - Planning

    /// Whether the budget can still be changed (nothing done yet today).
    var canChangeBudget: Bool {
        !(todayPlan?.hasStarted ?? false)
    }

    func makeTodayPlan(budget: Int) {
        guard let profile, canChangeBudget else { return }
        if let existing = todayPlan {
            context.delete(existing)
        }
        // Working ahead plans for that later day, so everything done up to now counts toward the balance.
        let today = planDay
        let plan = DayPlanner(calendar: calendar).plan(
            budget: budget,
            learner: snapshot(for: profile),
            history: history,
            today: today
        )
        let record = DayPlanRecord(day: today, budgetMinutes: budget, band: profile.band)
        insert(record)
        for (index, task) in plan.tasks.enumerated() {
            let taskRecord = PlannedTaskRecord(task: task, order: index, prompt: prompt(for: task.kind, band: profile.band, focus: plan.focus, on: today))
            context.insert(taskRecord)
            taskRecord.plan = record
        }
        save()
    }

    /// Every prompt given in a saved plan (done, skipped or not), so new plans pick fresh ones.
    private var usedPrompts: [String] {
        sessions.flatMap(\.sortedTasks).map(\.prompt).filter { !$0.isEmpty }
    }

    private func prompt(for kind: TaskKind, band: Band, focus: TaskDetail?, on date: Date) -> String {
        var text: String
        switch kind {
        // Prompts already given in earlier plans are skipped until the list is used up.
        case .writeGuided: text = Prompts.writing(for: band, on: date, used: usedPrompts, pack: pack, calendar: calendar)
        case .exchangeText, .exchangeVoice, .exchangeCall: text = Prompts.exchange(for: band, on: date, used: usedPrompts, pack: pack, calendar: calendar)
        case .writeQuick: text = Prompts.quickWrite(on: date, used: usedPrompts, pack: pack, calendar: calendar)
        case .fluency432: text = Prompts.fluencyStory(on: date, used: usedPrompts, pack: pack, calendar: calendar)
        case .missionTravel: text = Prompts.travelMission(on: date, used: usedPrompts, pack: pack, calendar: calendar)
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
        // A lesson happens outside the app: opening it just shows the log form. It isn't "started", so the plan
        // isn't locked and it can still be skipped.
        guard !task.task.isLesson else { return }
        task.status = .active
        task.startedAt = .now
        task.pausedAt = nil
        task.pausedSeconds = 0
        save()
        LiveActivities.start(task: task)
    }

    /// Back into a task that was already started: the timer reappears with its elapsed time.
    func resumeSession(_ task: PlannedTaskRecord) {
        LiveActivities.start(task: task)
    }

    /// Leaving the task screen without logging: the task stays started, but its timer goes away.
    func leaveSession() {
        LiveActivities.endAll()
    }

    func cancelActive(_ task: PlannedTaskRecord) {
        task.status = .planned
        task.startedAt = nil
        task.pausedAt = nil
        task.pausedSeconds = 0
        save()
        LiveActivities.endAll()
    }

    /// The task currently being timed, if any.
    var activeTask: PlannedTaskRecord? {
        sessions.reversed().lazy.flatMap(\.sortedTasks).first { $0.status == .active }
    }

    /// Pause / resume, from the task screen or the Live Activity's button.
    func togglePause() {
        guard let task = activeTask else { return }
        if let pausedAt = task.pausedAt {
            task.pausedSeconds += Date.now.timeIntervalSince(pausedAt)
            task.pausedAt = nil
        } else {
            task.pausedAt = .now
        }
        save()
        LiveActivities.update(task: task)
    }

    /// Set by the Live Activity's Done button (rumbo://finish): opens the log screen for the active task.
    var finishingTask: PlannedTaskRecord?

    /// Bumped to ask the app to show Today (from a widget tap).
    private(set) var todayRequests = 0

    func handle(_ url: URL) {
        guard url.scheme == "rumbo" else { return }
        switch url.host {
        case "finish":
            finishingTask = activeTask
        case "plan":
            // rumbo://plan?minutes=30 picks that time for today if there's no plan yet, then opens Today.
            showToday()
            let minutes = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "minutes" }?.value.flatMap(Int.init)
            if todayPlan == nil, let minutes, budgetChoices.contains(minutes) {
                makeTodayPlan(budget: minutes)
            }
            todayRequests += 1
        case "today":
            showToday()
            todayRequests += 1
        default:
            break
        }
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
        var writing: String?
        var feedback: CorrectionService.Result?
        var rewrite: String?
        var duolingoPosition: (section: Int, unit: Int)?
        /// After a Language Transfer task: the track the learner is up to now (91 = course finished).
        var languageTransferNextTrack: Int? = nil
        /// After a lesson: what kind it turned out to be, if different from the schedule (this lesson only).
        var lessonType: LessonType? = nil
        /// After a Dreaming Spanish task: the difficulty watched (0–100).
        var levelWatched: Int? = nil
    }

    func complete(_ task: PlannedTaskRecord, with completion: Completion) {
        guard let profile else { return }
        let before = streak
        // A one-off change of lesson type is logged (and shown) as that type.
        if let lessonType = completion.lessonType, task.task.isLesson { task.taskRaw = TaskKind.lesson(for: lessonType).rawValue }
        // An all-in-one lesson is logged as three equal parts, one per strand it covers.
        let parts = task.task == .lessonMixed ? LessonType.split(minutes: completion.minutes) : []
        let loggedAt = Date.now
        let log = ActivityLog(date: loggedAt, task: parts.first?.kind ?? task.task, minutes: parts.first?.minutes ?? completion.minutes)
        log.comprehension = completion.comprehension?.rawValue
        log.rating = completion.trackRating?.rawValue ?? completion.tandemFeeling
        if task.task == .gradedWatch {
            log.difficultyLow = profile.dsDifficultyLow
            log.difficultyHigh = profile.dsDifficultyHigh
        }
        if task.task == .gradedWatch {
            log.levelWatched = completion.levelWatched
        }
        insert(log)
        task.status = .done
        task.logID = log.id
        task.splitLogIDs = parts.dropFirst().map { part in
            let extra = ActivityLog(date: loggedAt, task: part.kind, minutes: part.minutes)
            insert(extra)
            return extra.id
        }

        if let text = completion.writing?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            let entry = WritingEntry(date: .now, task: task.task, prompt: task.prompt, text: text)
            entry.feedbackJSON = completion.feedback.flatMap { try? JSONEncoder().encode($0) }
            entry.rewrite = completion.rewrite?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            insert(entry)
            task.writingID = entry.id
            task.draftText = ""
            task.draftRewrite = ""
            task.draftFeedback = nil
            // Every corrected error becomes a mistake-deck card (R7, R11).
            for correction in completion.feedback?.corrections ?? [] {
                let content = Mistakes.card(from: text, correction: correction)
                let card = ReviewCard(front: content.front, back: content.back, explanation: content.explanation, origin: "writing")
                card.writingID = entry.id
                insert(card)
            }
        }

        task.progressBefore = try? JSONEncoder().encode(profile.sourceProgress)
        var progress = profile.sourceProgress
        progress.record(task.task, trackRating: completion.trackRating, pack: profile.pack)
        if let next = completion.languageTransferNextTrack {
            // The learner says where they are, which beats the automatic +1 (and replaces "shaky, repeat it").
            progress.courseLastTrack = min(max(next - 1, 0), profile.pack.course?.tracks ?? 0)
            progress.courseRepeatPending = false
        }
        profile.sourceProgress = progress

        if let position = completion.duolingoPosition {
            task.duolingoSectionBefore = profile.duolingoSection
            task.duolingoUnitBefore = profile.duolingoUnit
            profile.duolingoSection = position.section
            profile.duolingoUnit = position.unit
        }

        save()
        LiveActivities.endAll()
        updateSpeakingStage()
        refreshReminders()
        celebrations += 1
        celebrateProgress(since: before, minutes: completion.minutes)
        // Confetti when this task finishes the plan (extras come after, so they don't set it off again).
        if !task.isExtra, todayPlan?.isComplete == true {
            confettiBursts += 1
        }
    }

    /// Puts a done or skipped task back to planned, removing its log and anything it moved forward.
    func undo(_ task: PlannedTaskRecord) {
        guard let profile else { return }
        if task.status == .done {
            for id in task.allLogIDs {
                if let log = logs.first(where: { $0.id == id }) { context.delete(log) }
            }
            if let id = task.writingID {
                if let entry = try? context.fetch(FetchDescriptor<WritingEntry>(predicate: #Predicate { $0.id == id })).first {
                    // The text goes back to being the task's draft, so undo never throws writing away.
                    task.draftText = entry.text
                    task.draftRewrite = entry.rewrite
                    task.draftFeedback = entry.feedbackJSON
                    context.delete(entry)
                }
                for card in (try? context.fetch(FetchDescriptor<ReviewCard>(predicate: #Predicate { $0.writingID == id }))) ?? [] {
                    context.delete(card)
                }
            }
            if let data = task.progressBefore, let before = try? JSONDecoder().decode(SourceProgress.self, from: data) {
                var progress = profile.sourceProgress
                progress.undo(task.task, before: before)
                profile.sourceProgress = progress
            }
            if let section = task.duolingoSectionBefore, let unit = task.duolingoUnitBefore {
                profile.duolingoSection = section
                profile.duolingoUnit = unit
            }
            // Mistake review: the cards go back to how they were, so they're due again (and the task is offered again).
            if let data = task.reviewsBefore, let before = try? JSONDecoder().decode([String: FSRS.Card].self, from: data) {
                for card in allCards {
                    if let schedule = before[card.id.uuidString] { card.schedule = schedule }
                }
            }
        }
        task.status = .planned
        task.startedAt = nil
        task.logID = nil
        task.splitLogIDs = []
        task.writingID = nil
        task.progressBefore = nil
        task.duolingoSectionBefore = nil
        task.duolingoUnitBefore = nil
        task.reviewsBefore = nil
        save()
        refreshReminders()
    }

    // MARK: - Keep going

    /// Once today's plan is complete: every other task the learner can do, most-behind strand first.
    /// An extra that was undone or stopped without logging (back to planned) is offered again.
    var keepGoingOptions: [PlannedTask] {
        guard let profile, let plan = todayPlan, plan.isComplete else { return [] }
        let taken = Set(plan.sortedTasks.filter { !$0.isExtra || $0.status != .planned }.map(\.task))
        return DayPlanner(calendar: calendar).extraTasks(learner: snapshot(for: profile), history: history, today: plan.day, excluding: taken)
    }

    /// Extras started or done today, in the order they were added.
    var startedExtras: [PlannedTaskRecord] {
        todayPlan?.extraTasks.filter { $0.status != .planned } ?? []
    }

    /// Adds a "Keep going" task to today's plan as an extra and starts it.
    func startExtra(_ option: PlannedTask) -> PlannedTaskRecord? {
        guard let profile, let plan = todayPlan else { return nil }
        // Reuse one that was undone or stopped earlier rather than adding a duplicate.
        if let existing = plan.extraTasks.first(where: { $0.task == option.kind && $0.status == .planned }) {
            start(existing)
            return existing
        }
        let order = (plan.sortedTasks.map(\.order).max() ?? -1) + 1
        let record = PlannedTaskRecord(task: option, order: order, prompt: prompt(for: option.kind, band: profile.band, focus: nil, on: plan.day))
        record.isExtra = true
        context.insert(record)
        record.plan = plan
        start(record)
        return record
    }

    /// "Log other": practice outside the plan, in any strand (listening is logged as `contentWatch`).
    /// Practice outside the plan. A nil strand is all-in-one: split evenly across speaking & writing,
    /// listening and grammar & vocab, as logs sharing one timestamp so Today shows (and undoes) them as one.
    func logOther(minutes: Int, strand: Strand?) {
        let before = streak
        let date = Date.now
        let parts = strand.map { [(kind: TaskKind.other(for: $0), minutes: minutes)] } ?? LessonType.splitOther(minutes: minutes)
        for part in parts {
            let log = ActivityLog(date: date, task: part.kind, minutes: part.minutes)
            log.isBonus = true
            insert(log)
        }
        save()
        refreshReminders()
        celebrateProgress(since: before, minutes: minutes)
    }

    /// Profiles from older versions (or older backups): a 5-point Dreaming range, and a target date that
    /// matches the weekly goal (the two are linked now; see Settings → Goal).
    func bringProfileUpToDate() {
        guard let profile else { return }
        var changed = false
        if profile.dsDifficultyHigh - profile.dsDifficultyLow != profile.gradedWindowWidth {
            profile.dsDifficultyHigh = profile.dsDifficultyLow + profile.gradedWindowWidth
            changed = true
        }
        if profile.targetDate == nil {
            profile.targetDate = GoalPace.arrival(atHours: profile.goalHours, currentHours: trainingHours,
                                                  weeklyMinutes: profile.weeklyGoalMinutes, from: .now)
            changed = true
        } else if let date = profile.targetDate, Self.once("goal-model-training-hours") {
            // Levels moved to training hours: keep the chosen date and work out the weekly goal again.
            profile.weeklyGoalMinutes = GoalPace.weeklyMinutes(toReachHours: profile.goalHours, by: date, currentHours: trainingHours, from: .now)
            changed = true
        }
        if changed { try? context.save() }
    }

    // MARK: - Moments

    /// After logging: the minutes fly-up, and the weekly-goal and streak-milestone moments when they're crossed.
    private func celebrateProgress(since before: StreakCalculator.Status, minutes: Int) {
        timeGain = TimeGain(id: (timeGain?.id ?? 0) + 1, minutes: minutes)
        let after = streak
        let goal = profile?.weeklyGoalMinutes ?? 150
        let week = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? calendar.startOfDay(for: .now)
        if before.minutesThisWeek < goal, after.minutesThisWeek >= goal, Self.once("goal-\(Self.dayKey(week))") {
            goalReachedBursts += 1
        }
        if after.streak > before.streak, Self.streakMilestones.contains(after.streak),
           Self.once("streak-\(after.streak)-\(Self.dayKey(calendar.startOfDay(for: .now)))") {
            streakMilestone = StreakMilestone(days: after.streak)
            banner = Banner(title: "🔥 " + pack.phrases.streak(days: after.streak), message: streakMessage(after.streak))
        }
    }

    /// True once per unit: when it's newly complete (its last day is today or yesterday), for the stamp moment.
    func takeUnitCompletion(_ unit: PathUnit) -> Bool {
        guard unit.isComplete, let last = unit.nodes.last?.date,
              let yesterday = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: .now)),
              last >= yesterday else { return false }
        return Self.once("unit-\(Self.dayKey(last))")
    }

    /// A freeze earned in the last week, not shown yet. Marks it shown.
    func takeUnseenFreezeEarned() -> StreakCalculator.EarnedFreeze? {
        guard let earned = streak.freezesEarned.last,
              let weekAgo = calendar.date(byAdding: .day, value: -7, to: calendar.startOfDay(for: .now)),
              earned.day >= weekAgo, Self.once("freeze-earned-\(Self.dayKey(earned.day))") else { return nil }
        return earned
    }

    /// A day a streak freeze saved, not shown yet. Marks it shown.
    func takeUnseenFreeze() -> Date? {
        guard let day = streak.lastFreezeUsed, Self.once("freeze-\(Self.dayKey(day))") else { return nil }
        return day
    }

    private func streakMessage(_ days: Int) -> String {
        switch days {
        case 7: "A whole week, every day. Pico is impressed."
        case 30: "A month of \(pack.name), every single day. That's a real habit now."
        case 100: "100 days. Most people never get here. \(pack.phrases.amazing)"
        default: "A full year of \(pack.name), every day. Pico has no words. (In any language.)"
        }
    }

    /// True the first time it's called for `key` on this device.
    private static func once(_ key: String) -> Bool {
        let defaults = UserDefaults.standard
        // Moments are per language; Spanish keeps the plain keys it has always had.
        let key = ActiveLanguage.code == LanguagePack.defaultCode ? key : "\(ActiveLanguage.code).\(key)"
        var seen = Set(defaults.stringArray(forKey: "moments.seen") ?? [])
        guard seen.insert(key).inserted else { return false }
        defaults.set(Array(seen), forKey: "moments.seen")
        return true
    }

    private static func dayKey(_ date: Date) -> String {
        date.formatted(.iso8601.year().month().day())
    }

    /// Reschedules the daily reminder and the evening nudges (skipping today's once it's practised).
    func refreshReminders() {
        guard let profile else { return }
        let calculator = StreakCalculator(weeklyGoalMinutes: profile.weeklyGoalMinutes, calendar: calendar)
        let history = history
        Reminders.refresh(for: profile, practisedToday: minutesToday >= StreakCalculator.minutesForStreakDay, calendar: calendar) { day in
            // If nothing more is logged before `day`, did a freeze just cover the day before?
            let status = calculator.status(history: history, today: day)
            guard let used = status.lastFreezeUsed, let yesterday = self.calendar.date(byAdding: .day, value: -1, to: self.calendar.startOfDay(for: day)),
                  used == yesterday else { return nil }
            return Reminders.FreezeNote(streak: status.streak)
        }
    }

    /// Today's progress against the plan: minutes logged (plan tasks, Keep going extras, and extra
    /// listening logged today) and the plan's minutes (all its tasks, skipped ones included).
    func dayProgress(for plan: DayPlanRecord) -> (done: Int, planned: Int) {
        let allLogs = logs
        let logged = plan.sortedTasks.flatMap(\.allLogIDs).compactMap { id in allLogs.first { $0.id == id }?.minutes }.reduce(0, +)
        let bonus = calendar.isDateInToday(plan.day) ? bonusLogsToday.reduce(0) { $0 + $1.minutes } : 0
        let planned = plan.planTasks.reduce(0) { $0 + $1.minutesPlanned }
        return (logged + bonus, planned)
    }

    var bonusLogsToday: [ActivityLog] {
        logs.filter { $0.isBonus && calendar.isDateInToday($0.date) }
    }

    /// Today's other practice as Today lists it: an all-in-one entry's logs (same timestamp) form one group.
    var bonusEntriesToday: [[ActivityLog]] {
        var groups: [[ActivityLog]] = []
        for log in bonusLogsToday {
            if let index = groups.firstIndex(where: { $0[0].date == log.date }) {
                groups[index].append(log)
            } else {
                groups.append([log])
            }
        }
        return groups
    }

    func delete(_ logs: [ActivityLog]) {
        logs.forEach(context.delete)
        save()
        refreshReminders()
    }

    func delete(_ log: ActivityLog) {
        context.delete(log)
        save()
        refreshReminders()
    }

    /// Minutes logged when the task was done (may differ from the plan).
    func loggedMinutes(for task: PlannedTaskRecord) -> Int? {
        guard task.logID != nil else { return nil }
        let ids = Set(task.allLogIDs)
        return logs.filter { ids.contains($0.id) }.reduce(0) { $0 + $1.minutes }
    }

    /// Card subtitle: the planner's detail, or the learner's Duolingo position for the warm-up.
    func detailText(for task: PlannedTaskRecord) -> String? {
        if task.task == .drillLesson, let profile {
            return "Section \(profile.duolingoSection) · Unit \(profile.duolingoUnit)"
        }
        if task.task == .contentWatch, let current = currentContent {
            return current.title
        }
        if task.task == .reviewMistakes {
            let due = dueCards.count
            return due == 1 ? "1 card due" : "\(due) cards due"
        }
        return TaskCopy.detail(task.detail)
    }

    // MARK: - Mistake deck

    var allCards: [ReviewCard] {
        _ = revision
        let code = languageCode
        return (try? context.fetch(FetchDescriptor<ReviewCard>(predicate: #Predicate { $0.languageCode == code },
                                                               sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
    }

    /// Cards due now, most overdue first.
    var dueCards: [ReviewCard] {
        _ = revision
        let now = Date.now
        let code = languageCode
        return (try? context.fetch(FetchDescriptor<ReviewCard>(predicate: #Predicate { $0.due <= now && $0.languageCode == code },
                                                               sortBy: [SortDescriptor(\.due)]))) ?? []
    }

    func review(_ card: ReviewCard, rating: FSRS.Rating) {
        // During a mistake-review task, remember the card as it was, so undoing the task can put it back.
        if let task = activeTask, task.task == .reviewMistakes {
            var before = task.reviewsBefore.flatMap { try? JSONDecoder().decode([String: FSRS.Card].self, from: $0) } ?? [:]
            if before[card.id.uuidString] == nil {
                before[card.id.uuidString] = card.schedule
                task.reviewsBefore = try? JSONEncoder().encode(before)
            }
        }
        card.schedule = FSRS().review(card.schedule, rating: rating, now: .now)
        save()
    }

    func addCard(wrong: String, right: String, note: String, origin: String) {
        let wrong = wrong.trimmingCharacters(in: .whitespacesAndNewlines)
        let right = right.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !wrong.isEmpty, !right.isEmpty else { return }
        insert(ReviewCard(front: "Fix it: \(wrong)", back: right, explanation: note.trimmingCharacters(in: .whitespacesAndNewlines), origin: origin))
        save()
    }

    func deleteCard(_ card: ReviewCard) {
        context.delete(card)
        save()
    }

    // MARK: - Level-up gates

    var isGateOpen: Bool {
        guard let profile else { return false }
        return LevelGate.isOpen(band: profile.band, hours: trainingHours, lastFailedAttempt: profile.lastFailedGate, today: .now,
                                levels: profile.pack.levels, calendar: calendar)
    }

    func passGate() {
        guard let profile, let next = profile.band.next else { return }
        profile.band = next
        profile.gatesPassed += 1
        profile.lastFailedGate = nil
        save()
        celebrations += 1
        confettiBursts += 1
    }

    func failGate() {
        profile?.lastFailedGate = .now
        save()
    }

    /// Travel mode: Pico carries his big backpack, whatever his mood.
    var showsBackpack: Bool { profile?.travelMode == true }

    /// What Pico is up to on the home screens.
    var picoMood: PicoMood {
        guard profile != nil else { return .hovering }
        // Travel mode doesn't change the mood: Pico wears his backpack on top of it (`showsBackpack`).
        let hour = calendar.component(.hour, from: .now)
        if hour >= 20 && minutesToday == 0 { return .sleepy }
        return .hovering
    }

    func logs(on day: Date) -> [ActivityLog] {
        logs.filter { calendar.isDate($0.date, inSameDayAs: day) }
    }

    // MARK: - Library

    /// What the last check for new Library suggestions found, shown at the bottom of the Library.
    private(set) var catalogStatus = ""
    private var checkingCatalog = false

    /// Checks GitHub for a newer suggestions list: when the Library opens or is pulled, and when the app comes back.
    func refreshCatalog() async {
        guard !checkingCatalog else { return }
        checkingCatalog = true
        defer { checkingCatalog = false }
        // Runs in its own task, so leaving the Library mid-download doesn't cancel it.
        let current = catalog
        let pack = pack
        let result = await Task.detached { await ContentLibrary.check(against: current, pack: pack) }.value
        // The language was switched while it downloaded: this list isn't the one on screen.
        guard pack.code == languageCode else { return }
        let time = Date.now.formatted(date: .omitted, time: .shortened)
        switch result {
        case .updated(let newer):
            catalog = newer
            catalogStatus = "Suggestions list v\(newer.version) · updated at \(time)"
        case .upToDate(let version):
            catalogStatus = "Suggestions list v\(version) · up to date (checked at \(time))"
        case .failed(let reason):
            catalogStatus = "Suggestions list v\(catalog.version) · couldn't check for new ones: \(reason)"
        }
    }

    var contentSuggestions: (now: [ContentItem], next: [ContentItem]) {
        guard let profile else { return ([], []) }
        return catalog.suggestions(for: profile.band)
    }

    /// What the learner marked "Watching this", if it's still in the catalog.
    var currentContent: ContentItem? {
        guard let id = profile?.currentContentID, !id.isEmpty else { return nil }
        return catalog.items.first { $0.id == id }
    }

    func toggleWatching(_ item: ContentItem) {
        guard let profile else { return }
        profile.currentContentID = profile.currentContentID == item.id ? "" : item.id
        save()
    }

    func setTravelMode(_ on: Bool) {
        profile?.travelMode = on
        save()
        replanTodayIfNotStarted()
    }

    /// After a setting that shapes the plan changes (travel mode, Duolingo, lessons, speaking stage):
    /// today's plan is made again at the same time, as long as no task has been started. A started day keeps
    /// its plan, and the change applies from the next one.
    func replanTodayIfNotStarted() {
        guard let plan = todayPlan, canChangeBudget else { return }
        makeTodayPlan(budget: plan.budgetMinutes)
    }

    // MARK: - Stats

    /// Minutes per strand over the last 7 days.
    var strandMinutesThisWeek: [Strand: Int] {
        ProgressStats.strandMinutes(history: history, today: .now, calendar: calendar)
    }

    func heatMapWeeks(_ count: Int = 12) -> [[ProgressStats.Day]] {
        ProgressStats.weeks(count, history: history, today: .now, calendar: calendar)
    }

    // MARK: - Path

    /// Input pace for forecasts: the learner's own once there's a week of history, else their weekly goal.
    var forecastWeeklyHours: (hours: Double, isOwnPace: Bool) {
        guard let profile else { return (0, false) }
        let projection = Projection(calendar: calendar)
        if projection.hasEnoughHistory(history, today: .now) {
            return (projection.weeklyHours(history: history, today: .now), true)
        }
        return (Projection.weeklyHours(atGoalMinutes: profile.weeklyGoalMinutes), false)
    }

    /// Training hours still needed for the goal level by the end of a day: what was logged up to then for
    /// days so far, the forecast pace for days ahead. Nil without a profile.
    struct GoalCountdown {
        let band: Band
        /// Training hours the goal level starts at, in this language.
        fileprivate let goalHours: Double
        fileprivate let baseline: Double
        fileprivate let logs: [(date: Date, minutes: Int)]
        fileprivate let now: Date
        fileprivate let hoursNow: Double
        /// The forecast pace: the learner's own over the last 4 weeks, or the weekly goal until there's a week of history.
        let weeklyHours: Double
        fileprivate let calendar: Calendar

        /// Weeks `hours` takes at the forecast pace, or nil with no pace yet.
        func weeks(for hours: Double) -> Int? {
            guard weeklyHours > 0 else { return nil }
            return Int((hours / weeklyHours).rounded(.up))
        }

        /// Hours left after `day` ends, and whether that's a projection.
        func hoursLeft(after day: Date) -> (hours: Double, projected: Bool) {
            guard let end = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: day)) else { return (0, false) }
            if end <= now {
                let minutes = logs.filter { $0.date < end }.reduce(0) { $0 + $1.minutes }
                return (max(0, goalHours - baseline - Double(minutes) / 60), false)
            }
            let weeks = end.timeIntervalSince(now) / (7 * 24 * 3600)
            let projected = calendar.isDate(day, inSameDayAs: now) ? hoursNow : hoursNow + weeklyHours * weeks
            return (max(0, goalHours - projected), !calendar.isDate(day, inSameDayAs: now))
        }
    }

    var goalCountdown: GoalCountdown? {
        guard let profile else { return nil }
        return GoalCountdown(band: profile.goalBand, goalHours: profile.goalHours, baseline: Band.trainingHours(fromListening: profile.baselineInputHours),
                             logs: logs.map { ($0.date, $0.minutes) }, now: .now, hoursNow: trainingHours,
                             weeklyHours: forecastWeeklyHours.hours, calendar: calendar)
    }

    var pathMap: PathMap {
        guard let profile else { return PathMap(units: [], milestones: []) }
        let days = pathDays()
        var arrivals = Projection(calendar: calendar).arrivalDates(hours: trainingHours, weeklyHours: forecastWeeklyHours.hours, from: .now, levels: profile.pack.levels)
        arrivals = arrivals.filter { $0.key > profile.band }
        let status = streak
        let calculator = StreakCalculator(weeklyGoalMinutes: profile.weeklyGoalMinutes, calendar: calendar)
        return PathLayout.map(start: profile.createdAt, today: .now, days: days, arrivals: arrivals,
                              frozen: Set(status.frozenDays), freezesEarned: status.freezesEarned.map { (day: $0.day, streak: $0.streak) },
                              nextFreeze: calculator.nextFreeze(status, today: .now),
                              goal: pathGoal(profile), history: profile.pathHistory,
                              calendar: calendar)
    }

    private func pathGoal(_ profile: LearnerProfile) -> PathLayout.Goal {
        PathLayout.Goal(weeklyMinutes: profile.weeklyGoalMinutes, lessons: profile.lessonSchedule)
    }

    /// Saves each past day's path colour once (and today's need as it stands), so later goal or schedule
    /// changes never recolour a day that's over.
    func settlePath() {
        guard let profile else { return }
        var history = profile.pathHistory
        let today = calendar.startOfDay(for: .now)
        let needed = PathLayout.neededMinutes(on: today, days: pathDays(), goal: pathGoal(profile), calendar: calendar)
        if history.update(with: pathMap, todayNeeded: needed, today: today, calendar: calendar) {
            profile.pathHistory = history
            try? context.save()
        }
    }

    /// What happened on each day, for the path: minutes, and whether its plan was finished.
    private func pathDays() -> [Date: PathLayout.Day] {
        let allLogs = logs
        let minutesByLog = Dictionary(allLogs.map { ($0.id, $0.minutes) }, uniquingKeysWith: +)
        var days: [Date: PathLayout.Day] = [:]
        var plannedLogIDs: Set<UUID> = []

        // Days with a plan: finished or not, credited to the day the plan is for (even if done early).
        for session in sessions {
            let done = session.sortedTasks.filter { $0.status == .done }
            let ids = done.flatMap(\.allLogIDs)
            plannedLogIDs.formUnion(ids)
            guard !done.isEmpty else { continue }
            let day = calendar.startOfDay(for: session.day)
            let minutes = ids.compactMap { minutesByLog[$0] }.reduce(0, +)
            days[day] = PathLayout.Day(minutes: minutes, session: session.isComplete ? .finished : .unfinished)
        }

        // Other practice (extra listening, restored backups) adds minutes to the day it happened.
        for log in allLogs where !plannedLogIDs.contains(log.id) {
            let day = calendar.startOfDay(for: log.date)
            let existing = days[day] ?? PathLayout.Day(minutes: 0, session: .none)
            days[day] = PathLayout.Day(minutes: existing.minutes + log.minutes, session: existing.session)
        }
        return days
    }

    func acceptDifficultySuggestion() {
        guard let profile, let suggestion = difficultySuggestion else { return }
        profile.dsDifficulty = suggestion
        save()
    }

    /// Unlocks voice notes / calls when the evidence supports it (§2.4).
    private func updateSpeakingStage() {
        guard let profile else { return }
        let tandemLogs = logs.filter(\.task.isExchange)
        let textLogs = tandemLogs.filter { $0.task == .exchangeText }
        let span = textLogs.first.flatMap { first in
            textLogs.last.map { calendar.dateComponents([.day], from: first.date, to: $0.date).day ?? 0 }
        } ?? 0
        let evidence = SpeakingProgress.Evidence(
            inputHours: listeningHours,
            textExchanges: textLogs.count,
            textExchangeSpanDays: span,
            comfortableWithText: ["easy", "ok"].contains(textLogs.last?.rating ?? ""),
            voiceNotes: tandemLogs.filter { $0.task == .exchangeVoice }.count
        )
        let stage = SpeakingProgress.stage(for: evidence, current: profile.speakingStage)
        let capped = SpeakingStage(rawValue: min(stage.rawValue, profile.speakingStageCap)) ?? .text
        guard capped > profile.speakingStage else { return }
        profile.speakingStage = capped
        save()
        banner = capped == .calls
            ? Banner(title: "Live calls unlocked", message: "Once a week Rumbo will plan a short call with your \(pack.sources[.exchange]?.shortName ?? "exchange") partner.")
            : Banner(title: "Voice notes unlocked", message: "Plan a few bullet points, then record a 1–2 minute voice note. Planning first makes speaking easier.")
    }

    /// Settings → Speaking: switch voice notes or live calls on or off by hand. On also lets Rumbo unlock the
    /// next stage by itself again; off keeps that stage (and the ones after it) off until switched back on.
    func setSpeakingStage(_ stage: SpeakingStage, on: Bool) {
        guard let profile else { return }
        if on {
            profile.speakingStage = max(profile.speakingStage, stage)
            profile.speakingStageCap = SpeakingStage.calls.rawValue
        } else {
            let below = SpeakingStage(rawValue: stage.rawValue - 1) ?? .text
            profile.speakingStage = min(profile.speakingStage, below)
            profile.speakingStageCap = below.rawValue
        }
        save()
        replanTodayIfNotStarted()
    }

    func save() {
        try? context.save()
        settlePath()
        revision += 1
        publishWidgets()
    }

    // MARK: - Widgets

    @ObservationIgnored private var lastSnapshot: WidgetSnapshot?

    /// Writes what the widgets show and reloads them, if it changed.
    func publishWidgets() {
        guard let profile else { return }
        let today = calendar.startOfDay(for: .now)
        let plan = session(for: today)
        // The plan (skips hidden), then "Keep going" extras once they're done.
        let shown = (plan?.planTasks ?? []).filter { $0.status != .skipped } + (plan?.extraTasks ?? []).filter { $0.status == .done }
        var tasks = shown.map {
            WidgetSnapshot.TaskLine(title: TaskCopy.title(for: $0.task), symbol: TaskCopy.symbol(for: $0.task),
                                    minutes: $0.status == .done ? loggedMinutes(for: $0) ?? $0.minutesPlanned : $0.minutesPlanned,
                                    done: $0.status == .done, colorHex: $0.task.hex, isExtra: $0.isExtra)
        }
        // No plan yet: preview the one the gold-starred budget would give, so the widget shows what's on track.
        var suggested: Int?
        if plan == nil {
            let preview = suggestedPreview(for: today, profile: profile)
            suggested = preview.minutes
            tasks = preview.tasks
        }
        let status = streak
        // Widgets have one look per mood, so travel mode shows the backpacker (pack and hat) there.
        let mood: String
        if profile.travelMode {
            mood = "backpacker"
        } else {
            mood = picoMood == .sleepy ? "sleepy" : "hovering"
        }
        var snapshot = WidgetSnapshot(
            updated: .now, day: today, streak: status.streak, minutesThisWeek: status.minutesThisWeek,
            weeklyGoal: profile.weeklyGoalMinutes, bandLabel: "\(profile.pack.levelName(profile.band)) · \(profile.band.rawValue)",
            dayComplete: plan?.isComplete ?? false, hasPlan: plan != nil, tasks: tasks, mood: mood,
            suggestedMinutes: suggested, minutesToday: minutesToday,
            upcoming: (1...3).compactMap { calendar.date(byAdding: .day, value: $0, to: today) }.map { upcomingSnapshot(for: $0, profile: profile) },
            languageCode: profile.languageCode
        )
        var comparable = snapshot
        comparable.updated = lastSnapshot?.updated ?? snapshot.updated
        guard comparable != lastSnapshot else { return }
        snapshot.updated = .now
        snapshot.save()
        lastSnapshot = snapshot
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// The plan the gold-starred budget would give on `day`, as widget lines.
    private func suggestedPreview(for day: Date, profile: LearnerProfile) -> (minutes: Int, tasks: [WidgetSnapshot.TaskLine]) {
        let status = StreakCalculator(weeklyGoalMinutes: profile.weeklyGoalMinutes, calendar: calendar).status(history: history, today: day)
        let budget = BudgetAdvisor.advice(weeklyGoal: profile.weeklyGoalMinutes, minutesThisWeek: status.minutesThisWeek, today: day,
                                          lessons: profile.lessonSchedule, calendar: calendar).recommended
        let preview = DayPlanner(calendar: calendar).plan(budget: budget, learner: snapshot(for: profile), history: history, today: day)
        return (budget, preview.tasks.map {
            WidgetSnapshot.TaskLine(title: TaskCopy.title(for: $0.kind), symbol: TaskCopy.symbol(for: $0.kind),
                                    minutes: $0.minutes, done: false, colorHex: $0.kind.hex)
        })
    }

    /// A later day as the widget should show it if nothing more is logged before then: the suggested plan,
    /// that week's minutes (a new week starts at zero) and the streak as it would stand.
    private func upcomingSnapshot(for day: Date, profile: LearnerProfile) -> WidgetSnapshot {
        let status = StreakCalculator(weeklyGoalMinutes: profile.weeklyGoalMinutes, calendar: calendar).status(history: history, today: day)
        let preview = suggestedPreview(for: day, profile: profile)
        return WidgetSnapshot(
            updated: day, day: day, streak: status.streak, minutesThisWeek: status.minutesThisWeek,
            weeklyGoal: profile.weeklyGoalMinutes, bandLabel: "\(profile.pack.levelName(profile.band)) · \(profile.band.rawValue)",
            dayComplete: false, hasPlan: false, tasks: preview.tasks, mood: profile.travelMode ? "backpacker" : "hovering",
            suggestedMinutes: preview.minutes, minutesToday: 0, languageCode: profile.languageCode
        )
    }
}
