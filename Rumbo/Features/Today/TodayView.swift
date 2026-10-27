import RumboCore
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var openTask: PlannedTaskRecord?
    @State private var showingBonus = false
    @State private var showingGate = false

    /// Pushed from today's node on the path, so it lives inside the path's NavigationStack.
    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    banners
                    if let plan = model.todayPlan {
                        planSection(plan)
                    } else {
                        budgetPrompt
                    }
                    bonusSection
                    Button {
                        showingBonus = true
                    } label: {
                        Label("Log extra listening", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(ChunkySecondaryButtonStyle())
                }
                .padding(20)
            }
            .background(Palette.background.ignoresSafeArea())
            ConfettiView(trigger: model.confettiBursts)
        }
        .navigationTitle(model.isWorkingAhead ? model.planDay.formatted(.dateTime.weekday(.wide)) : "Today")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(item: $openTask) { task in
            TaskSessionView(task: task)
        }
        .fullScreenCover(isPresented: $showingGate) {
            GateView()
        }
        .sheet(isPresented: $showingBonus) {
            BonusInputSheet()
                .presentationDetents([.medium])
        }
    }

    // MARK: Header

    private var header: some View {
        let streak = model.streak
        let goal = model.profile?.weeklyGoalMinutes ?? 150
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                PicoBadge(size: 60, mood: model.picoMood, celebrate: model.celebrations)
                VStack(alignment: .leading, spacing: 2) {
                    Text(greeting)
                        .font(.rounded(.title2, weight: .black))
                        .foregroundStyle(Palette.ink)
                    if let profile = model.profile {
                        Text("\(profile.band.label) · \(profile.band.rawValue)")
                            .font(.rounded(.subheadline, weight: .bold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                }
                Spacer()
                StatPill(symbol: "flame.fill", value: "\(streak.streak)", color: Palette.sun, bounce: streak.streak)
                StatPill(symbol: "star.fill", value: "\(model.xp)", color: Palette.sky)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("This week")
                    Spacer()
                    Text("\(streak.minutesThisWeek) / \(goal) min")
                        .contentTransition(.numericText())
                }
                .font(.rounded(.caption, weight: .heavy))
                .foregroundStyle(Palette.secondaryText)
                ChunkyProgressBar(value: Double(streak.minutesThisWeek) / Double(max(goal, 1)), color: Palette.leaf)
            }
        }
    }

    private var greeting: String {
        let name = model.profile?.displayName ?? ""
        let hour = Calendar.current.component(.hour, from: .now)
        let hello = hour < 12 ? "¡Buenos días" : hour < 20 ? "¡Buenas tardes" : "¡Buenas noches"
        return name.isEmpty ? "\(hello)!" : "\(hello), \(name)!"
    }

    // MARK: Banners

    @ViewBuilder
    private var banners: some View {
        if model.isGateOpen, let next = model.profile?.band.next {
            BannerCard(title: "Level-up check ready", message: "You've reached the hours for \(next.label). Ten quick questions and you could move up.", color: Palette.sun) {
                Button("Check now") { showingGate = true }
                    .buttonStyle(ChunkyButtonStyle(color: Palette.sun, foreground: Palette.ink, fullWidth: false))
            }
        }
        if let banner = model.banner {
            BannerCard(title: banner.title, message: banner.message, color: Palette.sky) {
                Button("Got it") { model.banner = nil }
                    .buttonStyle(ChunkyButtonStyle(color: Palette.sky, fullWidth: false))
            }
        }
        if let suggestion = model.difficultySuggestion, let current = model.profile?.dsDifficulty {
            let harder = suggestion.lowerBound > current.lowerBound
            BannerCard(
                title: harder ? "Ready for harder videos?" : "Let's make it easier",
                message: harder
                    ? "Your recent Dreaming Spanish videos felt easy. Try videos rated \(suggestion.lowerBound)–\(suggestion.upperBound)."
                    : "You've felt lost a few times. Try videos rated \(suggestion.lowerBound)–\(suggestion.upperBound) so input stays understandable.",
                color: Palette.coral
            ) {
                Button("Switch") { model.acceptDifficultySuggestion() }
                    .buttonStyle(ChunkyButtonStyle(color: Palette.coral, fullWidth: false))
            }
        }
    }

    // MARK: Budget

    private var budgetPrompt: some View {
        RaisedCard(accent: Palette.coral) {
            VStack(alignment: .leading, spacing: 14) {
                Text(model.isWorkingAhead ? "Getting ahead! How long?" : "How much time today?")
                    .font(.rounded(.title3, weight: .black))
                    .foregroundStyle(Palette.ink)
                if model.isWorkingAhead {
                    Text("This is \(model.planDay.formatted(.dateTime.weekday(.wide)))'s session. Everything you've done so far is counted, so it balances out.")
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(Palette.secondaryText)
                }
                goalAdvice
                budgetChips(selected: nil)
            }
        }
    }

    /// What today needs for the weekly goal, e.g. "About 25 min a day for the 4 days left → pick 30".
    private var goalAdvice: some View {
        let advice = model.budgetAdvice
        let goal = model.profile?.weeklyGoalMinutes ?? 150
        let days = advice.daysLeft == 1 ? "today, the last day of the week" : "each of the \(advice.daysLeft) days left this week"
        return HStack(alignment: .top, spacing: 10) {
            Image(systemName: advice.goalAlreadyMet ? "checkmark.seal.fill" : "target")
                .font(.title3.weight(.bold))
                .foregroundStyle(advice.goalAlreadyMet ? Palette.leaf : Palette.sun)
            // LocalizedStringKey so the **bold** recommendation renders as Markdown.
            Text(LocalizedStringKey(advice.goalAlreadyMet
                 ? "You've met your \(goal)-minute goal this week. Any time today is a bonus; 10 minutes keeps the streak."
                 : "To reach your \(goal)-minute goal: about \(advice.minutesPerDay) min \(days). **\(advice.recommended) min** keeps you on track."))
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.ink)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cream))
    }

    private func budgetChips(selected: Int?) -> some View {
        let recommended = model.budgetAdvice.recommended
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 14) {
            ForEach(DayPlanner.budgetChoices, id: \.self) { minutes in
                ChipButton(title: minutes == 10 ? "10 · busy" : "\(minutes) min", isSelected: selected == minutes) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        model.makeTodayPlan(budget: minutes)
                    }
                }
                .overlay {
                    if minutes == recommended {
                        // The chip that keeps the weekly goal on track.
                        Capsule()
                            .strokeBorder(Palette.sun, lineWidth: 3)
                            .padding(.bottom, 3)
                            .padding(-3)
                            .allowsHitTesting(false)
                    }
                }
                .overlay(alignment: .top) {
                    if minutes == recommended {
                        Image(systemName: "star.fill")
                            .font(.system(size: 11, weight: .black))
                            .foregroundStyle(Palette.sun)
                            .offset(y: -10)
                            .accessibilityLabel("Recommended")
                    }
                }
            }
        }
    }

    // MARK: Plan

    private func planSection(_ plan: DayPlanRecord) -> some View {
        let tasks = plan.sortedTasks
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(plan.isComplete ? (model.isWorkingAhead ? "Done early! 🎉" : "Day complete! 🎉") : "Today's plan")
                    .font(.rounded(.title3, weight: .black))
                    .foregroundStyle(Palette.ink)
                Spacer()
                Text("\(plan.budgetMinutes) min")
                    .font(.rounded(.subheadline, weight: .heavy))
                    .foregroundStyle(Palette.secondaryText)
            }
            if model.canChangeBudget {
                budgetChips(selected: plan.budgetMinutes)
            }
            if plan.isComplete {
                Button {
                    withAnimation { model.workAhead() }
                } label: {
                    Label("Keep going: do \(nextDayName) now", systemImage: "forward.fill")
                }
                .buttonStyle(ChunkyButtonStyle(color: Palette.sky))
            }
            if tasks.isEmpty {
                Text("Nothing fits with the sources you have switched on. Check Settings → Sources.")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Palette.secondaryText)
            }
            ForEach(tasks) { task in
                TaskCardView(task: task, detail: model.detailText(for: task)) {
                    if task.status != .active { model.start(task) }
                    openTask = task
                } onSkip: {
                    withAnimation { model.skip(task) }
                } onUndo: {
                    withAnimation { model.undo(task) }
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: tasks.map(\.statusRaw))
    }
}

