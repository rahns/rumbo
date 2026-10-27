import RumboCore
import SwiftUI

/// First launch, about 2 minutes. See docs/03-experience.md §3.4.
struct OnboardingView: View {
    let onFinish: (OnboardingDraft) -> Void

    @Environment(AppModel.self) private var model
    @State private var draft = OnboardingDraft()
    @State private var importing = false
    @State private var restoreError: String?
    @State private var step = Step.welcome
    @State private var canDoIndex = 0

    enum Step: Int, CaseIterable {
        // The goal comes after placement, so the weekly goal and target date can be worked out from your hours.
        case welcome, name, sources, progress, canDo, placement, goal, habit
    }

    var body: some View {
        VStack(spacing: 0) {
            if step != .welcome {
                header
            }
            ScrollView {
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(step)
                    .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                            removal: .move(edge: .leading).combined(with: .opacity)))
            }
            .scrollBounceBehavior(.basedOnSize)
            footer
        }
        .background(Palette.background.ignoresSafeArea())
        .animation(.spring(response: 0.45, dampingFraction: 0.85), value: step)
        .sheet(isPresented: $importing) {
            BackupImportPicker { result in
                importing = false
                switch result {
                case .success(let data):
                    do {
                        try withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                            try model.restore(from: data)
                        }
                    } catch {
                        restoreError = error.localizedDescription
                    }
                case .failure(let error): restoreError = error.localizedDescription
                case nil: break
                }
            }
            .ignoresSafeArea()
        }
        .alert(restoreError ?? "", isPresented: Binding(get: { restoreError != nil }, set: { if !$0 { restoreError = nil } })) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: Chrome

    private var header: some View {
        HStack(spacing: 12) {
            Button {
                go(to: Step(rawValue: step.rawValue - 1) ?? .welcome)
            } label: {
                Image(systemName: "chevron.left")
                    .font(.rounded(.headline, weight: .heavy))
                    .foregroundStyle(Palette.secondaryText)
            }
            .accessibilityLabel("Back")
            ChunkyProgressBar(value: Double(step.rawValue) / Double(Step.allCases.count - 1), color: Palette.leaf)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var footer: some View {
        if step != .canDo {
            Button(step == .habit ? "Let's go" : step == .welcome ? "Start" : "Continue") {
                advance()
            }
            .buttonStyle(ChunkyButtonStyle(color: step == .habit ? Palette.leaf : Palette.coral))
            .disabled(step == .sources && draft.sources.isEmpty)
            .padding(20)
        }
    }

    private func advance() {
        if step == .habit {
            onFinish(draft)
            return
        }
        if step == .progress {
            canDoIndex = 0
            draft.canDoAnswers = [:]
        }
        go(to: Step(rawValue: step.rawValue + 1) ?? .habit)
    }

    private func go(to newStep: Step) {
        if newStep == .goal { draft.prepareGoal() }
        step = newStep
    }

    // MARK: Steps

    @ViewBuilder
    private var content: some View {
        switch step {
        case .welcome: welcome
        case .name: name
        case .goal: goal
        case .sources: sources
        case .progress: progress
        case .canDo: canDo
        case .placement: placement
        case .habit: habit
        }
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 80)
            PicoBadge(size: 110)
            Text("¿Rumbo a dónde?")
                .font(.rounded(.largeTitle, weight: .black))
                .foregroundStyle(Palette.ink)
            Text("Rumbo turns the Spanish sources you already use into one plan, and tells you exactly what to do each day.")
                .font(.rounded(.title3, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.secondaryText)
            Text("Hi, I'm Pico. This takes about two minutes.")
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.coral)
            Button("Restore from a backup") { importing = true }
                .font(.rounded(.subheadline, weight: .bold))
                .foregroundStyle(Palette.secondaryText)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var name: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepTitle("What should I call you?")
            TextField("Your name (optional)", text: $draft.name)
                .textContentType(.givenName)
                .font(.rounded(.title3, weight: .semibold))
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 14).fill(Palette.card))
        }
    }

    private var goal: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle("Where are you heading?")
            Text("Pick your goal, then either how much time you'll give it each week or when you want to get there. You can change this any time in Settings → Goal.")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
            GoalEditor(goal: $draft.goal, weeklyMinutes: $draft.weeklyGoalMinutes, targetDate: $draft.targetDate,
                       currentHours: draft.inputHours, band: draft.placement.band)
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepTitle("Which do you use?")
            Text("Switch off anything you don't use. Rumbo fills the time with the others.")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
            ForEach(SourceKind.allCases, id: \.self) { source in
                SourceToggleRow(source: source, isOn: Binding(
                    get: { draft.sources.contains(source) },
                    set: { on in
                        if on { draft.sources.insert(source) } else { draft.sources.remove(source) }
                    }
                ))
            }
        }
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 16) {
            StepTitle("Where are you now?")
            Text("Check each app for these numbers. They're what Rumbo uses to place you.")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
            if draft.sources.contains(.dreamingSpanish) {
                RaisedCard(accent: Palette.coral) {
                    VStack(alignment: .leading, spacing: 10) {
                        SourceHeading(source: .dreamingSpanish)
                        NumberStepper(title: "Total hours watched", value: $draft.dreamingHours, range: 0...3000, step: 5)
                        NumberStepper(title: "Difficulty you're watching: \(draft.dreamingDifficultyLow)–\(draft.dreamingDifficultyLow + LearnerProfile.dreamingRangeWidth)",
                                      value: $draft.dreamingDifficultyLow, range: 0...(100 - LearnerProfile.dreamingRangeWidth), step: 1)
                    }
                }
            } else {
                RaisedCard(accent: Palette.coral) {
                    NumberStepper(title: "Hours of Spanish you've listened to or watched (roughly)", value: $draft.otherListeningHours, range: 0...3000, step: 10)
                }
            }
            if draft.sources.contains(.languageTransfer) {
                RaisedCard(accent: Palette.leaf) {
                    VStack(alignment: .leading, spacing: 10) {
                        SourceHeading(source: .languageTransfer)
                        NumberStepper(title: "Last track finished", value: $draft.languageTransferLastTrack, range: 0...Course.languageTransferTracks, step: 1)
                    }
                }
            }
            if draft.sources.contains(.duolingo) {
                RaisedCard(accent: Palette.leaf) {
                    VStack(alignment: .leading, spacing: 10) {
                        SourceHeading(source: .duolingo)
                        NumberStepper(title: "Section", value: $draft.duolingoSection, range: 1...10, step: 1)
                        NumberStepper(title: "Unit", value: $draft.duolingoUnit, range: 1...300, step: 1)
                    }
                }
            }
            if draft.sources.contains(.extraEnEspanol) {
                RaisedCard(accent: Palette.coral) {
                    VStack(alignment: .leading, spacing: 10) {
                        SourceHeading(source: .extraEnEspanol)
                        NumberStepper(title: "Episodes watched", value: $draft.extraEpisodesWatched, range: 0...Course.extraEpisodes, step: 1)
                    }
                }
            }
        }
    }

    private var canDo: some View {
        let statements = draft.canDoStatements
        return VStack(alignment: .leading, spacing: 20) {
            StepTitle("Can you do this in Spanish?")
            Text("\(min(canDoIndex + 1, statements.count)) of \(statements.count)")
                .font(.rounded(.subheadline, weight: .bold))
                .foregroundStyle(Palette.secondaryText)
            if canDoIndex < statements.count {
                let statement = statements[canDoIndex]
                RaisedCard(accent: Palette.sky) {
                    Text(statement.text)
                        .font(.rounded(.title2, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 140, alignment: .topLeading)
                }
                .id(statement.text)
                .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))
                HStack(spacing: 12) {
                    Button("Todavía no") { answer(statement.text, false) }
                        .buttonStyle(ChunkySecondaryButtonStyle())
                    Button("¡Sí!") { answer(statement.text, true) }
                        .buttonStyle(ChunkyButtonStyle(color: Palette.leaf))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: canDoIndex)
    }

    private func answer(_ statement: String, _ yes: Bool) {
        draft.canDoAnswers[statement] = yes
        canDoIndex += 1
        if canDoIndex >= draft.canDoStatements.count {
            go(to: .placement)
        }
    }

    private var placement: some View {
        let result = draft.placement
        return VStack(spacing: 18) {
            Spacer(minLength: 30)
            PicoBadge(size: 80)
            Text("You're starting as")
                .font(.rounded(.title3, weight: .semibold))
                .foregroundStyle(Palette.secondaryText)
            BandBadge(band: result.band)
                .transition(.scale.combined(with: .opacity))
            Text(placementReason(result))
                .font(.rounded(.subheadline, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.secondaryText)
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.success, trigger: step)
    }

    private func placementReason(_ result: Placement.Result) -> String {
        let hours = Int(draft.inputHours)
        let yes = draft.canDoAnswers.values.filter { $0 }.count
        let base = "\(hours) hours of input and \(yes) of \(draft.canDoStatements.count) can-dos"
        switch result.adjustment {
        case 1: return "\(base). You're ahead of your hours, so you start one level up."
        case -1: return "\(base). Rumbo starts you one level lower so the plan feels comfortable."
        default: return "\(base)."
        }
    }

    private var habit: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle("When will you usually study?")
            Text("Tying Spanish to something you already do makes it stick.")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
            FlowChips(items: OnboardingDraft.habitCues, selection: $draft.habitCue)
            Toggle(isOn: $draft.reminderEnabled.animation()) {
                Text("Daily reminder").font(.rounded(.body, weight: .semibold))
            }
            .tint(Palette.leaf)
            if draft.reminderEnabled {
                DatePicker("Time", selection: $draft.reminderTime, displayedComponents: .hourAndMinute)
                    .font(.rounded(.body, weight: .semibold))
            }
            StepTitle("Your week starts on")
            HStack(spacing: 10) {
                ChipButton(title: "Monday", isSelected: !draft.weekStartsOnSunday) { draft.weekStartsOnSunday = false }
                ChipButton(title: "Sunday", isSelected: draft.weekStartsOnSunday) { draft.weekStartsOnSunday = true }
            }
            Text("Your weekly goal and streak freezes reset at the start of each week.")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
        }
        .task(id: draft.reminderEnabled) {
            if draft.reminderEnabled {
                _ = await Reminders.requestPermission()
            }
        }
    }
}

