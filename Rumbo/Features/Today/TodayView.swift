import RumboCore
import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var model
    @State private var openTask: PlannedTaskRecord?
    @State private var showingBonus = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    banners
                    if let plan = model.todayPlan {
                        planSection(plan)
                    } else {
                        budgetPrompt
                    }
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
            .toolbar(.hidden, for: .navigationBar)
            .fullScreenCover(item: $openTask) { task in
                TaskSessionView(task: task)
            }
            .sheet(isPresented: $showingBonus) {
                BonusInputSheet()
                    .presentationDetents([.medium])
            }
        }
    }

    // MARK: Header

    private var header: some View {
        let streak = model.streak
        let goal = model.profile?.weeklyGoalMinutes ?? 150
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                PicoBadge(size: 52)
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
                StatPill(symbol: "flame.fill", value: "\(streak.streak)", color: Palette.sun)
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
                Text("How much time today?")
                    .font(.rounded(.title3, weight: .black))
                    .foregroundStyle(Palette.ink)
                Text("Pick honestly. Ten minutes still counts.")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Palette.secondaryText)
                budgetChips(selected: nil)
            }
        }
    }

    private func budgetChips(selected: Int?) -> some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 10) {
            ForEach(DayPlanner.budgetChoices, id: \.self) { minutes in
                ChipButton(title: minutes == 10 ? "10 · busy" : "\(minutes) min", isSelected: selected == minutes) {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        model.makeTodayPlan(budget: minutes)
                    }
                }
            }
        }
    }

    // MARK: Plan

    private func planSection(_ plan: DayPlanRecord) -> some View {
        let tasks = plan.sortedTasks
        let done = tasks.filter { $0.status == .done }.count
        return VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(done == tasks.count && !tasks.isEmpty ? "All done today 🎉" : "Today's plan")
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
            if tasks.isEmpty {
                Text("Nothing fits with the sources you have switched on. Check Settings → Sources.")
                    .font(.rounded(.subheadline, weight: .medium))
                    .foregroundStyle(Palette.secondaryText)
            }
            ForEach(tasks) { task in
                TaskCardView(task: task) {
                    if task.status != .active { model.start(task) }
                    openTask = task
                } onSkip: {
                    withAnimation { model.skip(task) }
                }
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: tasks.map(\.statusRaw))
    }
}

struct StatPill: View {
    let symbol: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: symbol).foregroundStyle(color)
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
    let onStart: () -> Void
    let onSkip: () -> Void

    var body: some View {
        let kind = task.task
        let color = kind.strand.color
        let finished = task.status == .done || task.status == .skipped
        RaisedCard(accent: color) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: finished ? (task.status == .done ? "checkmark" : "forward.fill") : TaskCopy.symbol(for: kind))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 46, height: 46)
                        .background(Circle().fill(finished ? Palette.secondaryText.opacity(0.5) : color))
                        .background(Circle().fill(color.edge()).offset(y: 3).opacity(finished ? 0 : 1))
                        .contentTransition(.symbolEffect(.replace))
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
                        if let detail = TaskCopy.detail(task.detail) {
                            Text(detail)
                                .font(.rounded(.subheadline, weight: .semibold))
                                .foregroundStyle(Palette.secondaryText)
                        }
                    }
                    Spacer()
                    Text(TaskCopy.minutesLabel(task.minutesPlanned))
                        .font(.rounded(.subheadline, weight: .heavy))
                        .foregroundStyle(color)
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
