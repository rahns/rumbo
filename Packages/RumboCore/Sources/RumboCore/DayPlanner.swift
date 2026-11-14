import Foundation

/// What a planned card points at, so the app can show "Track 13" or "Episode 2, part 1".
public enum TaskDetail: Equatable, Sendable {
    case none
    /// A track of the audio course.
    case track(Int)
    case seriesPart(episode: Int, part: Int)
    case seriesEpisode(Int)
    /// A difficulty range in the graded video library.
    case difficulty(ClosedRange<Int>)
}

public struct PlannedTask: Equatable, Sendable {
    public var kind: TaskKind
    public var minutes: Int
    public var detail: TaskDetail
    /// Planned because a weekly anchor was due.
    public var isAnchor: Bool
}

public struct DayPlan: Equatable, Sendable {
    public var budget: Int
    public var band: Band
    public var tasks: [PlannedTask]

    public var totalMinutes: Int { tasks.reduce(0) { $0 + $1.minutes } }

    /// What today's output card should reuse (R4): the Language Transfer track or Extra episode planned today.
    public var focus: TaskDetail? {
        tasks.first { task in
            switch task.detail {
            case .track, .seriesPart, .seriesEpisode: true
            default: false
            }
        }?.detail
    }
}

/// Builds one day's plan. Implements docs/02-learning-engine.md §2.5.
public struct DayPlanner: Sendable {
    public static let maxCards = 4
    public static let budgetChoices = [10, 15, 20, 30, 45, 60]

    /// The time chips for a day: on a lesson day, longer ones too, since the lesson is part of the day's time.
    public static func budgetChoices(lessonMinutes: Int?) -> [Int] {
        guard let lessonMinutes, lessonMinutes > 0 else { return budgetChoices }
        return budgetChoices + [90, 120].filter { $0 > (budgetChoices.last ?? 60) }
    }

    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func plan(budget: Int, learner: LearnerSnapshot, history: [ActivityRecord], today: Date) -> DayPlan {
        let window = recentRecords(history, before: today)
        var builder = PlanBuilder(budget: budget, learner: learner, window: window)

        // A lesson day: the lesson is always in the plan, at its length, and uses up part of the day's time.
        if let lesson = learner.lessons.lesson(on: today, calendar: calendar) {
            builder.addLesson(lesson)
        }
        if budget <= 10 {
            // Busy day: a 3-minute Duolingo lesson keeps that streak alive, then one task for the rest
            // (the travel mission, in travel mode).
            builder.planBusyDayWarmUp()
            builder.planTravelMission()
            builder.planSingleTask()
        } else {
            builder.planWarmUp()
            builder.planTravelMission()
            builder.fill()
            builder.spendLeftover()
        }
        return DayPlan(budget: budget, band: learner.band, tasks: builder.orderedTasks())
    }

    /// "Keep going" options once today's plan is complete: every task the learner can do that isn't
    /// already in today's plan, at its standard length, the most-behind strand first (§2.5 step 8).
    public func extraTasks(learner: LearnerSnapshot, history: [ActivityRecord], today: Date, excluding planned: Set<TaskKind>) -> [PlannedTask] {
        // Today's practice counts too: it's already done.
        let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: today))!
        let window = recentRecords(history, before: startOfTomorrow)
        let builder = PlanBuilder(budget: 0, learner: learner, window: window)
        let order = Dictionary(uniqueKeysWithValues: TaskKind.allCases.enumerated().map { ($1, $0) })
        return TaskKind.allCases
            .filter { !planned.contains($0) && learner.isEligible($0) }
            .sorted { lhs, rhs in
                let left = builder.deficit(lhs.strand), right = builder.deficit(rhs.strand)
                if left != right { return left > right }
                return order[lhs]! < order[rhs]!
            }
            .map { PlannedTask(kind: $0, minutes: builder.fixedMinutes(for: $0) ?? learner.minuteRange(for: $0).standard, detail: builder.detail(for: $0), isAnchor: false) }
    }

    /// Records from the 6 days before `today` (today itself is what's being planned).
    func recentRecords(_ history: [ActivityRecord], before today: Date) -> [ActivityRecord] {
        let startOfToday = calendar.startOfDay(for: today)
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return [] }
        return history.filter { $0.date >= windowStart && $0.date < startOfToday }
    }
}

