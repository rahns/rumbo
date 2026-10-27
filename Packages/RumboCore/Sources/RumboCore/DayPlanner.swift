import Foundation

/// What a planned card points at, so the app can show "Track 13" or "Episode 2, part 1".
public enum TaskDetail: Equatable, Sendable {
    case none
    case languageTransferTrack(Int)
    case extraPart(episode: Int, part: Int)
    case extraEpisode(Int)
    case dreamingDifficulty(ClosedRange<Int>)
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
            case .languageTransferTrack, .extraPart, .extraEpisode: true
            default: false
            }
        }?.detail
    }
}

/// Builds one day's plan. Implements docs/02-learning-engine.md §2.5.
public struct DayPlanner: Sendable {
    public static let maxCards = 4
    public static let budgetChoices = [10, 15, 20, 30, 45, 60]

    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func plan(budget: Int, learner: LearnerSnapshot, history: [ActivityRecord], today: Date) -> DayPlan {
        let window = recentRecords(history, before: today)
        var builder = PlanBuilder(budget: budget, learner: learner, window: window)

        if budget <= 10 {
            builder.planSingleTask()
        } else {
            builder.planWarmUp()
            builder.fill()
            builder.spendLeftover()
        }
        return DayPlan(budget: budget, band: learner.band, tasks: builder.orderedTasks())
    }

    /// Records from the 6 days before `today` (today itself is what's being planned).
    func recentRecords(_ history: [ActivityRecord], before today: Date) -> [ActivityRecord] {
        let startOfToday = calendar.startOfDay(for: today)
        guard let windowStart = calendar.date(byAdding: .day, value: -6, to: startOfToday) else { return [] }
        return history.filter { $0.date >= windowStart && $0.date < startOfToday }
    }
}

// MARK: - Weekly anchors

/// How often each anchor should happen in a rolling 7 days, by band (§2.5 "Weekly anchors").
struct AnchorTargets {
    var writing: Int
    var extraIntensiveParts: Int
    var extraEpisodes: Int
    var tandemExchanges: Int
    var fluency432: Int

    init(band: Band) {
        switch band {
        case .a2_1, .a2_2:
            // Dreaming Spanish is the main input; Extra is a once-a-week change of pace.
            self.init(writing: 1, extraIntensiveParts: 1, extraEpisodes: 0, tandemExchanges: 3, fluency432: 0)
        case .b1_1, .b1_2:
            self.init(writing: 2, extraIntensiveParts: 0, extraEpisodes: 1, tandemExchanges: 3, fluency432: 1)
        case .b2_1:
            self.init(writing: 2, extraIntensiveParts: 0, extraEpisodes: 0, tandemExchanges: 3, fluency432: 1)
        case .b2_2:
            self.init(writing: 3, extraIntensiveParts: 0, extraEpisodes: 0, tandemExchanges: 3, fluency432: 1)
        }
    }

