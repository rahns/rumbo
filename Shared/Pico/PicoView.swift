import SwiftUI
import UIKit

/// Pico's moods. See docs/03-experience.md §3.3.
enum PicoMood: Equatable {
    case hovering
    case cheering
    case proud
    case backpacker
    case sleepy
    case listening
}

/// Pico the hummingbird, drawn in code on a 100 × 100 canvas and animated with time.
struct PicoView: View {
    var mood: PicoMood = .hovering
    var size: CGFloat = 80
    /// Change this value to play a loop-de-loop.
    var celebrate: Int = 0
    /// Tapping Pico plays a random trick. Off where Pico sits inside another control.
    var reactsToTaps = true
    /// Faces the other way. Only the bird is flipped, so a speech bubble stays readable.
    var mirrored = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taps = 0
    @State private var flipAngle: Double = 0
    @State private var spinAngle: Double = 0
    @State private var hops = 0
    @State private var squawk: String?

    private static let squawks = ["¡Vamos!", "¡Olé!", "¡Hola!", "¡Dale!", "¡Qué bien!", "¡Ánimo!"]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                PicoDrawing.draw(in: &context, size: canvasSize, time: time, mood: mood, still: reduceMotion)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(x: mirrored ? -1 : 1, y: 1)
        .rotation3DEffect(.degrees(flipAngle), axis: (x: 0, y: 1, z: 0))
        .rotationEffect(.degrees(spinAngle))
        .keyframeAnimator(initialValue: PicoMotion(), trigger: hops) { content, motion in
            content
                .offset(y: motion.lift)
                .scaleEffect(x: 1 / motion.scale, y: motion.scale, anchor: .bottom)
        } keyframes: { _ in
            KeyframeTrack(\.lift) {
                LinearKeyframe(0, duration: 0.08)
                SpringKeyframe(-size * 0.35, duration: 0.25)
                SpringKeyframe(0, duration: 0.35)
            }
            KeyframeTrack(\.scale) {
                // Squash, stretch on the way up, squash on landing.
                SpringKeyframe(0.85, duration: 0.08)
                SpringKeyframe(1.12, duration: 0.2)
                SpringKeyframe(0.9, duration: 0.3)
                SpringKeyframe(1, duration: 0.2)
            }
        }
        .overlay(alignment: .top) {
            if let squawk {
                Text(squawk)
                    .font(.rounded(.caption, weight: .black))
                    // A white speech bubble in both modes, so the text stays dark.
                    .foregroundStyle(Palette.inkOnBright)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(.white))
                    .overlay(Capsule().strokeBorder(Palette.ink.opacity(0.15), lineWidth: 1))
                    .fixedSize()
                    // On the side Pico faces.
                    .offset(x: mirrored ? -size * 0.35 : size * 0.35, y: -size * 0.15)
                    .transition(.scale(scale: 0.3, anchor: mirrored ? .bottomTrailing : .bottomLeading).combined(with: .opacity))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard reactsToTaps else { return }
            playTrick()
        }
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .keyframeAnimator(initialValue: PicoMotion(), trigger: celebrate) { content, motion in
            content
                .rotationEffect(.degrees(motion.spin))
                .offset(y: motion.lift)
                .scaleEffect(motion.scale)
        } keyframes: { _ in
            KeyframeTrack(\.lift) {
                SpringKeyframe(-18, duration: 0.25)
                SpringKeyframe(0, duration: 0.5)
            }
            KeyframeTrack(\.spin) {
                LinearKeyframe(0, duration: 0.1)
                CubicKeyframe(reduceMotion ? 0 : -360, duration: 0.6)
            }
            KeyframeTrack(\.scale) {
                SpringKeyframe(1.15, duration: 0.3)
                SpringKeyframe(1, duration: 0.45)
            }
        }
        .accessibilityHidden(true)
    }

    /// A flip, a spin, a hop or a squawk, at random. With Reduce Motion, always the squawk.
    private func playTrick() {
        taps += 1
        let trick = reduceMotion ? 3 : Int.random(in: 0..<4)
        switch trick {
        case 0: withAnimation(.spring(response: 0.6, dampingFraction: 0.7)) { flipAngle += 360 }
        case 1: withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { spinAngle -= 360 }
        case 2: hops += 1
        default:
            let word = Self.squawks.randomElement()!
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) { squawk = word }
            Task {
                try? await Task.sleep(for: .milliseconds(1300))
                if squawk == word { withAnimation(.easeOut(duration: 0.2)) { squawk = nil } }
            }
        }
    }
}