extension TodayView {
    /// "tomorrow", or the weekday when already working ahead.
    var nextDayName: String {
        let next = Calendar.current.date(byAdding: .day, value: 1, to: model.planDay) ?? .now
        return Calendar.current.isDateInTomorrow(next) ? "tomorrow" : next.formatted(.dateTime.weekday(.wide))
    }

    /// Extra listening logged today, each with an undo.
    @ViewBuilder
    var bonusSection: some View {
        let logs = model.bonusLogsToday
        if !logs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Extra listening today")
                    .font(.rounded(.headline, weight: .black))
                    .foregroundStyle(Palette.ink)
                ForEach(logs) { log in
                    HStack {
                        Image(systemName: "ear.fill").foregroundStyle(Palette.coral)
                        Text("\(log.minutes) min")
                            .font(.rounded(.body, weight: .bold))
                            .foregroundStyle(Palette.ink)
                        Text(log.date.formatted(date: .omitted, time: .shortened))
                            .font(.rounded(.subheadline, weight: .medium))
                            .foregroundStyle(Palette.secondaryText)
                        Spacer()
                        Button {
                            withAnimation { model.delete(log) }
                        } label: {
                            Label("Undo", systemImage: "arrow.uturn.backward")
                                .font(.rounded(.subheadline, weight: .heavy))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Palette.secondaryText)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
                    .transition(.opacity)
                }
            }
        }
    }
}

