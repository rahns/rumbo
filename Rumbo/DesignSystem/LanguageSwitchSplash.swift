import RumboCore
import SwiftUI

/// A brief full-screen moment when switching between two languages that are both set up
/// (Settings → Language): Pico swoops in onto a card showing the old language's flag, the card flips to
/// the new flag, Pico does a loop-de-loop, and "C'est parti !" (or "¡Vamos!") appears in the new language.
/// After a language is deleted, the old flag vanishes in a puff of smoke instead, and the new one pops in.
/// About two seconds; a tap ends it early. With Reduce Motion, the new flag simply fades in.
/// The data underneath switches straight away, so the screen behind is already the new language's.
struct LanguageSwitchSplash: View {
    let change: AppModel.LanguageSwitch
    let onFinish: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flipAngle: Double = 0
    @State private var showingNew = false
    @State private var picoIn = false
    @State private var celebrate = 0
    @State private var pulse = false
    @State private var textIn = false
    @State private var finished = false
    /// The deleted language's flag going up in smoke, then the gap before the new one pops in.
    @State private var poofed = false
    @State private var puffing = false
    @State private var newFlagIn = false

    private var from: LanguagePack { LanguagePack.pack(for: change.from) }
    private var to: LanguagePack { LanguagePack.pack(for: change.to) }

    var body: some View {
        ZStack {
            Palette.background.ignoresSafeArea()
            RadialGradient(colors: [Palette.sky.opacity(0.25), .clear], center: .center, startRadius: 10, endRadius: 420)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                ZStack {
                    // A ring that pulses out from the card as the new flag lands.
                    Circle()
                        .stroke(Palette.sun, lineWidth: 6)
                        .frame(width: 190, height: 190)
                        .scaleEffect(pulse ? 1.6 : 0.6)
                        .opacity(pulse ? 0 : 0.7)

                    if change.deleted {
                        // The old card swells, blurs and fades while puffs of smoke burst out; then the new one pops in.
                        card(from.flag)
                            .scaleEffect(poofed ? 1.35 : 1)
                            .blur(radius: poofed ? 14 : 0)
                            .opacity(poofed ? 0 : 1)
                        PuffCloud(bursting: puffing)
                        card(to.flag)
                            .scaleEffect(newFlagIn ? 1 : 0.2)
                            .opacity(newFlagIn ? 1 : 0)
                    } else {
                        card(showingNew ? to.flag : from.flag)
                            .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
                    }

                    // Pico perches on the card's top edge.
                    PicoView(mood: showingNew ? .cheering : .hovering, size: 96, celebrate: celebrate, reactsToTaps: false)
                        .offset(x: picoIn ? 0 : -320, y: -112)
                        .rotationEffect(.degrees(picoIn ? 0 : -25))
                }
                .frame(height: 260)

                VStack(spacing: 8) {
                    Text(to.phrases(for: change.toBand).letsGo)
                        .font(.rounded(.largeTitle, weight: .black))
                        .foregroundStyle(Palette.ink)
                    Text(change.deleted ? "\(from.name) deleted · back to \(to.name)" : "Now learning \(to.name)")
                        .font(.rounded(.title3, weight: .bold))
                        .foregroundStyle(Palette.secondaryText)
                }
                .multilineTextAlignment(.center)
                .opacity(textIn ? 1 : 0)
                .offset(y: textIn ? 0 : 16)
            }
            .padding(.horizontal, 24)
        }
        .contentShape(Rectangle())
        .onTapGesture { finish() }
        .sensoryFeedback(.success, trigger: showingNew)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Switched to \(to.name)")
        .accessibilityAddTraits(.isModal)
        .task { await play() }
    }

    private func card(_ flag: String) -> some View {
        Text(flag)
            .font(.system(size: 92))
            .frame(width: 170, height: 124)
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.card))
            .background(RoundedRectangle(cornerRadius: 26, style: .continuous).fill(Palette.cardEdge).offset(y: 6))
            .shadow(color: .black.opacity(0.12), radius: 14, y: 8)
    }

    private func play() async {
        if reduceMotion {
            showingNew = true
            poofed = true
            newFlagIn = true
            picoIn = true
            withAnimation(.easeOut(duration: 0.3)) { textIn = true }
            try? await Task.sleep(for: .seconds(1.3))
            finish()
            return
        }
        // Pico swoops in.
        withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) { picoIn = true }
        try? await Task.sleep(for: .seconds(0.45))
        if change.deleted {
            // Poof: the old flag goes up in smoke…
            withAnimation(.easeOut(duration: 0.35)) { poofed = true }
            withAnimation(.easeOut(duration: 0.6)) { puffing = true }
            try? await Task.sleep(for: .seconds(0.45))
            // …and after a beat the new one pops in.
            showingNew = true
            withAnimation(.spring(response: 0.45, dampingFraction: 0.55)) { newFlagIn = true }
            withAnimation(.easeOut(duration: 0.7)) { pulse = true }
            celebrate += 1
            try? await Task.sleep(for: .seconds(0.15))
            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { textIn = true }
            try? await Task.sleep(for: .seconds(1.4))
            finish()
            return
        }
        // The card turns edge-on…
        withAnimation(.easeIn(duration: 0.18)) { flipAngle = 90 }
        try? await Task.sleep(for: .seconds(0.18))
        // …and comes back round showing the new flag.
        showingNew = true
        flipAngle = -90
        withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { flipAngle = 0 }
        withAnimation(.easeOut(duration: 0.7)) { pulse = true }
        celebrate += 1
        try? await Task.sleep(for: .seconds(0.15))
        withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) { textIn = true }
        try? await Task.sleep(for: .seconds(1.3))
        finish()
    }

    private func finish() {
        guard !finished else { return }
        finished = true
        onFinish()
    }
}

/// Puffs of smoke bursting outward from the middle, fading as they go.
private struct PuffCloud: View {
    let bursting: Bool

    /// Angle (degrees), distance and size of each puff.
    private static let puffs: [(angle: Double, distance: CGFloat, size: CGFloat)] = [
        (0, 92, 46), (40, 104, 34), (80, 84, 42), (125, 100, 38), (165, 90, 48),
        (205, 106, 32), (245, 88, 44), (290, 100, 36), (330, 94, 40),
    ]

    var body: some View {
        ZStack {
            ForEach(Self.puffs.indices, id: \.self) { index in
                let puff = Self.puffs[index]
                let radians = puff.angle * .pi / 180
                Circle()
                    .fill(Palette.secondaryText.opacity(0.35))
                    .frame(width: puff.size, height: puff.size)
                    .scaleEffect(bursting ? 1.4 : 0.3)
                    .offset(x: bursting ? cos(radians) * puff.distance : 0, y: bursting ? sin(radians) * puff.distance : 0)
                    .opacity(bursting ? 0 : 1)
            }
        }
        .opacity(bursting ? 1 : 0.0001)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

