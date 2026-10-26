import RumboCore
import SwiftData
import SwiftUI
import UIKit

/// Doing one task: instructions, a timer, a link into the source app, then logging.
struct TaskSessionView: View {
    let task: PlannedTaskRecord

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var logging = false
    @State private var minutes = 0
    @State private var comprehension: ComprehensionTuner.Rating?
    @State private var trackRating: SourceProgress.TrackRating?
    @State private var tandemFeeling: String?
    @State private var writing = ""
    @State private var duolingoSection = 1
    @State private var duolingoUnit = 1

    private var kind: TaskKind { task.task }
    private var color: Color { kind.strand.color }
    private var isWriting: Bool { kind == .writeGuided || kind == .writeQuick }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    titleBlock
                    if logging {
                        logForm
                    } else {
                        sessionBody
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            bottomBar
        }
        .background(Palette.background.ignoresSafeArea())
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.rounded(.headline, weight: .heavy))
                    .foregroundStyle(Palette.secondaryText)
                    .padding(8)
            }
            .accessibilityLabel("Close")
            Spacer()
            Menu {
                Button("Stop without logging", systemImage: "xmark", role: .destructive) {
                    model.cancelActive(task)
                    dismiss()
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(Palette.secondaryText)
                    .padding(8)
            }
        }
        .padding(.horizontal, 12)
    }

    private var titleBlock: some View {
        HStack(spacing: 14) {
            Image(systemName: TaskCopy.symbol(for: kind))
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 58, height: 58)
                .background(Circle().fill(color))
                .background(Circle().fill(color.edge()).offset(y: 4))
            VStack(alignment: .leading, spacing: 2) {
                Text(TaskCopy.title(for: kind))
                    .font(.rounded(.title2, weight: .black))
                    .foregroundStyle(Palette.ink)
                if let detail = model.detailText(for: task) {
                    Text(detail)
                        .font(.rounded(.headline, weight: .bold))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
        }
    }

    private var sessionBody: some View {
        VStack(alignment: .leading, spacing: 18) {
            TimerDial(startedAt: task.startedAt ?? .now, plannedMinutes: task.minutesPlanned, color: color)
                .frame(maxWidth: .infinity)
            Text(TaskCopy.instructions(for: kind, detail: task.detail, band: model.profile?.band ?? .a2_1))
                .font(.rounded(.body, weight: .medium))
                .foregroundStyle(Palette.ink)
            if !task.prompt.isEmpty {
                Text(task.prompt)
                    .font(.rounded(.body, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cream))
            }
            if isWriting {
                writingEditor
            }
            if DeepLinks.url(for: kind, detail: task.detail) != nil {
                Button {
                    DeepLinks.open(kind, detail: task.detail)
                } label: {
                    Label(openLabel, systemImage: "arrow.up.forward.app.fill")
                }
                .buttonStyle(ChunkySecondaryButtonStyle())
            }
        }
    }

    private var openLabel: String {
        switch kind {
        case .extraIntensive, .extraExtensive: "Find it on YouTube"
        default: "Open \(TaskCopy.title(for: kind).replacingOccurrences(of: " warm-up", with: ""))"
        }
    }

    private var writingEditor: some View {
        VStack(alignment: .trailing, spacing: 6) {
            TextEditor(text: $writing)
                .font(.rounded(.body, weight: .medium))
                .scrollContentBackground(.hidden)
                .padding(10)
                .frame(minHeight: 200)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
            let words = writing.split(whereSeparator: \.isWhitespace).count
            let target = Prompts.wordTarget(for: model.profile?.band ?? .a2_1)
            Text(kind == .writeGuided ? "\(words) / \(target.lowerBound)–\(target.upperBound) words" : "\(words) words")
                .font(.rounded(.caption, weight: .heavy))
                .foregroundStyle(kind == .writeGuided && target.contains(words) ? Palette.leaf : Palette.secondaryText)
                .contentTransition(.numericText())
        }
    }

    private var logForm: some View {
        VStack(alignment: .leading, spacing: 18) {
            RaisedCard {
                NumberStepper(title: "Minutes spent", value: $minutes, range: 1...240, step: 1)
            }
            switch kind.strand {
            case .input where kind != .contentWatch:
                question("How much did you understand?") {
                    ChoiceRow(options: [
                        (ComprehensionTuner.Rating.lost, "😵", "Lost"),
                        (.mostly, "🙂", "Mostly"),
                        (.easy, "😎", "Easy"),
                    ], selection: $comprehension)
                }
            default:
                EmptyView()
            }
            if kind == .ltTrack {
                question("How did that track feel?") {
                    ChoiceRow(options: [
                        (SourceProgress.TrackRating.solid, "💪", "Solid"),
                        (.shaky, "🤔", "Shaky, repeat it"),
                    ], selection: $trackRating)
                }
            }
            if kind == .duoLesson {
                question("Where are you in Duolingo now?") {
                    RaisedCard {
                        VStack(spacing: 10) {
                            NumberStepper(title: "Section", value: $duolingoSection, range: 1...10, step: 1)
                            NumberStepper(title: "Unit", value: $duolingoUnit, range: 1...300, step: 1)
                        }
                    }
                }
            }
            if kind.isTandemExchange {
                question("How did it feel?") {
                    ChoiceRow(options: [("easy", "😎", "Easy"), ("ok", "🙂", "OK"), ("hard", "😬", "Hard")], selection: $tandemFeeling)
                }
            }
        }
    }

    private func question<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.rounded(.headline, weight: .heavy))
                .foregroundStyle(Palette.ink)
            content()
        }
    }

    private var bottomBar: some View {
        Group {
            if logging {
                Button("Save") { save() }
                    .buttonStyle(ChunkyButtonStyle(color: Palette.leaf))
                    .disabled(!canSave)
            } else {
                Button("I'm done") { beginLogging() }
                    .buttonStyle(ChunkyButtonStyle(color: color))
            }
        }
        .padding(20)
    }

    private var canSave: Bool {
        switch kind {
        case .ltTrack: trackRating != nil
        case .dsWatch, .dsEasy, .extraIntensive, .extraExtensive: comprehension != nil
        default: true
        }
    }

    // MARK: Actions

    private func beginLogging() {
        let elapsed = Date.now.timeIntervalSince(task.startedAt ?? .now) / 60
        minutes = max(1, Int(elapsed.rounded()))
        if elapsed < 1 { minutes = task.minutesPlanned }
        duolingoSection = model.profile?.duolingoSection ?? 1
        duolingoUnit = model.profile?.duolingoUnit ?? 1
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { logging = true }
    }

    private func save() {
        model.complete(task, with: .init(
            minutes: minutes,
            comprehension: comprehension,
            trackRating: trackRating,
            tandemFeeling: tandemFeeling,
            writing: isWriting ? writing : nil,
            duolingoPosition: kind == .duoLesson ? (section: duolingoSection, unit: duolingoUnit) : nil
        ))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

/// Big circular timer counting up against the planned minutes.
struct TimerDial: View {
    let startedAt: Date
    let plannedMinutes: Int
    let color: Color

    var body: some View {
        TimelineView(.periodic(from: startedAt, by: 1)) { context in
            let elapsed = max(0, context.date.timeIntervalSince(startedAt))
            let progress = elapsed / Double(max(plannedMinutes * 60, 1))
            ZStack {
                Circle().stroke(Palette.lilac, lineWidth: 16)
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 16, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: progress)
                VStack(spacing: 2) {
                    Text(Duration.seconds(elapsed).formatted(.time(pattern: .minuteSecond)))
                        .font(.system(size: 44, weight: .black, design: .rounded).monospacedDigit())
                        .foregroundStyle(Palette.ink)
                        .contentTransition(.numericText())
                    Text("of \(plannedMinutes) min")
                        .font(.rounded(.subheadline, weight: .bold))
                        .foregroundStyle(Palette.secondaryText)
                }
            }
            .frame(width: 200, height: 200)
        }
    }
}