struct StatPill: View {
    let symbol: String
    let value: String
    let color: Color
    /// The icon bounces when this changes (e.g. the streak goes up).
    var bounce: Int = 0

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .symbolEffect(.bounce, value: bounce)
            Text(value)
                .foregroundStyle(Palette.ink)
                .contentTransition(.numericText())
        }
        .font(.rounded(.subheadline, weight: .heavy))
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Capsule().fill(Palette.card))
    }
}

struct BannerCard<Actions: View>: View {
    let title: String
    let message: String
    let color: Color
    @ViewBuilder var actions: Actions

    var body: some View {
        RaisedCard(accent: color) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.rounded(.headline, weight: .black)).foregroundStyle(Palette.ink)
                Text(message).font(.rounded(.subheadline, weight: .medium)).foregroundStyle(Palette.secondaryText)
                actions
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

struct TaskCardView: View {
    let task: PlannedTaskRecord
    let detail: String?
    let onStart: () -> Void
    let onSkip: () -> Void
    let onUndo: () -> Void

    var body: some View {
        let kind = task.task
        let color = kind.strand.color
        let finished = task.status == .done || task.status == .skipped
        RaisedCard(accent: color) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        if finished { onUndo() }
                    } label: {
                        Image(systemName: finished ? (task.status == .done ? "checkmark" : "forward.fill") : TaskCopy.symbol(for: kind))
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 46, height: 46)
                            .background(Circle().fill(finished ? Palette.secondaryText.opacity(0.5) : color))
                            .background(Circle().fill(color.edge()).offset(y: 3).opacity(finished ? 0 : 1))
                            .contentTransition(.symbolEffect(.replace))
                            // Finishing a task flips its icon over to the tick.
                            .rotation3DEffect(.degrees(task.status == .done ? 360 : 0), axis: (x: 0, y: 1, z: 0))
                    }
                    .buttonStyle(.plain)
                    .disabled(!finished)
                    .accessibilityLabel(finished ? "Undo" : TaskCopy.title(for: kind))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(TaskCopy.title(for: kind))
                                .font(.rounded(.headline, weight: .heavy))
                            if task.isAnchor {
                                Image(systemName: "star.circle.fill")
                                    .foregroundStyle(Palette.sun)
                                    .accessibilityLabel("Weekly task")
                            }
                        }
                        .foregroundStyle(Palette.ink)
                        if let detail {
                            Text(detail)
                                .font(.rounded(.subheadline, weight: .semibold))
                                .foregroundStyle(Palette.secondaryText)
                        }
                    }
                    Spacer()
                    Text(TaskCopy.minutesLabel(task.minutesPlanned))
                        .font(.rounded(.subheadline, weight: .heavy))
                        .foregroundStyle(finished ? Palette.secondaryText : color)
                }
                if !task.prompt.isEmpty && !finished {
                    Text(task.prompt)
                        .font(.rounded(.subheadline, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(RoundedRectangle(cornerRadius: 12).fill(Palette.cream))
                }
                if !finished {
                    HStack(spacing: 10) {
                        Button(task.status == .active ? "Continue" : "Start", action: onStart)
                            .buttonStyle(ChunkyButtonStyle(color: color))
                        if task.status == .planned {
                            Button(action: onSkip) {
                                Image(systemName: "forward.fill")
                            }
                            .buttonStyle(ChunkySecondaryButtonStyle(fullWidth: false))
                            .accessibilityLabel("Skip")
                        }
                    }
                }
            }
        }
        .opacity(finished ? 0.65 : 1)
    }
}
