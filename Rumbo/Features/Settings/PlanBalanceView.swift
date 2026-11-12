import RumboCore
import SwiftUI

/// Settings → Plan balance (shown once "Custom plan balance" is on): the learner's own split of the day's
/// practice between listening, speaking & writing, grammar & vocab and fluency, one slider per strand.
/// Moving one scales the others so it always adds up to 100%. See docs/03-experience.md "Settings".
struct PlanBalanceView: View {
    @Environment(AppModel.self) private var model
    /// The split being edited, saved when a slider is let go (so today's plan isn't rebuilt on every step).
    @State private var draft: StrandBalance?

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
            draft = profile.strandBalance ?? StrandBalance(band: profile.band)
        }
    }

    @ViewBuilder
    private func sections(_ profile: LearnerProfile) -> some View {
        let standard = StrandBalance(band: profile.band)
        let balance = draft ?? profile.strandBalance ?? standard
        let learner = model.snapshot(for: profile)
        let blocked = Self.order.filter { !learner.canPlan($0) }
        Section {
            BalanceBar(balance: balance, order: Self.order)
                .padding(.vertical, 4)
            ForEach(Self.order, id: \.self) { strand in
                StrandSliderRow(strand: strand, percent: balance[strand], enabled: true,
                                warning: blocked.contains(strand) && balance[strand] > 0
                                    ? "Nothing for this can be planned right now (its sources are off), so its share goes to the others."
                                    : nil) { value in
                    var updated = balance
                    updated.set(strand, to: value)
                    if updated != draft { Haptics.tap(.light, intensity: 0.6) }
                    draft = updated
                } onRelease: {
                    save(profile)
                }
            }
        } footer: {
            Text("Move one and the others make room, keeping their proportions, so it always adds up to 100%. A type at 0% gets no cards."
                 + (blocked.contains { balance[$0] > 0 } && Self.order.allSatisfy { blocked.contains($0) || balance[$0] == 0 }
                    ? " Everything is on types that can't be planned right now, so your plans use the default balance for the rest until you turn a source back on."
                    : ""))
        }

        Section {
            Button("Reset to the default balance", systemImage: "arrow.counterclockwise") {
                withAnimation(.snappy) { draft = standard }
                save(profile)
            }
            .disabled(balance == standard)
        }

        Section("About the balance") {
            explanation("What this does", "Each day's plan picks its cards and minutes so your practice over the past week moves toward this split. Classes/tutoring, the daily warm-up, the mistake review and travel missions are planned as usual and count toward it.")
            explanation("The default for your level (\(profile.band.rawValue))", Self.order.map { "\($0.label) \(standard[$0])%" }.joined(separator: " · "))
            explanation("Why it's recommended", "It follows research on the four strands of language learning. Understanding lots of \(profile.pack.name) is what moves your level most, so listening stays at about half your time. Grammar & vocab gives you a head start early on and shrinks as the courses finish; speaking & writing grows as you level up; a little fluency practice makes what you already know quicker. The default shifts by itself as your level changes, while a custom balance stays as you set it. Listening below about 40% tends to slow progress.")
        }
    }

    private func explanation(_ title: String, _ text: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.rounded(.subheadline, weight: .black))
                .foregroundStyle(Palette.ink)
            Text(text)
                .font(.rounded(.subheadline, weight: .medium))
                .foregroundStyle(Palette.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func save(_ profile: LearnerProfile) {
        guard let draft, profile.strandBalance != draft else { return }
        profile.strandBalance = draft
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
    /// Why this share can't be used right now, if it can't.
    let warning: String?
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
            if let warning {
                Label(warning, systemImage: "exclamationmark.triangle.fill")
                    .font(.rounded(.caption, weight: .semibold))
                    .foregroundStyle(Palette.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}