    private init(writing: Int, extraIntensiveParts: Int, extraEpisodes: Int, tandemExchanges: Int, fluency432: Int) {
        self.writing = writing
        self.extraIntensiveParts = extraIntensiveParts
        self.extraEpisodes = extraEpisodes
        self.tandemExchanges = tandemExchanges
        self.fluency432 = fluency432
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

    // Step 1
    mutating func planWarmUp() {
        if budget >= 15, learner.isEligible(.duoLesson) {
            add(.duoLesson, minutes: 5)
        }
        if budget >= 20, learner.dueReviewCards >= 5, learner.isEligible(.reviewMistakes) {
            add(.reviewMistakes, minutes: budget >= 30 ? 5 : 3)
        }
    }

    // Step 3: new cards, strand with the largest deficit first.
    mutating func fill() {
        var exhausted: Set<Strand> = []
        while tasks.count < DayPlanner.maxCards {
            let strands = Strand.allCases
                .filter { !exhausted.contains($0) }
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
            let range = kind.minutes
            let minutes = min(min(max(wanted, range.min), range.max), remaining)
            guard minutes >= range.min else { continue }
            add(kind, minutes: minutes)
            return true
        }
        return false
    }

    // Step 6: prefer a task that can fill the whole budget (so not the 5-minute Duolingo warm-up).
    mutating func planSingleTask() {
        for strand in Strand.allCases.sorted(by: { deficit($0) > deficit($1) }) {
            let fitting = candidates(for: strand).filter { $0.minutes.min <= budget }
            if let kind = fitting.first(where: { $0.minutes.max >= budget }) ?? fitting.first {
                add(kind, minutes: min(budget, kind.minutes.max))
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
        for index in order where remaining > 0 {
            let headroom = tasks[index].kind.minutes.max - tasks[index].minutes
            tasks[index].minutes += min(headroom, remaining)
        }
    }

    // Step 5
    func orderedTasks() -> [PlannedTask] {
        func rank(_ task: PlannedTask) -> Int {
            switch task.kind {
            case .duoLesson: 0
            case .reviewMistakes: 1
            default:
                switch task.kind.strand {
                case .languageFocused: 2
                case .input: 3
                case .output: 4
                case .fluency: 5
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
        let planned = tasks.filter { $0.kind.strand == strand }.reduce(0) { $0 + $1.minutes }
        let share = learner.band.strandTargets[strand] ?? 0
        let target = share * Double(loggedTotal + budget)
        return target - Double(logged) - Double(planned)
    }

    // MARK: Candidates

    /// Eligible tasks for a strand, in order: due anchors, then progression, then defaults (§2.5 step 3).
    func candidates(for strand: Strand) -> [TaskKind] {
        var ordered: [TaskKind]
        switch strand {
        case .input:
            ordered = anchorsDue(.extraIntensive) + anchorsDue(.extraExtensive)
                + [.dsWatch, .extraIntensive, .extraExtensive, .contentWatch]
        case .languageFocused:
            ordered = [.ltTrack, .reviewMistakes, .duoLesson]
        case .output:
            // Once calls are unlocked, one call a week; voice notes otherwise.
            let callDue = learner.isEligible(.tandemCall) && count(of: .tandemCall) == 0
            let tandem = callDue ? .tandemCall : learner.preferredTandemTask
            var anchors: [TaskKind] = anchorsDue(.writeGuided)
            if isTandemAnchorDue && anchorSlotFree { anchors.append(tandem) }
            let travel: [TaskKind] = learner.travelMode ? [.missionTravel] : []
            ordered = travel + anchors + [tandem, learner.preferredTandemTask, .writeGuided, .tandemCall, .tandemText, .missionTravel]
        case .fluency:
            ordered = anchorsDue(.fluency432) + [.dsEasy, .writeQuick, .fluency432]
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
        // Short days stay with Dreaming Spanish; Extra waits for a day with 20+ minutes.
        if kind.source == .extraEnEspanol && budget < 20 { return [] }
        let targets = AnchorTargets(band: learner.band)
        let required: Int = switch kind {
        case .writeGuided: targets.writing
        case .extraIntensive: targets.extraIntensiveParts
        case .extraExtensive: targets.extraEpisodes
        case .fluency432: targets.fluency432
        default: 0
        }
        return count(of: kind) < required && learner.isEligible(kind) ? [kind] : []
    }

    private var isTandemAnchorDue: Bool {
        let done = window.filter(\.kind.isTandemExchange).count + tasks.filter(\.kind.isTandemExchange).count
        return done < AnchorTargets(band: learner.band).tandemExchanges
    }

    private func count(of kind: TaskKind) -> Int {
        window.filter { $0.kind == kind }.count + tasks.filter { $0.kind == kind }.count
    }

    func isAnchor(_ kind: TaskKind) -> Bool {
        switch kind.strand {
        case .output:
            !anchorsDue(kind).isEmpty || (kind.isTandemExchange && isTandemAnchorDue && anchorSlotFree)
        default:
            !anchorsDue(kind).isEmpty
        }
    }

    // MARK: Adding

    private mutating func add(_ kind: TaskKind, minutes: Int) {
        let anchor = isAnchor(kind)
        tasks.append(PlannedTask(kind: kind, minutes: minutes, detail: detail(for: kind), isAnchor: anchor))
    }

    private func detail(for kind: TaskKind) -> TaskDetail {
        switch kind {
        case .ltTrack:
            let track = learner.languageTransferRepeatPending
                ? max(learner.languageTransferLastTrack, 1)
                : learner.languageTransferLastTrack + 1
            return .languageTransferTrack(min(track, Course.languageTransferTracks))
        case .extraIntensive:
            return .extraPart(episode: learner.extraEpisodesWatched + 1, part: learner.extraPartsDoneInEpisode + 1)
        case .extraExtensive:
            return .extraEpisode(learner.extraEpisodesWatched + 1)
        case .dsWatch:
            return .dreamingDifficulty(learner.dsDifficulty)
        case .dsEasy:
            let low = max(0, learner.dsDifficulty.lowerBound - 15)
            let high = max(low, learner.dsDifficulty.lowerBound - 10)
            return .dreamingDifficulty(low...high)
        default:
            return .none
        }
    }
}
