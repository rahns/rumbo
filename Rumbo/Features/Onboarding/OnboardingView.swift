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
        case welcome, language, name, sources, progress, canDo, placement, goal, feedback, habit
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
            Button(step == .habit ? "Let's go" : step == .welcome ? "Start"
                   : step == .feedback && draft.geminiKey.trimmingCharacters(in: .whitespaces).isEmpty ? "Skip for now" : "Continue") {
                advance()
            }
            .buttonStyle(ChunkyButtonStyle(color: step == .habit ? Palette.leaf : Palette.coral))
            .disabled(step == .sources && draft.sources.isEmpty)
            .padding(20)
        }
    }

    private func advance() {
        if step == .habit {
            if !draft.geminiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { GeminiKey.save(draft.geminiKey) }
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
        case .language: language
        case .name: name
        case .goal: goal
        case .sources: sources
        case .progress: progress
        case .canDo: canDo
        case .placement: placement
        case .feedback: feedback
        case .habit: habit
        }
    }

    private var welcome: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 40)
            // Pico introduces himself, so new learners know who the toucan is.
            PicoSpeechBubble(text: "¡Hola! I'm Pico 👋 I'll turn the language learning you already do into one simple plan each day, and cheer you on.")
                .padding(.horizontal, 12)
            PicoBadge(size: 110)
            Text("¿Rumbo a dónde?")
                .font(.rounded(.largeTitle, weight: .black))
                .foregroundStyle(Palette.ink)
            Text("Rumbo turns the apps, courses and shows you already use into one plan, and tells you exactly what to do each day.")
                .font(.rounded(.title3, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.secondaryText)
            Text("Setting up takes about two minutes.")
                .font(.rounded(.subheadline, weight: .semibold))
                .foregroundStyle(Palette.coral)
            Button("Restore from a backup") { importing = true }
                .font(.rounded(.subheadline, weight: .bold))
                .foregroundStyle(Palette.secondaryText)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    /// What's being learned. Everything after this step follows the choice: the sources offered, the hours
    /// each level needs, and the app's wording.
    private var language: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepTitle("What are you learning?")
            Text("Rumbo builds your plan around the best sources for that language.")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
            ForEach(LanguagePack.all) { pack in
                let chosen = draft.languageCode == pack.code
                Button {
                    draft.languageCode = pack.code
                } label: {
                    HStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(pack.name).font(.rounded(.headline, weight: .bold))
                            Text(pack.nativeName).font(.rounded(.caption, weight: .medium)).foregroundStyle(Palette.secondaryText)
                        }
                        .foregroundStyle(Palette.ink)
                        Spacer(minLength: 0)
                        Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                            .font(.title)
                            .foregroundStyle(chosen ? Palette.leaf : Palette.secondaryText)
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(chosen ? "\(pack.name), chosen" : pack.name)
            }
            ForEach(LanguagePack.upcoming, id: \.self) { name in
                HStack {
                    Text(name).font(.rounded(.headline, weight: .bold))
                    Spacer()
                    Text("Coming soon").font(.rounded(.caption, weight: .bold))
                }
                .foregroundStyle(Palette.secondaryText)
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card.opacity(0.5)))
            }
        }
        .sensoryFeedback(.selection, trigger: draft.languageCode)
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
                       currentHours: draft.trainingHours, band: draft.placement.band)
        }
    }

    private var sources: some View {
        VStack(alignment: .leading, spacing: 14) {
            StepTitle("Which do you use?")
            Text("Tick what you use; Rumbo fills the time with those. Not sure what one is? Tap it.")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
            ForEach(draft.pack.roles, id: \.self) { source in
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
            let pack = draft.pack
            if draft.importsHours, let graded = pack.graded {
                RaisedCard(accent: Palette.coral) {
                    VStack(alignment: .leading, spacing: 10) {
                        SourceHeading(source: .gradedVideo)
                        NumberStepper(title: "Total hours watched", value: $draft.dreamingHours, range: 0...3000, step: 5)
                        NumberStepper(title: "Difficulty you're watching: \(draft.dreamingDifficultyLow)–\(draft.dreamingDifficultyLow + graded.windowWidth)",
                                      value: $draft.dreamingDifficultyLow,
                                      range: graded.scale.lowerBound...(graded.scale.upperBound - graded.windowWidth), step: 1)
                    }
                }
            } else {
                RaisedCard(accent: Palette.coral) {
                    NumberStepper(title: "Hours of \(pack.name) you've listened to or watched (roughly)", value: $draft.otherListeningHours, range: 0...3000, step: 10)
                }
            }
            if draft.sources.contains(.audioCourse), let course = pack.course {
                RaisedCard(accent: Palette.leaf) {
                    VStack(alignment: .leading, spacing: 10) {
                        SourceHeading(source: .audioCourse)
                        NumberStepper(title: "Last track finished", value: $draft.languageTransferLastTrack, range: 0...course.tracks, step: 1)
                    }
                }
            }
            if draft.sources.contains(.drillApp), let drill = pack.drill {
                RaisedCard(accent: Palette.leaf) {
                    VStack(alignment: .leading, spacing: 10) {
                        SourceHeading(source: .drillApp)
                        NumberStepper(title: "Section", value: $draft.duolingoSection, range: drill.sections, step: 1)
                        NumberStepper(title: "Unit", value: $draft.duolingoUnit, range: drill.units, step: 1)
                    }
                }
            }
            if draft.sources.contains(.learnerSeries), let series = pack.series {
                RaisedCard(accent: Palette.coral) {
                    VStack(alignment: .leading, spacing: 10) {
                        SourceHeading(source: .learnerSeries)
                        NumberStepper(title: "Episodes watched", value: $draft.extraEpisodesWatched, range: 0...series.episodes, step: 1)
                    }
                }
            }
        }
    }

    private var canDo: some View {
        let statements = draft.canDoStatements
        return VStack(alignment: .leading, spacing: 20) {
            StepTitle("Can you do this in \(draft.pack.name)?")
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
                    Button(draft.pack.phrases.notYet) { answer(statement.text, false) }
                        .buttonStyle(ChunkySecondaryButtonStyle())
                    Button(draft.pack.phrases.yes) { answer(statement.text, true) }
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
        let yes = draft.canDoAnswers.values.filter { $0 }.count
        let base = "\(Int(draft.inputHours)) hours of listening (≈ \(Int(draft.trainingHours)) training hours, since listening is \(Int(Band.listeningShare * 100))% of Rumbo's mix) and \(yes) of \(draft.canDoStatements.count) can-dos"
        switch result.adjustment {
        case 1: return "\(base). You're ahead of your hours, so you start one level up."
        case -1: return "\(base). Rumbo starts you one level lower so the plan feels comfortable."
        default: return "\(base)."
        }
    }

    private var feedback: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle("Better writing feedback")
            Text("Pico can check your writing with Google's Gemini, for free, using your own API key. It catches more than the basic checker and explains each mistake. You can also do this later in Settings.")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
            GeminiKeySetup(key: $draft.geminiKey)
        }
    }

    private var habit: some View {
        VStack(alignment: .leading, spacing: 18) {
            StepTitle("When should Pico remind you?")
            Text("Pick the time you usually have for \(draft.pack.name). A regular time makes the habit stick.")
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
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
            Text("Your weekly goal resets at the start of each week.")
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
            Text(ActiveLanguage.pack.levelName(band))
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
    @State private var showingInfo = false

    var body: some View {
        HStack(spacing: 14) {
            // The source itself opens what it is; the tick on the right switches it on or off.
            Button {
                showingInfo = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: SourceCopy.symbol(source))
                        .font(.title3.weight(.bold))
                        .foregroundStyle(isOn ? .white : Palette.secondaryText)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 12).fill(isOn ? Palette.coral : Palette.lilac))
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 5) {
                            Text(SourceCopy.name(source)).font(.rounded(.headline, weight: .bold))
                            Image(systemName: "info.circle")
                                .font(.rounded(.caption, weight: .bold))
                                .foregroundStyle(Palette.secondaryText)
                        }
                        Text(SourceCopy.role(source)).font(.rounded(.caption, weight: .medium)).foregroundStyle(Palette.secondaryText)
                    }
                    .foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows what \(SourceCopy.name(source)) is")
            Button {
                isOn.toggle()
            } label: {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.title)
                    .foregroundStyle(isOn ? Palette.leaf : Palette.secondaryText)
                    .padding(4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isOn ? "Using \(SourceCopy.name(source))" : "Not using \(SourceCopy.name(source))")
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16).fill(Palette.card))
        .sensoryFeedback(.selection, trigger: isOn)
        .sheet(isPresented: $showingInfo) { SourceInfoSheet(source: source) }
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

/// How the language being learned names each source (`LanguagePack.sources`).
enum SourceCopy {
    private static func info(_ source: SourceKind) -> SourceInfo? { ActiveLanguage.pack.sources[source] }

    static func name(_ source: SourceKind) -> String { info(source)?.name ?? "" }
    static func role(_ source: SourceKind) -> String { info(source)?.role ?? "" }
    static func symbol(_ source: SourceKind) -> String { info(source)?.symbol ?? "questionmark.circle" }
}

/// A big speech bubble with its tail pointing down at Pico, in a fixed dark ink on white so it reads in both modes.
struct PicoSpeechBubble: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.rounded(.headline, weight: .bold))
            .foregroundStyle(Palette.inkOnBright)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 14)
            .padding(.horizontal, 18)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white))
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Palette.cardEdge).offset(y: 4))
            .overlay(alignment: .bottom) {
                Triangle()
                    .fill(.white)
                    .frame(width: 22, height: 12)
                    .offset(y: 11)
            }
            .padding(.bottom, 10)
    }
}
