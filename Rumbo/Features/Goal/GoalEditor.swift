import RumboCore
import SwiftUI

/// The goal level, the weekly goal and the target date, kept in step (docs/03-experience.md "Goal").
/// Changing the weekly goal moves the date; picking a date sets the weekly goal that gets there.
/// Used in onboarding and in Settings → Goal.
struct GoalEditor: View {
    @Binding var goal: String
    @Binding var weeklyMinutes: Int
    @Binding var targetDate: Date
    /// Listening hours so far, and the learner's band (for the listening share).
    let currentHours: Double
    let band: Band

    /// Set while one value is being updated from the other, so they don't bounce back and forth.
    @State private var syncing = false

    static let levels = ["B1", "B2", "C1"]

    static func goalBand(for goal: String) -> Band {
        switch goal {
        case "B1": .b1_1
        case "C1": .b2_2
        default: .b2_1
        }
    }

    static func description(for goal: String) -> String {
        switch goal {
        case "B1": "Get by confidently: travel, everyday conversations, simple opinions."
        case "C1": "Near-native ease. Rumbo's path goes to B2.2, then keeps you growing with native content."
        default: "Comfortably conversational: follow native speakers and hold your own in a group."
        }
    }

    private var goalBand: Band { Self.goalBand(for: goal) }
    private var weeklyHours: Double { Projection.weeklyInputHours(atGoalMinutes: weeklyMinutes, band: band) }
    private var alreadyThere: Bool { currentHours >= goalBand.inputHoursThreshold }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            levelPicker
            if alreadyThere {
                Label("You've already got the hours for \(goal). Pick a higher goal, or keep this one and enjoy the ride.", systemImage: "checkmark.seal.fill")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.leaf)
            }
            weeklyGoalCard
            linkBadge
            dateCard
            preview
        }
        .onChange(of: goal) { _, _ in dateFromMinutes() }
        .onChange(of: weeklyMinutes) { _, _ in
            if syncing { syncing = false } else { dateFromMinutes() }
        }
        .onChange(of: targetDate) { _, _ in
            if syncing { syncing = false } else { minutesFromDate() }
        }
    }

    // MARK: Pieces

    private var levelPicker: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your goal")
                .font(.rounded(.headline, weight: .heavy))
                .foregroundStyle(Palette.ink)
            HStack(spacing: 10) {
                ForEach(Self.levels, id: \.self) { level in
                    ChipButton(title: level, isSelected: goal == level, color: Palette.coral) { goal = level }
                }
            }
            Text(Self.description(for: goal))
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
        }
    }

    private var weeklyGoalCard: some View {
        RaisedCard(accent: Palette.leaf) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Weekly goal")
                    .font(.rounded(.headline, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                HStack(spacing: 16) {
                    roundButton("minus", enabled: weeklyMinutes > GoalPace.minutes.lowerBound) {
                        weeklyMinutes = max(GoalPace.minutes.lowerBound, weeklyMinutes - GoalPace.step)
                    }
                    VStack(spacing: 0) {
                        Text("\(weeklyMinutes)")
                            .font(.system(size: 44, weight: .black, design: .rounded))
                            .foregroundStyle(Palette.ink)
                            .contentTransition(.numericText(value: Double(weeklyMinutes)))
                        Text("min a week")
                            .font(.rounded(.subheadline, weight: .bold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    roundButton("plus", enabled: weeklyMinutes < GoalPace.minutes.upperBound) {
                        weeklyMinutes = min(GoalPace.minutes.upperBound, weeklyMinutes + GoalPace.step)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: weeklyMinutes)
                Text("About \(Int((Double(weeklyMinutes) / 7).rounded())) min a day on average; busy days are fine. \(String(format: "%.1f", weeklyHours)) h of that is listening, which is what counts toward levels.")
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
            }
        }
        .sensoryFeedback(.selection, trigger: weeklyMinutes)
        .accessibilityElement(children: .contain)
    }

    private func roundButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.title2.weight(.black))
                .foregroundStyle(.white)
                .frame(width: 52, height: 52)
                .background(Circle().fill(enabled ? Palette.leaf : Palette.secondaryText.opacity(0.4)))
                .background(Circle().fill(enabled ? Palette.leaf.edge() : .clear).offset(y: 3))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .buttonRepeatBehavior(.enabled)
        .accessibilityLabel(symbol == "plus" ? "10 more minutes a week" : "10 fewer minutes a week")
    }

    private var linkBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.up.arrow.down")
            Text("Linked: change one and the other follows")
        }
        .font(.rounded(.caption, weight: .heavy))
        .foregroundStyle(Palette.secondaryText)
        .frame(maxWidth: .infinity)
    }

    private var dateCard: some View {
        RaisedCard(accent: Palette.sun) {
            VStack(alignment: .leading, spacing: 8) {
                DatePicker(selection: $targetDate, in: tomorrow..., displayedComponents: .date) {
                    Text("Reach \(goal) by")
                        .font(.rounded(.headline, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                }
                .tint(Palette.coral)
                Text(dateNote)
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(outOfReach ? Palette.coral : Palette.secondaryText)
            }
        }
    }

    private var tomorrow: Date {
        Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: .now))!
    }

    private var outOfReach: Bool {
        GoalPace.isOutOfReach(goalBand, by: targetDate, currentHours: currentHours, band: band, from: .now)
    }

    private var dateNote: String {
        if alreadyThere { return "Already reached." }
        let months = max(0, Calendar.current.dateComponents([.month], from: .now, to: targetDate).month ?? 0)
        if outOfReach {
            return "That's sooner than even \(GoalPace.minutes.upperBound) min a week can get you there. Try a later date."
        }
        let span = months < 18 ? "\(months) months" : "about \(Int((Double(months) / 12).rounded())) years"
        return "\(span) from now. \(goal) needs \(Int(goalBand.inputHoursThreshold)) h of listening; you have \(Int(currentHours))."
    }

    /// The road at this pace, as on Progress.
    private var preview: some View {
        let projection = Projection()
        let arrivals = projection.arrivalDates(inputHours: currentHours, weeklyHours: weeklyHours, from: .now)
        let atTarget = projection.inputHours(by: targetDate, from: .now, current: currentHours, weeklyHours: weeklyHours)
        return VStack(alignment: .leading, spacing: 10) {
            Text("At this pace")
                .font(.rounded(.headline, weight: .heavy))
                .foregroundStyle(Palette.ink)
            LevelTimeline(band: band, hours: currentHours, arrivals: arrivals, goal: goal, goalBand: goalBand,
                          targetDate: targetDate, hoursAtTarget: atTarget)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: weeklyMinutes)
    }

    // MARK: Keeping the two in step

    private func dateFromMinutes() {
        let date = GoalPace.arrival(of: goalBand, currentHours: currentHours, weeklyMinutes: weeklyMinutes, band: band, from: .now)
        let clamped = max(date, tomorrow)
        guard !Calendar.current.isDate(clamped, inSameDayAs: targetDate) else { return }
        syncing = true
        targetDate = clamped
    }

    private func minutesFromDate() {
        let minutes = GoalPace.weeklyMinutes(toReach: goalBand, by: targetDate, currentHours: currentHours, band: band, from: .now)
        guard minutes != weeklyMinutes else { return }
        syncing = true
        weeklyMinutes = minutes
    }
}

