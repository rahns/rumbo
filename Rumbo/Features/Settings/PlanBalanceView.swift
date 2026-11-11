import RumboCore
import SwiftUI

/// Settings → Plan balance: how the day's practice is split between listening, speaking & writing,
/// grammar & vocab and fluency. Rumbo's split (by level) or the learner's own, set with one slider per
/// strand; moving one scales the others so it always adds up to 100%. See docs/03-experience.md "Settings".
struct PlanBalanceView: View {
    @Environment(AppModel.self) private var model
    /// The split being edited, saved when a slider is let go (so today's plan isn't rebuilt on every step).
    @State private var draft: StrandBalance?
    @State private var custom = false

    /// Bar and rows in the order the plan's cards come in.
    private static let order: [Strand] = [.input, .languageFocused, .output, .fluency]

    var body: some View {
        Form {
            if let profile = model.profile {
                Group { sections(profile) }
                    .rumboRows()
            }
        }
        .rumboListBackground()
        .navigationTitle("Plan balance")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            guard let profile = model.profile else { return }
            custom = profile.strandBalance != nil
            draft = profile.strandBalance ?? StrandBalance(band: profile.band)
        }
    }

    @ViewBuilder
    private func sections(_ profile: LearnerProfile) -> some View {
        let balance = custom ? (draft ?? StrandBalance(band: profile.band)) : StrandBalance(band: profile.band)
        Section {
            Picker("Balance", selection: Binding(get: { custom }, set: { setCustom($0, profile: profile) })) {
                Text("Rumbo's").tag(false)
                Text("Custom").tag(true)
            }
            .pickerStyle(.segmented)
            BalanceBar(balance: balance, order: Self.order)
                .padding(.vertical, 4)
        } footer: {
            Text(custom
                 ? "Your own split, used for every day's plan until you switch back. Classes/tutoring, the Duolingo warm-up and travel missions are planned as usual."
                 : "Rumbo's split for your level (\(profile.band.rawValue)), from language-learning research: mostly listening, with the rest shifting from grammar toward speaking as you level up.")
        }

        Section {
            ForEach(Self.order, id: \.self) { strand in
                StrandSliderRow(strand: strand, percent: balance[strand], enabled: custom) { value in
                    var updated = balance
                    updated.set(strand, to: value)
                    if updated != draft { Haptics.tap(.light, intensity: 0.6) }
                    draft = updated
                } onRelease: {
                    save(profile)
                }
            }
        } footer: {
            if custom {
                Text("Move one and the others make room, keeping their proportions. A type at 0% gets no cards. Listening below about 40% tends to slow progress: understanding lots of Spanish is what moves your level most.")
            } else {
                Text("Choose Custom to set your own split.")
            }
        }

        if custom {
            Section {
                Button("Go back to Rumbo's balance", systemImage: "arrow.counterclockwise") {
                    setCustom(false, profile: profile)
                }
            }
        }
    }

    private func setCustom(_ on: Bool, profile: LearnerProfile) {
        withAnimation(.snappy) {
            custom = on
            if on && draft == nil { draft = StrandBalance(band: profile.band) }
            if !on { draft = StrandBalance(band: profile.band) }
        }
        save(profile)
    }

    private func save(_ profile: LearnerProfile) {
        let value = custom ? draft : nil
        guard profile.strandBalance != value else { return }
        profile.strandBalance = value
        model.save()
        model.replanTodayIfNotStarted()
    }
}

/// The split as one bar in the strands' colours, with each share's percentage inside it when it fits.
private struct BalanceBar: View {
    let balance: StrandBalance
    let order: [Strand]

    var body: some View {
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(order.filter { balance[$0] > 0 }, id: \.self) { strand in
                    let width = max(0, (proxy.size.width - 6) * CGFloat(balance[strand]) / 100)
                    ZStack {
                        Rectangle().fill(strand.color)
                        if width >= 34 {
                            Text("\(balance[strand])%")
                                .font(.rounded(.caption, weight: .black))
                                .foregroundStyle(.white)
                                .monospacedDigit()
                                .contentTransition(.numericText())
                        }
                    }
                    .frame(width: width)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .frame(height: 34)
        .animation(.snappy, value: balance)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(order.map { "\($0.label) \(balance[$0]) percent" }.joined(separator: ", "))
    }
}

/// One strand: its colour, name, what counts toward it, its share, and a slider in its colour.
private struct StrandSliderRow: View {
    let strand: Strand
    let percent: Int
    let enabled: Bool
    let onChange: (Int) -> Void
    let onRelease: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Circle().fill(strand.color).frame(width: 12, height: 12)
                VStack(alignment: .leading, spacing: 2) {
                    Text(strand.label)
                        .font(.rounded(.body, weight: .bold))
                        .foregroundStyle(Palette.ink)
                    Text(strand.detail)
                        .font(.rounded(.caption, weight: .medium))
                        .foregroundStyle(Palette.secondaryText)
                }
                Spacer(minLength: 8)
                Text("\(percent)%")
                    .font(.rounded(.title3, weight: .black))
                    .foregroundStyle(enabled ? strand.color : Palette.secondaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: percent)
            }
            Slider(value: Binding(get: { Double(percent) }, set: { onChange(Int($0.rounded())) }),
                   in: 0...100, step: Double(StrandBalance.step)) { editing in
                if !editing { onRelease() }
            }
            .tint(strand.color)
            .disabled(!enabled)
            .opacity(enabled ? 1 : 0.45)
        }
        .padding(.vertical, 4)
    }
}