// MARK: - Builder

private struct PlanBuilder {
    let budget: Int
    let learner: LearnerSnapshot
    let window: [ActivityRecord]
    var tasks: [PlannedTask] = []

    init(budget: Int, learner: LearnerSnapshot, window: [ActivityRecord]) {
        self.budget = budget
        self.learner = learner
        self.window = window
    }

    var remaining: Int { budget - tasks.reduce(0) { $0 + $1.minutes } }

    mutating func addLesson(_ lesson: PlannedTask) {
        tasks.append(lesson)
    }

    mutating func planBusyDayWarmUp() {
        if learner.alwaysIncludeDrillApp, learner.isEligible(.drillLesson) {
            add(.drillLesson, minutes: learner.minuteRange(for: .drillLesson).min)
        }
    }

    // Step 1
    mutating func planWarmUp() {
        // Every day, so the Duolingo streak survives; one 3-minute lesson leaves study time for Language Transfer.
        if budget >= 15, learner.alwaysIncludeDrillApp, learner.isEligible(.drillLesson) {
            add(.drillLesson, minutes: learner.minuteRange(for: .drillLesson).standard)
        }
        if budget >= 20, learner.dueReviewCards >= 5, learner.isEligible(.reviewMistakes) {
            add(.reviewMistakes, minutes: budget >= 30 ? 5 : 3)
        }
    }

    /// Travel mode: a real-world mission every day, online or not, not only when speaking & writing gets a card.
    mutating func planTravelMission() {
        guard learner.travelMode, learner.isEligible(.missionTravel), !tasks.contains(where: { $0.kind == .missionTravel }) else { return }
        let range = learner.minuteRange(for: .missionTravel)
        let minutes = min(range.standard, remaining)
        guard minutes >= range.min else { return }
        add(.missionTravel, minutes: minutes)
    }

    // Step 3: new cards, strand with the largest deficit first.
    mutating func fill() {
        var exhausted: Set<Strand> = []
        // A lesson doesn't take one of the cards.
        while tasks.filter({ !$0.kind.isLesson }).count < DayPlanner.maxCards && remaining > 0 {
            // A strand set to 0% in a custom balance never gets a card.
            let strands = Strand.allCases
                .filter { !exhausted.contains($0) && (learner.strandTargets[$0] ?? 0) > 0 }
                .sorted { deficit($0) > deficit($1) }
            guard let strand = strands.first else { return }

            if !addCard(in: strand) {
                exhausted.insert(strand)
            }
        }
    }

    /// Adds a new card to `strand`. Returns false if nothing in the strand fits.
    private mutating func addCard(in strand: Strand) -> Bool {
        let wanted = Int((deficit(strand) / 5).rounded()) * 5
        for kind in candidates(for: strand) where !tasks.contains(where: { $0.kind == kind }) {
            if let fixed = fixedMinutes(for: kind) {
                guard fixed <= remaining else { continue }
                add(kind, minutes: fixed)
                return true
            }
            let range = learner.minuteRange(for: kind)
            let minutes = min(min(max(wanted, range.min), range.max), remaining)
            guard minutes >= range.min else { continue }
            add(kind, minutes: minutes)
            return true
        }
        // A beginner's study strand often has only one source (Duolingo, already in as the warm-up): rather
        // than leaving its share unspent, lengthen the task already planned there, within its range.
        // Beginners only, so plans from A2 up are unchanged.
        if learner.band < .a2_1,
           let index = tasks.firstIndex(where: { $0.kind.strand == strand && !$0.kind.isLesson && fixedMinutes(for: $0.kind) == nil }) {
            let headroom = learner.minuteRange(for: tasks[index].kind).max - tasks[index].minutes
            let extra = min(headroom, max(wanted, 5), remaining)
            if extra > 0 {
                tasks[index].minutes += extra
                return true
            }
        }
        return false
    }