/// Settings → Goal: the goal editor on its own page, saving as it changes.
struct GoalSettingsView: View {
    @Environment(AppModel.self) private var model
    @State private var goal = "B2"
    @State private var weeklyMinutes = 150
    @State private var targetDate = Date.now
    @State private var loaded = false

    var body: some View {
        ScrollView {
            if let profile = model.profile {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 12) {
                        PicoBadge(size: 56, mood: .proud)
                        Text("Set your goal, then either how much time you'll give it each week or when you want to get there.")
                            .font(.rounded(.subheadline, weight: .semibold))
                            .foregroundStyle(Palette.secondaryText)
                    }
                    // Shown once the saved values are in, so loading them doesn't count as an edit.
                    if loaded {
                        GoalEditor(goal: $goal, weeklyMinutes: $weeklyMinutes, targetDate: $targetDate,
                                   currentHours: model.inputHours, band: profile.band)
                    }
                }
                .padding(20)
            }
        }
        .background(Palette.background.ignoresSafeArea())
        .navigationTitle("Goal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear(perform: load)
        .onChange(of: goal) { _, _ in store() }
        .onChange(of: weeklyMinutes) { _, _ in store() }
        .onChange(of: targetDate) { _, _ in store() }
    }

    private func load() {
        guard !loaded, let profile = model.profile else { return }
        goal = profile.goal
        weeklyMinutes = profile.weeklyGoalMinutes
        // Older profiles may have no date: start from where the weekly goal leads.
        targetDate = profile.targetDate ?? GoalPace.arrival(of: GoalEditor.goalBand(for: profile.goal), currentHours: model.inputHours,
                                                           weeklyMinutes: profile.weeklyGoalMinutes, band: profile.band, from: .now)
        loaded = true
    }

    private func store() {
        guard loaded, let profile = model.profile else { return }
        profile.goal = goal
        profile.weeklyGoalMinutes = weeklyMinutes
        profile.targetDate = targetDate
        model.save()
    }
}
