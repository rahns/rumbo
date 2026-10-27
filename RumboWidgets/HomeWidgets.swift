import SwiftUI
import WidgetKit

// Home and Lock Screen widgets (docs/03-experience.md §3.6). Data comes from the snapshot the app
// writes after every change; tapping any widget opens Rumbo.

struct RumboEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot?
}

struct RumboProvider: TimelineProvider {
    func placeholder(in context: Context) -> RumboEntry {
        RumboEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (RumboEntry) -> Void) {
        completion(RumboEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()?.current()))
    }

    /// One entry now and one just after midnight, when yesterday's plan stops showing.
    func getTimeline(in context: Context, completion: @escaping (Timeline<RumboEntry>) -> Void) {
        let now = Date.now
        let snapshot = WidgetSnapshot.load()
        let midnight = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: now))!.addingTimeInterval(60)
        let entries = [
            RumboEntry(date: now, snapshot: snapshot?.current(at: now)),
            RumboEntry(date: midnight, snapshot: snapshot?.current(at: midnight)),
        ]
        completion(Timeline(entries: entries, policy: .after(midnight)))
    }
}

// MARK: - Home screen

struct RumboHomeWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RumboToday", provider: RumboProvider()) { entry in
            HomeWidgetView(entry: entry)
                .containerBackground(Palette.background, for: .widget)
                .widgetURL(entry.snapshot?.tapURL ?? URL(string: "rumbo://today"))
        }
        .configurationDisplayName("Rumbo")
        .description("Your streak, this week's minutes and today's plan.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

struct HomeWidgetView: View {
    let entry: RumboEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        if let snapshot = entry.snapshot {
            switch family {
            case .systemMedium: medium(snapshot)
            case .systemLarge: large(snapshot)
            default: small(snapshot)
            }
        } else {
            VStack(spacing: 6) {
                PicoStill(mood: .hovering, size: 60)
                Text("Open Rumbo to get started")
                    .font(.rounded(.caption, weight: .bold))
                    .foregroundStyle(Palette.secondaryText)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private func small(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                PicoStill(mood: snapshot.dayComplete ? .cheering : mood(snapshot), size: 56)
                Spacer(minLength: 0)
                WeekRing(snapshot: snapshot, size: 44)
            }
            Spacer(minLength: 0)
            StreakLabel(streak: snapshot.streak)
            Text(status(snapshot))
                .font(.rounded(.caption, weight: .heavy))
                .foregroundStyle(snapshot.dayComplete ? Palette.leaf : Palette.secondaryText)
                .lineLimit(2)
        }
    }

    private func medium(_ snapshot: WidgetSnapshot) -> some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                PicoStill(mood: snapshot.dayComplete ? .cheering : mood(snapshot), size: 58)
                HStack(alignment: .top, spacing: 8) {
                    StreakLabel(streak: snapshot.streak)
                    WeekRing(snapshot: snapshot, size: 34)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                planHeader(snapshot)
                taskList(snapshot, limit: 4)
                Spacer(minLength: 0)
            }
        }
    }

    private func large(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                PicoStill(mood: snapshot.dayComplete ? .cheering : mood(snapshot), size: 64)
                VStack(alignment: .leading, spacing: 4) {
                    StreakLabel(streak: snapshot.streak)
                    Text(snapshot.bandLabel)
                        .font(.rounded(.caption, weight: .bold))
                        .foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 0)
                WeekRing(snapshot: snapshot, size: 50, showsMinutes: true)
            }
            Divider()
            planHeader(snapshot)
            taskList(snapshot, limit: 7)
            Spacer(minLength: 0)
            if snapshot.isSuggestion {
                Text("Tap to start this plan")
                    .font(.rounded(.subheadline, weight: .heavy))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Palette.coral))
            }
        }
    }

    /// "Today", "¡Hecho!", or, before a plan is picked, the on-track suggestion.
    @ViewBuilder
    private func planHeader(_ snapshot: WidgetSnapshot) -> some View {
        if snapshot.isSuggestion, let minutes = snapshot.suggestedMinutes {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Image(systemName: "star.fill").foregroundStyle(Palette.sun)
                    Text("Suggested: \(minutes) min")
                }
                .font(.rounded(.headline, weight: .black))
                .foregroundStyle(Palette.ink)
                Text("Keeps you on track for your weekly goal")
                    .font(.rounded(.caption2, weight: .bold))
                    .foregroundStyle(Palette.secondaryText)
                    .lineLimit(1)
            }
        } else {
            Text(snapshot.dayComplete ? "¡Hecho! Day complete" : "Today")
                .font(.rounded(.headline, weight: .black))
                .foregroundStyle(snapshot.dayComplete ? Palette.leaf : Palette.ink)
        }
    }

    @ViewBuilder
    private func taskList(_ snapshot: WidgetSnapshot, limit: Int) -> some View {
        if snapshot.tasks.isEmpty {
            Text("Tap to pick your time for today.")
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.secondaryText)
        } else {
            ForEach(Array(snapshot.tasks.prefix(limit).enumerated()), id: \.offset) { _, task in
                HStack(spacing: 6) {
                    Image(systemName: task.done ? "checkmark.circle.fill" : snapshot.isSuggestion ? task.symbol : "circle")
                        .foregroundStyle(task.done ? Palette.leaf : Color(uiColor: UIColor(hex: task.colorHex)))
                        .frame(width: 16)
                    Text(task.title)
                        .strikethrough(task.done)
                        .foregroundStyle(task.done ? Palette.secondaryText : Palette.ink)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Text("\(task.minutes)′")
                        .foregroundStyle(Palette.secondaryText)
                }
                .font(.rounded(family == .systemLarge ? .subheadline : .caption, weight: .bold))
            }
        }
    }

    private func status(_ snapshot: WidgetSnapshot) -> String {
        if snapshot.dayComplete { return "¡Hecho! Day complete" }
        if snapshot.isSuggestion, let minutes = snapshot.suggestedMinutes { return "Suggested: \(minutes) min, tap to start" }
        if let next = snapshot.nextTask { return "Next: \(next.title)" }
        return "Pick your time for today"
    }

    private func mood(_ snapshot: WidgetSnapshot) -> PicoMood {
        switch snapshot.mood {
        case "sleepy": .sleepy
        case "backpacker": .backpacker
        default: .hovering
        }
    }
}