/// Row of large emoji choices.
struct ChoiceRow<Value: Hashable>: View {
    let options: [(Value, String, String)]
    @Binding var selection: Value?

    var body: some View {
        HStack(spacing: 10) {
            ForEach(options.indices, id: \.self) { index in
                let value = options[index].0
                let emoji = options[index].1
                let label = options[index].2
                let selected = selection == value
                Button {
                    selection = value
                } label: {
                    VStack(spacing: 4) {
                        Text(emoji).font(.system(size: 30))
                        Text(label).font(.rounded(.caption, weight: .heavy))
                    }
                    .foregroundStyle(selected ? .white : Palette.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14).fill(selected ? Palette.sky : Palette.card))
                    .background(RoundedRectangle(cornerRadius: 14).fill(selected ? Palette.sky.edge() : Palette.cardEdge).offset(y: 3))
                    .scaleEffect(selected ? 1.04 : 1)
                }
                .buttonStyle(.plain)
                .sensoryFeedback(.selection, trigger: selected)
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selection)
    }
}

/// Spanish heard outside the plan, e.g. on a bus or a walking tour (§2.7).
struct BonusInputSheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var minutes = 20

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle("Extra listening")
            Text("Podcasts, a tour in Spanish, a long conversation: it all counts toward your input hours.")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
            HStack {
                ForEach([10, 20, 30, 60], id: \.self) { value in
                    ChipButton(title: "\(value) min", isSelected: minutes == value) { minutes = value }
                }
            }
            NumberStepper(title: "Minutes", value: $minutes, range: 1...600, step: 5)
            Button("Log it") {
                model.logBonusInput(minutes: minutes)
                dismiss()
            }
            .buttonStyle(ChunkyButtonStyle(color: Palette.coral))
        }
        .padding(24)
        .background(Palette.background.ignoresSafeArea())
    }
}