struct PicoMotion {
    var lift: CGFloat = 0
    var spin: Double = 0
    var scale: CGFloat = 1
}

/// Pico badge used across the app (keeps the old call sites working).
struct PicoBadge: View {
    var size: CGFloat = 56
    var mood: PicoMood = .hovering
    var celebrate: Int = 0

    var body: some View {
        PicoView(mood: mood, size: size, celebrate: celebrate)
    }
}

/// Pico the toucan (*pico* is Spanish for "beak"), drawn on a 100 × 100 canvas.
/// The geometry matches the reference render in docs/art/pico-render.py point for point.
enum PicoDrawing {
    private static func hex(_ value: UInt32, _ alpha: Double = 1) -> Color {
        Color(uiColor: UIColor(hex: value)).opacity(alpha)
    }

    static let navyHigh = hex(0x3E5290)
    static let navy = hex(0x1E2A4A)
    static let navyLow = hex(0x121A33)
    static let wingTop = hex(0x2E3F72)
    static let featherLine = hex(0x4A5C94)
    static let outline = hex(0x0B1124)
    static let cream = hex(0xFFF3C4)
    static let amber = hex(0xFFC93C)
    static let amberLine = hex(0xE0A82E)
    static let bibEdge = hex(0xC9922A)
    static let orange = hex(0xFF8A3D)
    static let coral = hex(0xF25C4A)
    static let coralDark = hex(0xC8392B)
    static let sky = hex(0x6CC4FA)
    static let skyDark = hex(0x2F7FCC)
    static let feet = hex(0x5B7FA8)
    static let iris = hex(0x8A5A2E)
    static let irisDark = hex(0x6B4423)
    static let blush = hex(0xFF8C96, 0.65)
    static let leather = hex(0xB07A45)
    static let leatherDark = hex(0x7E5230)
    static let khaki = hex(0xE2C48A)
    static let khakiDark = hex(0xB8975A)

    static let wingPivot = CGPoint(x: 31, y: 48)