// MARK: - Pieces

struct StepTitle: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.rounded(.title2, weight: .black))
            .foregroundStyle(Palette.ink)
    }
}

struct BandBadge: View {
    let band: Band

    var body: some View {
        VStack(spacing: 4) {
            Text(band.label)
                .font(.rounded(.largeTitle, weight: .black))
            Text(band.rawValue)
                .font(.rounded(.headline, weight: .heavy))
                .opacity(0.85)
        }
        .foregroundStyle(.white)
        .padding(.vertical, 18)
        .padding(.horizontal, 36)
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.coral))
        .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.coral.edge()).offset(y: 5))
    }
}

struct SourceHeading: View {
    let source: SourceKind

    var body: some View {
        Label(SourceCopy.name(source), systemImage: SourceCopy.symbol(source))
            .font(.rounded(.headline, weight: .heavy))
            .foregroundStyle(Palette.ink)
    }
}

struct SourceToggleRow: View {
    let source: SourceKind
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: SourceCopy.symbol(source))
                    .font(.title3.weight(.bold))
                    .foregroundStyle(isOn ? .white : Palette.secondaryText)
                    .frame(width: 44, height: 44)
                    .background(RoundedRectangle(cornerRadius: 12).fill(isOn ? Palette.coral : Palette.lilac))
                VStack(alignment: .leading, spacing: 2) {
                    Text(SourceCopy.name(source)).font(.rounded(.headline, weight: .bold))
                    Text(SourceCopy.role(source)).font(.rounded(.caption, weight: .medium)).foregroundStyle(Palette.secondaryText)
                }
                .foregroundStyle(Palette.ink)
                Spacer()
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(isOn ? Palette.leaf : Palette.secondaryText)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isOn)
    }
}

