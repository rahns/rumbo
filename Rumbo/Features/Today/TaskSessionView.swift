import RumboCore
import SwiftData
import SwiftUI
import UIKit

/// Doing one task: instructions, a timer, a link into the source app, then logging.
struct TaskSessionView: View {
    let task: PlannedTaskRecord
    /// Opened from the Live Activity's Done button: go straight to logging.
    var startLogging = false

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var logging = false
    @State private var minutes = 0
    @State private var comprehension: ComprehensionTuner.Rating?
    @State private var trackRating: SourceProgress.TrackRating?
    @State private var tandemFeeling: String?
    @State private var writing = ""
    @State private var rewrite = ""
    @State private var feedback: CorrectionService.Result?
    @State private var addingCorrection = false
    @State private var ltNextTrack = 1
    @State private var duolingoSection = 1
    @State private var duolingoUnit = 1
    @State private var keyboardVisible = false
    @State private var confirmingFinish = false

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
        .onAppear {
            restoreDraft()
            if startLogging && !logging { beginLogging() }
        }
        // Writing is kept on the task as it's typed, so closing the screen never loses it.
        .onChange(of: writing) { _, text in task.draftText = text }
        .onChange(of: rewrite) { _, text in task.draftRewrite = text }
        .onChange(of: feedback) { _, result in task.draftFeedback = result.flatMap { try? JSONEncoder().encode($0) } }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in keyboardVisible = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in keyboardVisible = false }
    }

    private func restoreDraft() {
        guard isWriting, writing.isEmpty else { return }
        writing = task.draftText
        rewrite = task.draftRewrite
        feedback = task.draftFeedback.flatMap { try? JSONDecoder().decode(CorrectionService.Result.self, from: $0) }
    }

    // MARK: Pieces

    private var topBar: some View {
        HStack {
            Button {
                // Leaving without logging: the task stays started, but its timer leaves the Dynamic Island.
                model.leaveSession()
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
            if kind.strand == .input || kind == .ltTrack {
                PicoView(mood: .listening, size: 64)
            }
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
            TimerDial(task: task, color: color)
                .frame(maxWidth: .infinity)
            Button {
                model.togglePause()
            } label: {
                Label(task.isPaused ? "Resume" : "Pause", systemImage: task.isPaused ? "play.fill" : "pause.fill")
            }
            .buttonStyle(ChunkySecondaryButtonStyle(fullWidth: false))
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
            if kind == .writeGuided {
                GuidedWritingView(draft: $writing, rewrite: $rewrite, feedback: $feedback,
                                  band: model.profile?.band ?? .a2_1, prompt: task.prompt)
            } else if kind == .writeQuick {
                writingEditor
            } else if kind == .reviewMistakes {
                ReviewDeckView()
            }
            if kind == .contentWatch, let current = model.currentContent {
                Label("\(current.title) · \(current.whereToFind)", systemImage: "sparkles.tv.fill")
                    .font(.rounded(.subheadline, weight: .bold))
                    .foregroundStyle(Palette.secondaryText)
                if let url = current.url.flatMap(URL.init(string:)) {
                    Link(destination: url) {
                        Label("Open \(current.title)", systemImage: "arrow.up.forward.app.fill")
                    }
                    .buttonStyle(ChunkySecondaryButtonStyle())
                }
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
            VStack(alignment: .leading, spacing: 6) {
                RaisedCard {
                    NumberStepper(title: "Minutes spent", value: $minutes, range: 1...240, step: 1)
                }
                explanation("Counts toward your weekly goal, streak and level hours.")
            }
            if isWriting {
                let words = (rewrite.isEmpty ? writing : rewrite).split(whereSeparator: \.isWhitespace).count
                Label(kind == .writeGuided && feedback != nil
                      ? "Your writing (\(words) words) and its corrections are saved with this task. Each correction becomes a mistake-deck card."
                      : "Your writing (\(words) words) is saved with this task. Tap Back to keep working on it.",
                      systemImage: "doc.text.fill")
                    .font(.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(Palette.ink)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Palette.cream))
            }
            // Only questions whose answers change something are asked (docs/03-experience.md §3.3).
            if kind == .dsWatch {
                question("How much did you understand?",
                         explanation: "Rumbo looks at your last 5 answers: mostly \"Lost\" suggests easier videos, mostly \"Easy\" suggests harder ones.") {
                    ChoiceRow(options: [
                        (ComprehensionTuner.Rating.lost, "😵", "Lost"),
                        (.mostly, "🙂", "Mostly"),
                        (.easy, "😎", "Easy"),
                    ], selection: $comprehension)
                }
            }
            if kind == .ltTrack {
                question("Which track are you up to now?",
                         explanation: "Rumbo plans this track next. Did more than one? Move it on. Want to repeat one? Set it back.") {
                    RaisedCard {
                        HStack {
                            Text(ltNextTrack > Course.languageTransferTracks ? "Course finished 🎉" : "Track \(ltNextTrack)")
                                .font(.rounded(.title3, weight: .heavy))
                                .foregroundStyle(Palette.ink)
                                .contentTransition(.numericText())
                            Spacer()
                            Stepper("", value: $ltNextTrack, in: 1...(Course.languageTransferTracks + 1))
                                .labelsHidden()
                        }
                        .animation(.snappy, value: ltNextTrack)
                    }
                }
            }
            if kind == .duoLesson {
                question("Where are you in Duolingo now?",
                         explanation: "Keeps your place up to date, so the warm-up card shows where to pick up.") {
                    RaisedCard {
                        VStack(spacing: 10) {
                            NumberStepper(title: "Section", value: $duolingoSection, range: 1...10, step: 1)
                            NumberStepper(title: "Unit", value: $duolingoUnit, range: 1...300, step: 1)
                        }
                    }
                }
            }
            if kind == .tandemText {
                question("How did it feel?",
                         explanation: "Voice notes unlock once texting feels comfortable: your latest message needs to be Easy or OK.") {
                    ChoiceRow(options: [("easy", "😎", "Easy"), ("ok", "🙂", "OK"), ("hard", "😬", "Hard")], selection: $tandemFeeling)
                }
            }
            if kind.isTandemExchange {
                Button {
                    addingCorrection = true
                } label: {
                    Label("Save a correction from your partner", systemImage: "plus.bubble.fill")
                }
                .buttonStyle(ChunkySecondaryButtonStyle())
                .sheet(isPresented: $addingCorrection) {
                    AddCardSheet(origin: "tandem")
                        .presentationDetents([.medium, .large])
                }
            }
        }
    }

    private func question<Content: View>(_ title: String, explanation text: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.rounded(.headline, weight: .heavy))
                .foregroundStyle(Palette.ink)
            content()
            explanation(text)
        }
    }

    /// Small print under a question: what Rumbo does with the answer.
    private func explanation(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.rounded(.caption, weight: .semibold))
            .foregroundStyle(Palette.secondaryText)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private var bottomBar: some View {
        // While typing, only "Hide keyboard" sits above the keyboard; "I'm done" waits until it's down.
        if keyboardVisible && isWriting {
            HStack {
                Spacer()
                Button {
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                } label: {
                    Label("Hide keyboard", systemImage: "keyboard.chevron.compact.down")
                        .font(.rounded(.subheadline, weight: .heavy))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Palette.secondaryText)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        } else {
            Group {
                if logging {
                    HStack(spacing: 10) {
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { logging = false }
                        } label: {
                            Label("Back", systemImage: "chevron.left")
                        }
                        .buttonStyle(ChunkySecondaryButtonStyle(fullWidth: false))
                        Button("Save") { save() }
                            .buttonStyle(ChunkyButtonStyle(color: Palette.leaf))
                            .disabled(!canSave)
                    }
                } else {
                    Button("I'm done") {
                        if needsFinishConfirmation { confirmingFinish = true } else { beginLogging() }
                    }
                    .buttonStyle(ChunkyButtonStyle(color: color))
                }
            }
            .padding(20)
            .confirmationDialog(kind == .writeGuided && feedback == nil ? "Finish without checking?" : "Finish writing?",
                                isPresented: $confirmingFinish, titleVisibility: .visible) {
                if kind == .writeGuided && feedback == nil {
                    Button("Keep writing, I'll check it first") {}
                    Button("Finish without a check") { beginLogging() }
                } else {
                    Button("Finish and log it") { beginLogging() }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text(kind == .writeGuided && feedback == nil
                     ? "Tap \"Check my writing\" for Pico's corrections. Your text is kept either way."
                     : "Your text is kept and saved with this task when you log it.")
            }
        }
    }

    /// Writing tasks ask before moving on, so text is never left behind by accident.
    private var needsFinishConfirmation: Bool {
        isWriting && !writing.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSave: Bool {
        switch kind {
        case .dsWatch: comprehension != nil
        default: true
        }
    }

    // MARK: Actions

    private func beginLogging() {
        let elapsed = task.elapsed() / 60
        minutes = max(1, Int(elapsed.rounded()))
        if elapsed < 1 { minutes = task.minutesPlanned }
        duolingoSection = model.profile?.duolingoSection ?? 1
        duolingoUnit = model.profile?.duolingoUnit ?? 1
        // The track just done, plus one: finishing 13 suggests 14.
        if case .languageTransferTrack(let track) = task.detail {
            ltNextTrack = min(track + 1, Course.languageTransferTracks + 1)
        } else {
            ltNextTrack = (model.profile?.languageTransferLastTrack ?? 0) + 1
        }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { logging = true }
    }

    private func save() {
        model.complete(task, with: .init(
            minutes: minutes,
            comprehension: comprehension,
            trackRating: trackRating,
            tandemFeeling: tandemFeeling,
            writing: isWriting ? writing : nil,
            feedback: kind == .writeGuided ? feedback : nil,
            rewrite: kind == .writeGuided ? rewrite : nil,
            duolingoPosition: kind == .duoLesson ? (section: duolingoSection, unit: duolingoUnit) : nil,
            languageTransferNextTrack: kind == .ltTrack ? ltNextTrack : nil
        ))
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        dismiss()
    }
}

/// Big circular timer counting up against the planned minutes; freezes while paused.
struct TimerDial: View {
    let task: PlannedTaskRecord
    let color: Color

    private var plannedMinutes: Int { task.minutesPlanned }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let elapsed = task.elapsed(at: context.date)
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
                    Text(task.isPaused ? "Paused" : "of \(plannedMinutes) min")
                        .font(.rounded(.subheadline, weight: .bold))
                        .foregroundStyle(task.isPaused ? Palette.coral : Palette.secondaryText)
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