    static func draw(in context: inout GraphicsContext, size: CGSize, time t: Double, mood: PicoMood, still: Bool) {
        context.scaleBy(x: size.width / 100, y: size.height / 100)
        let happy = mood == .cheering || mood == .proud
        let sleepy = mood == .sleepy
        let feetPoint = CGPoint(x: 43, y: 90)

        // Ground shadow stays put while the body breathes or sways above it.
        context.fill(ellipse(43, 94, 42, 6), with: .color(navy.opacity(0.12)))
        if !still {
            if sleepy {
                rotate(&context, degrees: sin(t * 1.2) * 2, around: feetPoint)
            } else {
                let breathe = 1 + sin(t * 2.2) * 0.012
                context.translateBy(x: feetPoint.x, y: feetPoint.y)
                context.scaleBy(x: 1 / breathe, y: breathe)
                context.translateBy(x: -feetPoint.x, y: -feetPoint.y)
            }
        }

        // Feet
        for footX in [37.0, 49.0] {
            for toe in [-3.0, 0, 3] {
                var toeLine = Path()
                toeLine.move(to: p(footX, 84))
                toeLine.addLine(to: p(footX + toe * 1.3, 91))
                context.stroke(toeLine, with: .color(feet), style: line(2.4))
            }
        }

        // Tail
        let tail = shape(p(14, 66), .l(p(26, 66)), .l(p(26, 86)), .c(p(26, 92), p(14, 92), p(14, 86)), .l(p(14, 66)))
            .applying(rotation(38, around: p(20, 70)))
        context.fill(tail, with: linear(p(20, 66), p(20, 92), [navy, navyLow]))
        context.stroke(tail, with: .color(outline), style: line(2.2))

        // Body with a soft radial sheen
        let body = shape(p(40, 24), .c(p(56, 24), p(64, 38), p(64, 54)), .c(p(64, 72), p(54, 88), p(40, 88)),
                         .c(p(26, 88), p(16, 74), p(16, 56)), .c(p(16, 38), p(26, 24), p(40, 24)))
        context.fill(body, with: .radialGradient(Gradient(stops: [.init(color: navyHigh, location: 0), .init(color: navy, location: 0.45), .init(color: navyLow, location: 1)]),
                                                 center: p(32, 38), startRadius: 0, endRadius: 52))

        if mood == .backpacker {
            let pack = shape(p(12, 50), .c(p(12, 44), p(16, 42), p(22, 42)), .l(p(26, 42)), .c(p(30, 42), p(31, 46), p(31, 50)), .l(p(31, 70)),
                             .c(p(31, 74), p(28, 76), p(24, 76)), .l(p(16, 76)), .c(p(12, 76), p(11, 73), p(11, 70)), .l(p(12, 50)))
            context.fill(pack, with: linear(p(12, 44), p(30, 76), [leather, leatherDark]))
            context.stroke(pack, with: .color(outline), style: line(2))
            let flap = shape(p(11, 52), .c(p(16, 49), p(26, 49), p(31, 52)), .l(p(31, 58)), .c(p(26, 61), p(16, 61), p(11, 58)), .l(p(11, 52)))
            context.fill(flap, with: .color(leatherDark))
            context.stroke(flap, with: .color(outline), style: line(1.6))
            context.fill(ellipse(21, 59, 3, 3), with: .color(amber))
            context.stroke(ellipse(21, 59, 3, 3), with: .color(outline), style: line(1))
        } else {
            // Crest: three tufts
            for (base, peak, end) in [(p(34, 26), p(30, 12), p(39, 24)), (p(38, 25), p(37, 9), p(44, 24)), (p(42, 25), p(46, 12), p(48, 26))] {
                let tuft = shape(base, .c(p(base.x - 2, 18), p(peak.x - 2, peak.y + 2), peak), .c(p(peak.x + 3, peak.y + 3), p(end.x, 18), end))
                context.fill(tuft, with: .color(navy))
                context.stroke(tuft, with: .color(outline), style: line(1.8))
            }
        }
        context.stroke(body, with: .color(outline), style: line(2.4))

        // Chest bib with scalloped feathers, and a coral sash
        let bib = shape(p(47, 29), .c(p(60, 31), p(65, 45), p(61, 58)), .c(p(57, 66), p(46, 66), p(41, 58)), .c(p(38, 48), p(38, 34), p(47, 29)))
        context.fill(bib, with: linear(p(50, 30), p(50, 64), [cream, amber]))
        for (row, y) in [44.0, 50, 56].enumerated() {
            for index in 0..<3 {
                let x = 44 + Double(index) * 5 + Double(row % 2) * 2.5
                guard x > 40 && x < 60 else { continue }
                let scallop = shape(p(x - 2.2, y), .c(p(x - 2.2, y + 2.5), p(x + 2.2, y + 2.5), p(x + 2.2, y)))
                context.stroke(scallop, with: .color(amberLine), style: line(0.9))
            }
        }
        let sash = shape(p(39, 57), .c(p(46, 64), p(56, 63), p(61, 56)), .c(p(62, 60), p(61, 64), p(58, 66)), .c(p(51, 71), p(43, 69), p(38, 62)), .l(p(39, 57)))
        context.fill(sash, with: linear(p(40, 58), p(60, 66), [coral, coralDark]))
        context.stroke(bib, with: .color(bibEdge), style: line(1))
        context.fill(ellipse(27, 36, 10, 6), with: .color(.white.opacity(0.13)))

        // Wing: hangs at the side, waves when happy
        let up = happy && !still ? 100 + sin(t * 2 * .pi * 2.2) * 25 : happy ? 100 : 0
        let turn = rotation(up, around: wingPivot)
        let wing = shape(p(30, 45), .c(p(38, 45), p(41, 58), p(38, 70)), .c(p(35, 78), p(26, 80), p(21, 73)), .c(p(17, 63), p(21, 48), p(30, 45)))
            .applying(turn)
        context.fill(wing, with: linear(p(30, 44).applying(turn), p(30, 80).applying(turn), [wingTop, navyLow]))
        for (from, to, control) in [(p(25, 55), p(32, 70), p(31, 59)), (p(22, 61), p(28, 74), p(25, 67)), (p(29, 51), p(36, 64), p(35, 54))] {
            context.stroke(shape(from, .c(control, control, to)).applying(turn), with: .color(featherLine), style: line(1))
        }
        for (x, y) in [(22.5, 73.0), (27.5, 77.0), (33.0, 75.5)] {
            let tip = ellipse(x, y, 6, 4).applying(turn)
            context.fill(tip, with: .color(sky))
            context.stroke(tip, with: .color(outline), style: line(1))
        }
        context.stroke(wing, with: .color(outline), style: line(2.2))

        // Eye ring, eye and brow
        context.fill(ellipse(54, 36, 23, 23), with: .color(sky))
        context.stroke(ellipse(54, 36, 23, 23), with: .color(outline), style: line(1.6))
        let blinking = !still && mood != .sleepy && !happy && t.truncatingRemainder(dividingBy: 4) < 0.12
        if sleepy {
            context.stroke(shape(p(48, 36), .c(p(51, 41), p(57, 41), p(60, 36))), with: .color(outline), style: line(2.2))
        } else if happy {
            context.stroke(shape(p(48, 39), .c(p(51, 31), p(57, 31), p(60, 39))), with: .color(outline), style: line(2.4))
        } else if blinking {
            context.stroke(shape(p(48, 36), .l(p(61, 36))), with: .color(outline), style: line(2.2))
        } else {
            context.fill(ellipse(55, 35.5, 15, 17), with: .color(.white))
            context.stroke(ellipse(55, 35.5, 15, 17), with: .color(outline), style: line(1))
            context.fill(ellipse(57.2, 36.5, 9.5, 11), with: .radialGradient(Gradient(colors: [iris, irisDark]), center: p(57, 35), startRadius: 0, endRadius: 7))
            context.fill(ellipse(58, 37, 5.2, 6.2), with: .color(outline))
            context.fill(ellipse(59.8, 33.4, 3.4, 3.4), with: .color(.white))
            context.fill(ellipse(55.8, 40, 1.6, 1.6), with: .color(.white))
        }
        context.stroke(shape(p(44, 23), .c(p(49, 20), p(56, 19.5), p(61, 22))), with: .color(outline), style: line(2.6))
        context.fill(ellipse(51, 49, 7, 3.8), with: .color(blush))

        if mood == .backpacker {
            let strap = shape(p(40, 30), .c(p(46, 44), p(46, 60), p(40, 72)))
            context.stroke(strap, with: .color(leatherDark), style: line(3.2))
            context.stroke(strap, with: .color(outline), style: line(0.8))
            context.fill(ellipse(40, 23, 40, 8), with: .color(khakiDark))
            context.stroke(ellipse(40, 23, 40, 8), with: .color(outline), style: line(1.8))
            let crown = shape(p(28, 22), .c(p(28, 12), p(34, 8), p(40, 8)), .c(p(46, 8), p(52, 12), p(52, 22)), .l(p(28, 22)))
            context.fill(crown, with: linear(p(40, 8), p(40, 22), [khaki, khakiDark]))
            context.stroke(crown, with: .color(outline), style: line(1.8))
            let band = Path(CGRect(x: 28, y: 17, width: 24, height: 4))
            context.fill(band, with: .color(coral))
            context.stroke(band, with: .color(outline), style: line(1))
        }

        if mood == .listening {
            let arc = shape(p(32, 34), .c(p(28, 6), p(58, 2), p(62, 20)))
            context.stroke(arc, with: .color(outline), style: line(4.6))
            context.stroke(arc, with: .color(coral), style: line(2.6))
            let cup = shape(p(27, 30), .c(p(27, 26), p(30, 25), p(33, 25)), .l(p(37, 25)), .c(p(40, 25), p(41, 28), p(41, 31)), .l(p(41, 39)),
                            .c(p(41, 42), p(39, 44), p(36, 44)), .l(p(32, 44)), .c(p(29, 44), p(27, 42), p(27, 39)), .l(p(27, 30)))
            context.fill(cup, with: linear(p(34, 25), p(34, 44), [coral, coralDark]))
            context.stroke(cup, with: .color(outline), style: line(1.8))
            for (index, note) in [p(70, 14), p(78, 8)].enumerated() {
                let rise = still ? 0 : sin(t * 3 + Double(index)) * 2
                context.fill(ellipse(note.x, note.y + rise, 4, 3), with: .color(skyDark))
                context.stroke(shape(p(note.x + 1.8, note.y + rise), .l(p(note.x + 1.8, note.y + rise - 7))), with: .color(skyDark), style: line(1.2))
            }
        }

        // The beak: big, sun to coral on top, sky blue underneath. Opens a little when happy.
        var lower = shape(p(61, 43), .c(p(76, 43), p(90, 45), p(98, 47)), .c(p(90, 52), p(74, 53), p(62, 50)), .l(p(61, 43)))
        if happy {
            lower = lower.applying(rotation(8, around: p(61, 46)))
        }
        context.fill(lower, with: linear(p(62, 46), p(98, 46), [sky, skyDark]))
        context.stroke(lower, with: .color(outline), style: line(2))
        let upper = shape(p(59, 29), .c(p(74, 21), p(93, 29), p(99, 46)), .c(p(92, 45), p(78, 43), p(61, 44)), .l(p(59, 29)))
        context.fill(upper, with: .linearGradient(Gradient(stops: [.init(color: amber, location: 0), .init(color: orange, location: 0.5),
                                                                   .init(color: coral, location: 0.82), .init(color: coralDark, location: 1)]),
                                                  startPoint: p(59, 36), endPoint: p(99, 40)))
        context.stroke(shape(p(64, 28.5), .c(p(76, 24.5), p(88, 29), p(94, 37))), with: .color(.white.opacity(0.55)), style: line(2))
        context.fill(ellipse(65, 32, 2.4, 1.4), with: .color(outline))
        context.stroke(upper, with: .color(outline), style: line(2.2))

        if happy {
            for (index, star) in [(p(14, 22), 3.0), (p(86, 14), 3.5), (p(90, 70), 2.5), (p(8, 52), 2.5)].enumerated() {
                let r = star.1 * (still ? 1 : 0.8 + 0.3 * sin(t * 6 + Double(index)))
                let c = star.0
                context.fill(shape(p(c.x, c.y - r * 2), .l(p(c.x + r * 0.6, c.y)), .l(p(c.x, c.y + r * 2)), .l(p(c.x - r * 0.6, c.y)), .l(p(c.x, c.y - r * 2))),
                             with: .color(amber))
            }
        }

        if sleepy {
            for (index, z) in [(p(76, 16), 3.0), (p(84, 9), 4.0)].enumerated() {
                let phase = still ? 0 : (t * 0.5 + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
                var zContext = context
                zContext.opacity = still ? 1 : 1 - phase
                let o = p(z.0.x + phase * 4, z.0.y - phase * 8)
                let zs = z.1
                zContext.stroke(shape(o, .l(p(o.x + zs, o.y)), .l(p(o.x, o.y + zs)), .l(p(o.x + zs, o.y + zs))), with: .color(skyDark), style: line(1.4))
            }
        }
    }

    // MARK: Geometry helpers

    private enum Segment {
        case c(CGPoint, CGPoint, CGPoint)
        case l(CGPoint)
    }

    private static func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }

    private static func shape(_ start: CGPoint, _ segments: Segment...) -> Path {
        var path = Path()
        path.move(to: start)
        for segment in segments {
            switch segment {
            case .c(let c1, let c2, let end): path.addCurve(to: end, control1: c1, control2: c2)
            case .l(let end): path.addLine(to: end)
            }
        }
        return path
    }

    private static func ellipse(_ cx: Double, _ cy: Double, _ width: Double, _ height: Double) -> Path {
        Path(ellipseIn: CGRect(x: cx - width / 2, y: cy - height / 2, width: width, height: height))
    }

    private static func linear(_ start: CGPoint, _ end: CGPoint, _ colors: [Color]) -> GraphicsContext.Shading {
        .linearGradient(Gradient(colors: colors), startPoint: start, endPoint: end)
    }

    private static func line(_ width: Double) -> StrokeStyle {
        StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round)
    }

    /// Clockwise rotation (y points down), matching the reference render.
    private static func rotation(_ degrees: Double, around point: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: -point.x, y: -point.y)
            .concatenating(CGAffineTransform(rotationAngle: degrees * .pi / 180))
            .concatenating(CGAffineTransform(translationX: point.x, y: point.y))
    }

    private static func rotate(_ context: inout GraphicsContext, degrees: Double, around point: CGPoint) {
        context.translateBy(x: point.x, y: point.y)
        context.rotate(by: .degrees(degrees))
        context.translateBy(x: -point.x, y: -point.y)
    }
}