    /// Tasks with a set length: a Language Transfer track takes as long as the track is.
    func fixedMinutes(for kind: TaskKind) -> Int? {
        guard kind == .courseTrack, case .track(let track) = detail(for: kind) else { return nil }
        return learner.pack.course?.minutes(track: track)
    }

    // Step 7: one task for what's left of a 10-minute day, preferring one that fills it.
    mutating func planSingleTask() {
        let left = remaining
        guard left > 0 else { return }
        for strand in Strand.allCases.filter({ (learner.strandTargets[$0] ?? 0) > 0 }).sorted(by: { deficit($0) > deficit($1) }) {
            let fitting = candidates(for: strand).filter { kind in
                (fixedMinutes(for: kind) ?? learner.minuteRange(for: kind).min) <= left && !tasks.contains { $0.kind == kind }
            }
            if let kind = fitting.first(where: { (fixedMinutes(for: $0) ?? learner.minuteRange(for: $0).max) >= left }) ?? fitting.first {
                add(kind, minutes: fixedMinutes(for: kind) ?? min(left, learner.minuteRange(for: kind).max))
                return
            }
        }
    }

    /// Leftover minutes go to existing cards with headroom: input first, then by deficit.
    mutating func spendLeftover() {
        let order = tasks.indices.sorted { lhs, rhs in
            let left = tasks[lhs].kind.strand, right = tasks[rhs].kind.strand
            if (left == .input) != (right == .input) { return left == .input }
            return deficit(left) > deficit(right)
        }
        for index in order where remaining > 0 && fixedMinutes(for: tasks[index].kind) == nil && !tasks[index].kind.isLesson {
            let headroom = learner.minuteRange(for: tasks[index].kind).max - tasks[index].minutes
            tasks[index].minutes += min(headroom, remaining)
        }
    }