struct NumberStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    let step: Int

    var body: some View {
        HStack {
            Text(title)
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.secondaryText)
            Spacer()
            TextField("0", value: $value, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .font(.rounded(.title3, weight: .heavy))
                .foregroundStyle(Palette.ink)
                .frame(width: 70)
                .onChange(of: value) { _, new in value = min(max(new, range.lowerBound), range.upperBound) }
            Stepper("", value: $value, in: range, step: step)
                .labelsHidden()
        }
    }
}

struct FlowChips: View {
    let items: [String]
    @Binding var selection: String

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), alignment: .leading)], alignment: .leading, spacing: 10) {
            ForEach(items, id: \.self) { item in
                ChipButton(title: item, isSelected: selection == item) { selection = item }
            }
        }
    }
}

enum SourceCopy {
    static func name(_ source: SourceKind) -> String {
        switch source {
        case .dreamingSpanish: "Dreaming Spanish"
        case .languageTransfer: "Language Transfer"
        case .extraEnEspanol: "Extra en Español"
        case .duolingo: "Duolingo"
        case .writing: "Writing"
        case .tandem: "Tandem partner"
        case .suggestedContent: "Suggested shows & podcasts"
        }
    }

    static func role(_ source: SourceKind) -> String {
        switch source {
        case .dreamingSpanish: "Your main listening engine"
        case .languageTransfer: "Grammar skeleton, A2 to early B1"
        case .extraEnEspanol: "Sitcom with subtitles and shadowing"
        case .duolingo: "Short daily warm-up"
        case .writing: "Short writing tasks in Rumbo"
        case .tandem: "I have a language exchange partner"
        case .suggestedContent: "Native content once a course runs out"
        }
    }

    static func symbol(_ source: SourceKind) -> String {
        switch source {
        case .dreamingSpanish: "play.tv.fill"
        case .languageTransfer: "headphones"
        case .extraEnEspanol: "film.fill"
        case .duolingo: "bolt.fill"
        case .writing: "pencil.and.scribble"
        case .tandem: "bubble.left.and.bubble.right.fill"
        case .suggestedContent: "sparkles.tv.fill"
        }
    }
}
