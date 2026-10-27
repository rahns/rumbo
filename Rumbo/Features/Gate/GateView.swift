import RumboCore
import SwiftUI

/// Level-up check (§2.1 "Promotion"): the next band's 10 can-do statements, pass at 7.
struct GateView: View {
    /// Practice mode (from Diagnostics): the full flow, but the result isn't saved.
    var isPractice = false

    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var stage = Stage.intro
    @State private var index = 0
    @State private var yesCount = 0
    @State private var confetti = 0

    enum Stage: Equatable {
        case intro, questions, passed, notYet
    }

    /// Fixed when the check opens: after passing, the profile's band already is this one.
    @State private var next: Band = .a2_2
    private var statements: [String] { CanDo.statements(for: next) }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            VStack(spacing: 0) {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.rounded(.headline, weight: .heavy))
                            .foregroundStyle(Palette.secondaryText)
                            .padding(8)
                    }
                    .accessibilityLabel("Close")
                    if stage == .questions {
                        ChunkyProgressBar(value: Double(index) / Double(statements.count), color: Palette.sun)
                    }
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                Group {
                    switch stage {
                    case .intro: intro
                    case .questions: questions
                    case .passed: passed
                    case .notYet: notYet
                    }
                }
                .padding(20)
                .frame(maxHeight: .infinity)
                .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .opacity))
            }
            ConfettiView(trigger: confetti)
        }
        .onAppear {
            let band = model.profile?.band ?? .a2_1
            next = band.next ?? band
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.8), value: stage)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: index)
    }

    private var intro: some View {
        VStack(spacing: 20) {
            Spacer()
            PicoView(mood: .hovering, size: 120)
            Text("Ready for \(next.label)?")
                .font(.rounded(.largeTitle, weight: .black))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            Text("You've reached \(Int(next.hoursThreshold)) training hours. Answer 10 quick questions honestly. Seven \"¡Sí!\" and you level up.")
                .font(.rounded(.body, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Let's check") { stage = .questions }
                .buttonStyle(ChunkyButtonStyle(color: Palette.sun, foreground: Palette.inkOnBright))
        }
    }

    private var questions: some View {
        VStack(alignment: .leading, spacing: 20) {
            StepTitle("Can you do this in Spanish?")
            if index < statements.count {
                RaisedCard(accent: Palette.sun) {
                    Text(statements[index])
                        .font(.rounded(.title2, weight: .bold))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(minHeight: 140, alignment: .topLeading)
                }
                .id(index)
                .transition(.asymmetric(insertion: .scale(scale: 0.9).combined(with: .opacity), removal: .move(edge: .leading).combined(with: .opacity)))
            }
            Spacer()
            HStack(spacing: 12) {
                Button("Todavía no") { answer(false) }
                    .buttonStyle(ChunkySecondaryButtonStyle())
                Button("¡Sí!") { answer(true) }
                    .buttonStyle(ChunkyButtonStyle(color: Palette.leaf))
            }
        }
    }

    private var passed: some View {
        VStack(spacing: 20) {
            Spacer()
            PicoView(mood: .proud, size: 130, celebrate: confetti)
            Text("¡Felicidades!")
                .font(.rounded(.largeTitle, weight: .black))
                .foregroundStyle(Palette.ink)
            BandBadge(band: next)
            Text("Your plan now has a bit more speaking and writing, and a little less study. That's how it grows with you.")
                .font(.rounded(.body, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            Button("¡Vamos!") { dismiss() }
                .buttonStyle(ChunkyButtonStyle(color: Palette.leaf))
        }
        .sensoryFeedback(.success, trigger: stage)
    }

    private var notYet: some View {
        VStack(spacing: 20) {
            Spacer()
            PicoView(mood: .hovering, size: 110)
            Text("Not yet, and that's fine")
                .font(.rounded(.title, weight: .black))
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.center)
            Text("\(yesCount) of \(statements.count). Keep following the plan; Rumbo will offer the check again in \(LevelGate.retryDays) days.")
                .font(.rounded(.body, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
                .multilineTextAlignment(.center)
            Spacer()
            Button("Back to my path") { dismiss() }
                .buttonStyle(ChunkyButtonStyle())
        }
    }

    private func answer(_ yes: Bool) {
        if yes { yesCount += 1 }
        index += 1
        guard index >= statements.count else { return }
        if LevelGate.passes(yesAnswers: yesCount) {
            if !isPractice { model.passGate() }
            stage = .passed
            confetti += 1
        } else {
            if !isPractice { model.failGate() }
            stage = .notYet
        }
    }
}