    // Step 5
    func orderedTasks() -> [PlannedTask] {
        func rank(_ task: PlannedTask) -> Int {
            switch task.kind {
            case .drillLesson: 0
            case .lessonOutput, .lessonInput, .lessonStudy, .lessonMixed: 1
            case .reviewMistakes: 2
            default:
                switch task.kind.strand {
                case .languageFocused: 3
                case .input: 4
                case .output: 5
                case .fluency: 6
                }
            }
        }
        return tasks.enumerated()
            .sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }
            .map(\.element)
    }

    // MARK: Deficits (step 2)

    func deficit(_ strand: Strand) -> Double {
        let logged = window.filter { $0.kind.strand == strand }.reduce(0) { $0 + $1.minutes }
        let loggedTotal = window.reduce(0) { $0 + $1.minutes }
        // An all-in-one lesson counts a third toward speaking, listening and grammar & vocab.
        let planned = tasks.reduce(0.0) { total, task in
            if task.kind == .lessonMixed { return total + (strand == .fluency ? 0 : Double(task.minutes) / 3) }
            return total + (task.kind.strand == strand ? Double(task.minutes) : 0)
        }
        let share = learner.strandTargets[strand] ?? 0
        let target = share * Double(loggedTotal + budget)
        return target - Double(logged) - planned
    }

    // MARK: Candidates

    /// Eligible tasks for a strand, in order: due anchors, then progression, then defaults (§2.5 step 3).
    func candidates(for strand: Strand) -> [TaskKind] {
        var ordered: [TaskKind]
        switch strand {
        case .input:
            ordered = anchorsDue(.seriesIntensive) + anchorsDue(.seriesExtensive)
                + [.gradedWatch, .seriesIntensive, .seriesExtensive, .contentWatch]
        case .languageFocused:
            ordered = [.courseTrack, .reviewMistakes, .drillLesson]
        case .output:
            // Once calls are unlocked, one call a week; voice notes otherwise.
            let callDue = learner.isEligible(.exchangeCall) && count(of: .exchangeCall) == 0
            let exchange = callDue ? .exchangeCall : learner.preferredExchangeTask
            var anchors: [TaskKind] = anchorsDue(.writeGuided)
            if isExchangeAnchorDue && anchorSlotFree { anchors.append(exchange) }
            // The week's call goes first: it's the one speaking task that doesn't fit into a short slot later.
            if callDue && isExchangeAnchorDue && anchorSlotFree { anchors.insert(.exchangeCall, at: 0) }
            let travel: [TaskKind] = learner.travelMode ? [.missionTravel] : []
            ordered = travel + anchors + [exchange, learner.preferredExchangeTask, .writeGuided, .exchangeCall, .exchangeText, .missionTravel]
        case .fluency:
            ordered = anchorsDue(.fluency432) + [.gradedEasy, .writeQuick, .fluency432]
        }
        var seen: Set<TaskKind> = []
        return ordered.filter { learner.isEligible($0) && seen.insert($0).inserted }
    }

    /// At most one anchor per day (two from 45 minutes), so a fresh week doesn't crowd out progression.
    private var anchorSlotFree: Bool {
        tasks.filter(\.isAnchor).count < (budget >= 45 ? 2 : 1)
    }

    private func anchorsDue(_ kind: TaskKind) -> [TaskKind] {
        guard anchorSlotFree else { return [] }
        // Short days stay with the main listening source; the learner series waits for a day with enough time.
        if kind.source == .learnerSeries && budget < (learner.pack.series?.minimumBudget ?? 0) { return [] }
        let targets = learner.pack.anchorTargets(for: learner.band)
        let required: Int = switch kind {
        case .writeGuided: targets.writing
        case .seriesIntensive: targets.seriesIntensiveParts
        case .seriesExtensive: targets.seriesEpisodes
        case .fluency432: targets.fluency432
        default: 0
        }
        return count(of: kind) < required && learner.isEligible(kind) ? [kind] : []
    }

    private var isExchangeAnchorDue: Bool {
        let done = window.filter(\.kind.isExchange).count + tasks.filter(\.kind.isExchange).count
        return done < learner.pack.anchorTargets(for: learner.band).exchanges
    }

    private func count(of kind: TaskKind) -> Int {
        window.filter { $0.kind == kind }.count + tasks.filter { $0.kind == kind }.count
    }

    func isAnchor(_ kind: TaskKind) -> Bool {
        switch kind.strand {
        case .output:
            !anchorsDue(kind).isEmpty || (kind.isExchange && isExchangeAnchorDue && anchorSlotFree)
        default:
            !anchorsDue(kind).isEmpty
        }
    }

    // MARK: Adding

    private mutating func add(_ kind: TaskKind, minutes: Int) {
        let anchor = isAnchor(kind)
        tasks.append(PlannedTask(kind: kind, minutes: minutes, detail: detail(for: kind), isAnchor: anchor))
    }

    func detail(for kind: TaskKind) -> TaskDetail {
        switch kind {
        case .courseTrack:
            let track = learner.courseRepeatPending
                ? max(learner.courseLastTrack, 1)
                : learner.courseLastTrack + 1
            return .track(min(track, learner.pack.course?.tracks ?? track))
        case .seriesIntensive:
            return .seriesPart(episode: learner.seriesEpisodesWatched + 1, part: learner.seriesPartsDone + 1)
        case .seriesExtensive:
            return .seriesEpisode(learner.seriesEpisodesWatched + 1)
        case .gradedWatch:
            return learner.pack.graded == nil ? .none : .difficulty(learner.gradedDifficulty)
        case .gradedEasy:
            guard let graded = learner.pack.graded else { return .none }
            return .difficulty(graded.easyRange(below: learner.gradedDifficulty.lowerBound))
        default:
            return .none
        }
    }
}
