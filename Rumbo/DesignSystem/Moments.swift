import SwiftUI

// One-off celebration moments (docs/03-experience.md §3.5). Each plays when its trigger changes,
// after a short delay so a closing task screen doesn't hide it. Reduce Motion swaps motion for fades.

/// "+22 min" floating up into the training-hours badge.
struct TimeFlyUp: View {
    let gain: AppModel.TimeGain?
    /// Called as the number reaches the badge, so the badge can bounce.
    var onLand: () -> Void = {}

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: AppModel.TimeGain?
    @State private var risen = false

    var body: some View {
        ZStack {
            if let shown {
                Text("+\(shown.minutes) min")
                    .font(.rounded(.headline, weight: .black))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Capsule().fill(Palette.sky))
                    .background(Capsule().fill(Palette.sky.edge()).offset(y: 3))
                    .offset(y: risen || reduceMotion ? 0 : 70)
                    .scaleEffect(risen ? 0.7 : 1.1)
                    .opacity(risen ? 0 : 1)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: gain) { _, gain in
            guard let gain, gain.minutes > 0 else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(600))
                risen = false
                shown = gain
                withAnimation(.easeIn(duration: 0.9).delay(0.25)) { risen = true }
                try? await Task.sleep(for: .milliseconds(1100))
                onLand()
                Haptics.tap(.soft)
                try? await Task.sleep(for: .milliseconds(200))
                shown = nil
            }
        }
    }
}

/// Fireworks behind a "¡Meta cumplida!" banner, the moment the weekly goal is reached.
struct GoalReachedOverlay: View {
    let trigger: Int
    let goal: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?
    @State private var bursts: [FireworkBurst] = []
    @State private var showingBanner = false

    private static let duration: TimeInterval = 3.2

    var body: some View {
        ZStack {
            if !reduceMotion {
                TimelineView(.animation(paused: startedAt == nil)) { timeline in
                    Canvas { context, size in
                        guard let startedAt else { return }
                        let t = timeline.date.timeIntervalSince(startedAt)
                        for burst in bursts {
                            burst.draw(in: &context, size: size, t: t - burst.delay)
                        }
                    }
                }
            }
            if showingBanner {
                VStack(spacing: 6) {
                    PicoView(mood: .cheering, size: 90, celebrate: trigger)
                    Text("¡Meta cumplida!")
                        .font(.rounded(.title, weight: .black))
                        .foregroundStyle(Palette.ink)
                    Text("\(goal) minutes this week. Weekly goal done!")
                        .font(.rounded(.subheadline, weight: .bold))
                        .foregroundStyle(Palette.secondaryText)
                }
                .padding(24)
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.card))
                .background(RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Palette.sun).offset(y: 5))
                .transition(.scale(scale: 0.6).combined(with: .opacity))
                .accessibilityElement(children: .combine)
            }
        }
        .allowsHitTesting(false)
        .onChange(of: trigger) { _, _ in
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                bursts = (0..<5).map { index in FireworkBurst.random(delay: Double(index) * 0.35) }
                startedAt = .now
                Haptics.success()
                for index in 1..<5 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.35) { Haptics.tap(.medium, intensity: 0.8) }
                }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.7)) { showingBanner = true }
                try? await Task.sleep(for: .seconds(Self.duration))
                withAnimation(.easeOut(duration: 0.4)) { showingBanner = false }
                startedAt = nil
            }
        }
    }
}

struct FireworkBurst {
    var center: UnitPoint
    var delay: Double
    var color: Color
    var sparks: [CGVector]

    static let life: Double = 1.4