// MARK: - Lock Screen

struct RumboLockScreenWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "RumboLockScreen", provider: RumboProvider()) { entry in
            LockScreenWidgetView(entry: entry)
                .containerBackground(.clear, for: .widget)
                .widgetURL(entry.snapshot?.tapURL ?? URL(string: "rumbo://today"))
        }
        .configurationDisplayName("Rumbo")
        .description("This week's minutes, your streak and the next task.")
        .supportedFamilies([.accessoryCircular, .accessoryRectangular, .accessoryInline])
    }
}

struct LockScreenWidgetView: View {
    let entry: RumboEntry
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let snapshot = entry.snapshot ?? .placeholder
        switch family {
        case .accessoryCircular:
            // Weekly goal only (the streak is on the rectangular and inline widgets).
            Gauge(value: Double(min(snapshot.minutesThisWeek, snapshot.weeklyGoal)), in: 0...Double(max(snapshot.weeklyGoal, 1))) {
                Text("WEEK")
            } currentValueLabel: {
                Text("\(Int(Double(snapshot.minutesThisWeek) / Double(max(snapshot.weeklyGoal, 1)) * 100))%")
            }
            .gaugeStyle(.accessoryCircular)
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Text("🔥 \(snapshot.streak) · \(snapshot.minutesThisWeek)/\(snapshot.weeklyGoal) min this week")
                    .font(.headline)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)
                if snapshot.dayComplete {
                    Text("Day complete ✓")
                } else if snapshot.isSuggestion, let minutes = snapshot.suggestedMinutes {
                    Text("Suggested: \(minutes) min")
                    Text("Tap to start").foregroundStyle(.secondary)
                } else if let next = snapshot.nextTask {
                    Text("Next: \(next.title)").lineLimit(1)
                    Text("\(next.minutes) min").foregroundStyle(.secondary)
                } else {
                    Text("Pick your time today")
                }
            }
        default:
            Text("🔥 \(snapshot.streak) · \(snapshot.minutesThisWeek)/\(snapshot.weeklyGoal) min this week")
        }
    }
}

// MARK: - Pieces

/// Pico drawn once, without animation (widgets render a still image).
struct PicoStill: View {
    let mood: PicoMood
    let size: CGFloat

    var body: some View {
        Canvas { context, canvasSize in
            PicoDrawing.draw(in: &context, size: canvasSize, time: 0, mood: mood, still: true)
        }
        .frame(width: size, height: size)
    }
}

/// Progress toward the weekly goal (minutes logged this week ÷ weekly goal), labelled "this week".
struct WeekRing: View {
    let snapshot: WidgetSnapshot
    let size: CGFloat
    /// Adds "85/150 min" under the label, where there's room.
    var showsMinutes = false

    var body: some View {
        let progress = Double(snapshot.minutesThisWeek) / Double(max(snapshot.weeklyGoal, 1))
        VStack(spacing: 2) {
            ZStack {
                Circle().stroke(Palette.lilac, lineWidth: size * 0.14)
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(Palette.leaf, style: StrokeStyle(lineWidth: size * 0.14, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(Int(min(progress, 9.99) * 100))%")
                    .font(.system(size: size * 0.26, weight: .black, design: .rounded))
                    .foregroundStyle(Palette.ink)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: size, height: size)
            Text(showsMinutes ? "\(snapshot.minutesThisWeek)/\(snapshot.weeklyGoal) min\nthis week" : "this week")
                .font(.rounded(.caption2, weight: .heavy))
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekly goal")
        .accessibilityValue("\(snapshot.minutesThisWeek) of \(snapshot.weeklyGoal) minutes this week")
    }
}

struct StreakLabel: View {
    let streak: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "flame.fill").foregroundStyle(Palette.sun)
            Text("\(streak)").foregroundStyle(Palette.ink)
        }
        .font(.rounded(.headline, weight: .black))
    }
}