    static func random(delay: Double) -> FireworkBurst {
        let count = 34
        let sparks = (0..<count).map { index -> CGVector in
            let angle = Double(index) / Double(count) * 2 * .pi + Double.random(in: -0.08...0.08)
            let speed = Double.random(in: 150...260)
            return CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed)
        }
        return FireworkBurst(
            center: UnitPoint(x: Double.random(in: 0.15...0.85), y: Double.random(in: 0.12...0.4)),
            delay: delay,
            color: [Palette.coral, Palette.sun, Palette.leaf, Palette.sky].randomElement()!,
            sparks: sparks
        )
    }

    func draw(in context: inout GraphicsContext, size: CGSize, t: Double) {
        guard t >= 0, t < Self.life else { return }
        let origin = CGPoint(x: size.width * center.x, y: size.height * center.y)
        // Sparks slow down (drag) and droop (gravity) as they fade.
        let travel = (1 - exp(-3 * t)) / 3
        let fade = max(0, 1 - t / Self.life)
        for spark in sparks {
            let point = CGPoint(x: origin.x + spark.dx * travel, y: origin.y + spark.dy * travel + 60 * t * t)
            let radius = 2.6 * fade + 0.8
            var drawing = context
            drawing.opacity = fade
            drawing.fill(Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2)), with: .color(color))
        }
        if t < 0.25 {
            var flash = context
            flash.opacity = 1 - t / 0.25
            flash.fill(Path(ellipseIn: CGRect(x: origin.x - 14, y: origin.y - 14, width: 28, height: 28)), with: .color(.white))
        }
    }
}

/// A big flame that swells and beats for 7, 30, 100 and 365-day streaks.
struct StreakMilestoneOverlay: View {
    let milestone: AppModel.StreakMilestone?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown: AppModel.StreakMilestone?
    @State private var scale: CGFloat = 0.2

    var body: some View {
        ZStack {
            if let shown {
                VStack(spacing: 4) {
                    Image(systemName: "flame.fill")
                        .font(.system(size: 130, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [Palette.sun, Palette.coral], startPoint: .top, endPoint: .bottom))
                        .shadow(color: Palette.sun.opacity(0.6), radius: 24)
                    Text("\(shown.days)")
                        .font(.system(size: 54, weight: .black, design: .rounded))
                        .foregroundStyle(Palette.ink)
                    Text("days in a row")
                        .font(.rounded(.headline, weight: .heavy))
                        .foregroundStyle(Palette.secondaryText)
                }
                .scaleEffect(reduceMotion ? 1 : scale)
                .transition(.opacity)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: milestone) { _, milestone in
            guard let milestone else { return }
            Task {
                try? await Task.sleep(for: .milliseconds(700))
                scale = 0.2
                withAnimation(.easeOut(duration: 0.2)) { shown = milestone }
                withAnimation(.spring(response: 0.4, dampingFraction: 0.5)) { scale = 1.25 }
                Haptics.heartbeat()
                // Two beats, matching the haptic.
                for (delay, size) in [(0.35, 1.0), (0.5, 1.15), (0.95, 1.0), (1.1, 1.12), (1.4, 1.0)] {
                    DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                        withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { scale = size }
                    }
                }
                try? await Task.sleep(for: .seconds(2.6))
                withAnimation(.easeOut(duration: 0.4)) { shown = nil }
            }
        }
    }
}

/// An ice crystal over the streak flame that cracks and shatters: a freeze saved the streak.
struct IceShatter: View {
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: Phase = .hidden

    enum Phase { case hidden, frozen, shattered }

    var body: some View {
        ZStack {
            if phase == .frozen {
                Image(systemName: "snowflake")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Palette.sky)
                    .padding(6)
                    .background(Circle().fill(Palette.sky.opacity(0.25)))
                    .transition(.scale(scale: 0.3).combined(with: .opacity))
            }
            ForEach(0..<8, id: \.self) { index in
                let angle = Double(index) / 8 * 2 * .pi
                RoundedRectangle(cornerRadius: 1)
                    .fill(Palette.sky)
                    .frame(width: 5, height: 9)
                    .rotationEffect(.radians(angle))
                    // Hidden behind the crystal while frozen, then fly out and fade as it shatters.
                    .offset(x: phase == .shattered ? cos(angle) * 34 : 0, y: phase == .shattered ? sin(angle) * 34 + 10 : 0)
                    .opacity(phase == .frozen ? 1 : 0)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, _ in
            Task {
                try? await Task.sleep(for: .milliseconds(500))
                withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { phase = .frozen }
                try? await Task.sleep(for: .milliseconds(900))
                Haptics.crack()
                withAnimation(.easeOut(duration: reduceMotion ? 0.3 : 0.6)) { phase = reduceMotion ? .hidden : .shattered }
                try? await Task.sleep(for: .milliseconds(700))
                phase = .hidden
            }
        }
    }
}
