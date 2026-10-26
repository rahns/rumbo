import SwiftUI

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

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60, paused: reduceMotion)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                PicoDrawing.draw(in: &context, size: canvasSize, time: time, mood: mood, still: reduceMotion)
            }
        }
        .frame(width: size, height: size)
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

/// Pico's artwork on a 100 × 100 canvas. Previewed with a Python render of the same geometry
/// before porting, so the shapes here match that reference.
enum PicoDrawing {
    static let green = Color(red: 0.18, green: 0.77, blue: 0.55)
    static let greenDark = Color(red: 0.09, green: 0.55, blue: 0.43)
    static let teal = Color(red: 0.09, green: 0.59, blue: 0.55)
    static let mint = Color(red: 0.82, green: 0.96, blue: 0.88)
    static let blush = Color(red: 1.0, green: 0.55, blue: 0.59)
    static let ink = Color(red: 0.12, green: 0.16, blue: 0.29)
    static let brown = Color(red: 0.55, green: 0.36, blue: 0.20)

    static func draw(in context: inout GraphicsContext, size: CGSize, time t: Double, mood: PicoMood, still: Bool) {
        context.scaleBy(x: size.width / 100, y: size.height / 100)
        let sleepy = mood == .sleepy
        let excited = mood == .cheering || mood == .proud

        if sleepy {
            drawBranch(in: context)
            context.translateBy(x: 0, y: 6)
        } else if !still {
            context.translateBy(x: 0, y: sin(t * (excited ? 4.5 : 2.4)) * 3)
        }

        // Tail: three fanned feathers, the middle one tipped in coral.
        context.fill(feather(from: CGPoint(x: 36, y: 66), length: 26, width: 8, degrees: -15), with: .color(greenDark))
        context.fill(feather(from: CGPoint(x: 36, y: 66), length: 25, width: 8, degrees: -50), with: .color(greenDark))
        let middle = feather(from: CGPoint(x: 36, y: 66), length: 30, width: 8, degrees: -32)
        context.fill(middle, with: .color(teal))
        var tip = context
        tip.clip(to: Path(ellipseIn: CGRect(x: 4, y: 74, width: 16, height: 16)))
        tip.fill(middle, with: .color(Palette.coral))

        if mood == .backpacker {
            let pack = Path(roundedRect: CGRect(x: 30, y: 42, width: 17, height: 20), cornerRadius: 5)
                .applying(rotation(degrees: -32, around: CGPoint(x: 38.5, y: 52)))
            context.fill(pack, with: .color(brown))
        }

        // Body (with a darker edge underneath for depth) and belly.
        context.fill(ellipse(center: CGPoint(x: 50, y: 61), width: 46, height: 29, degrees: -32), with: .color(greenDark))
        context.fill(ellipse(center: CGPoint(x: 50, y: 59.5), width: 44, height: 27, degrees: -32), with: .color(green))
        context.fill(ellipse(center: CGPoint(x: 56, y: 66), width: 24, height: 12, degrees: -32), with: .color(mint))

        if sleepy {
            for x in [50.0, 56.0] {
                var leg = Path()
                leg.move(to: CGPoint(x: x, y: 70))
                leg.addLine(to: CGPoint(x: x + 1, y: 78))
                context.stroke(leg, with: .color(ink), style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
            }
        }

        if mood == .backpacker {
            var strap = Path()
            strap.move(to: CGPoint(x: 44, y: 44))
            strap.addQuadCurve(to: CGPoint(x: 57, y: 63), control: CGPoint(x: 58, y: 48))
            context.stroke(strap, with: .color(brown), lineWidth: 2.5)
        }

        // Head with a soft highlight.
        context.fill(Path(ellipseIn: CGRect(x: 49, y: 19.5, width: 34, height: 33)), with: .color(greenDark))
        context.fill(Path(ellipseIn: CGRect(x: 50, y: 19.5, width: 32, height: 31)), with: .color(green))
        context.fill(Path(ellipseIn: CGRect(x: 55, y: 23, width: 11, height: 6)), with: .color(.white.opacity(0.22)))

        // Crest sweeping back, middle tuft coral (hidden under the hat when travelling).
        if mood != .backpacker {
            context.fill(feather(from: CGPoint(x: 62, y: 23), length: 13, width: 6, degrees: 35), with: .color(greenDark))
            context.fill(feather(from: CGPoint(x: 62, y: 23), length: 15, width: 6, degrees: 60), with: .color(Palette.coral))
            context.fill(feather(from: CGPoint(x: 62, y: 23), length: 11, width: 6, degrees: 85), with: .color(greenDark))
        }

        // Shiny coral throat.
        context.fill(ellipse(center: CGPoint(x: 67, y: 47.5), width: 20, height: 11, degrees: -12), with: .color(Palette.coral))
        context.fill(ellipse(center: CGPoint(x: 71, y: 45.5), width: 5, height: 2.4, degrees: -20), with: .color(Palette.sun))

        // Long beak.
        var beak = Path()
        beak.move(to: CGPoint(x: 80, y: 35.5))
        beak.addLine(to: CGPoint(x: 99, y: 34))
        beak.addLine(to: CGPoint(x: 99.5, y: 35.5))
        beak.addLine(to: CGPoint(x: 80, y: 40.5))
        beak.closeSubpath()
        context.fill(beak, with: .color(ink))

        drawEye(in: context, time: t, mood: mood, still: still)
        context.fill(Path(ellipseIn: CGRect(x: 74, y: 40.25, width: 6, height: 3.5)), with: .color(blush.opacity(excited ? 0.95 : 0.75)))

        if mood == .listening {
            var band = Path()
            band.move(to: CGPoint(x: 53, y: 38))
            band.addQuadCurve(to: CGPoint(x: 80, y: 30), control: CGPoint(x: 64, y: 4))
            context.stroke(band, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            context.fill(Path(roundedRect: CGRect(x: 48, y: 30, width: 9, height: 13), cornerRadius: 4), with: .color(Palette.coral))
        }

        if mood == .backpacker {
            context.fill(Path(ellipseIn: CGRect(x: 51, y: 18, width: 32, height: 7)), with: .color(brown))
            context.fill(Path(roundedRect: CGRect(x: 58, y: 9, width: 18, height: 12), cornerRadius: 4), with: .color(brown))
            context.fill(Path(CGRect(x: 58, y: 16, width: 18, height: 2.5)), with: .color(Palette.coral))
        }

        // Wing: three feathers from the shoulder. Flaps fast with ghost copies for blur; folded when asleep.
        let shoulder = CGPoint(x: 52, y: 50)
        if sleepy {
            drawWing(in: context, at: shoulder, degrees: -18, opacity: 1)
        } else if still {
            drawWing(in: context, at: shoulder, degrees: 45, opacity: 1)
        } else {
            let flap = 47 + sin(t * 2 * .pi * (excited ? 10 : 7)) * 32
            drawWing(in: context, at: shoulder, degrees: flap - 24, opacity: 0.22)
            drawWing(in: context, at: shoulder, degrees: flap + 24, opacity: 0.22)
            drawWing(in: context, at: shoulder, degrees: flap, opacity: 1)
        }

        if excited && !still {
            drawSparkles(in: context, time: t)
        }
        if sleepy {
            drawZzz(in: context, time: still ? 0 : t)
        }
    }

    // MARK: Pieces

    private static func drawEye(in context: GraphicsContext, time t: Double, mood: PicoMood, still: Bool) {
        let closedLine = StrokeStyle(lineWidth: 2.3, lineCap: .round)
        switch mood {
        case .sleepy:
            var lid = Path()
            lid.move(to: CGPoint(x: 66.5, y: 33))
            lid.addQuadCurve(to: CGPoint(x: 76.5, y: 33), control: CGPoint(x: 71.5, y: 39))
            context.stroke(lid, with: .color(ink), style: closedLine)
        case .cheering, .proud:
            // Happy squint: ^
            var squint = Path()
            squint.move(to: CGPoint(x: 66.5, y: 36))
            squint.addQuadCurve(to: CGPoint(x: 76.5, y: 36), control: CGPoint(x: 71.5, y: 27))
            context.stroke(squint, with: .color(ink), style: closedLine)
        default:
            if !still && t.truncatingRemainder(dividingBy: 4) < 0.12 {
                var lid = Path()
                lid.move(to: CGPoint(x: 66, y: 33.5))
                lid.addLine(to: CGPoint(x: 77, y: 33.5))
                context.stroke(lid, with: .color(ink), style: closedLine)
            } else {
                context.fill(Path(ellipseIn: CGRect(x: 65.5, y: 26.5, width: 12, height: 13)), with: .color(.white))
                context.fill(Path(ellipseIn: CGRect(x: 69.75, y: 29.75, width: 7.5, height: 8.5)), with: .color(ink))
                context.fill(Path(ellipseIn: CGRect(x: 73.6, y: 30.1, width: 2.8, height: 2.8)), with: .color(.white))
                context.fill(Path(ellipseIn: CGRect(x: 71.3, y: 35.8, width: 1.4, height: 1.4)), with: .color(.white))
            }
            // A slightly raised eyebrow gives Pico a cheeky, curious look.
            var brow = Path()
            brow.move(to: CGPoint(x: 66.5, y: 24.5))
            brow.addLine(to: CGPoint(x: 76.5, y: 23))
            context.stroke(brow, with: .color(greenDark), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
        }
    }

    private static func drawWing(in context: GraphicsContext, at shoulder: CGPoint, degrees: Double, opacity: Double) {
        var wing = context
        wing.opacity = opacity
        wing.fill(feather(from: shoulder, length: 36, width: 13, degrees: degrees), with: .color(greenDark))
        wing.fill(feather(from: shoulder, length: 30, width: 11, degrees: degrees + 7), with: .color(teal))
        wing.fill(feather(from: shoulder, length: 24, width: 9, degrees: degrees + 14), with: .color(green))
    }

    private static func drawBranch(in context: GraphicsContext) {
        var branch = Path()
        branch.move(to: CGPoint(x: 10, y: 86))
        branch.addQuadCurve(to: CGPoint(x: 94, y: 82), control: CGPoint(x: 50, y: 90))
        context.stroke(branch, with: .color(brown), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        context.fill(ellipse(center: CGPoint(x: 22, y: 80), width: 13, height: 6, degrees: -30), with: .color(green))
        context.fill(ellipse(center: CGPoint(x: 86, y: 77), width: 11, height: 5, degrees: 25), with: .color(green))
    }

    private static func drawSparkles(in context: GraphicsContext, time t: Double) {
        for index in 0..<5 {
            let angle = t * 1.6 + Double(index) * (2 * .pi / 5)
            let center = CGPoint(x: 52 + cos(angle) * 46, y: 50 + sin(angle) * 42)
            let pulse = 2.5 + sin(t * 6 + Double(index)) * 1.2
            var star = Path()
            star.move(to: CGPoint(x: center.x, y: center.y - pulse * 2))
            star.addLine(to: CGPoint(x: center.x + pulse * 0.6, y: center.y))
            star.addLine(to: CGPoint(x: center.x, y: center.y + pulse * 2))
            star.addLine(to: CGPoint(x: center.x - pulse * 0.6, y: center.y))
            star.closeSubpath()
            context.fill(star, with: .color(Palette.sun))
        }
    }

    private static func drawZzz(in context: GraphicsContext, time t: Double) {
        for index in 0..<2 {
            let phase = (t * 0.5 + Double(index) * 0.5).truncatingRemainder(dividingBy: 1)
            var z = context
            z.opacity = 1 - phase
            z.draw(
                Text("z").font(.system(size: 10 + Double(index) * 4, weight: .black, design: .rounded)).foregroundStyle(Palette.sky),
                at: CGPoint(x: 86 + phase * 8, y: 18 - phase * 14)
            )
        }
    }

    // MARK: Geometry

    /// A teardrop feather from `pivot`, pointing left and then rotated clockwise by `degrees`.
    static func feather(from pivot: CGPoint, length: CGFloat, width: CGFloat, degrees: Double) -> Path {
        let steps = 24
        var top: [CGPoint] = []
        var bottom: [CGPoint] = []
        for step in 0...steps {
            let t = CGFloat(step) / CGFloat(steps)
            let half = width * sin(.pi * t) * (1 - 0.35 * t) / 2
            top.append(CGPoint(x: pivot.x - length * t, y: pivot.y - half))
            bottom.append(CGPoint(x: pivot.x - length * t, y: pivot.y + half))
        }
        var path = Path()
        path.addLines(top + bottom.reversed())
        path.closeSubpath()
        return path.applying(rotation(degrees: degrees, around: pivot))
    }

    private static func ellipse(center: CGPoint, width: CGFloat, height: CGFloat, degrees: Double) -> Path {
        Path(ellipseIn: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
            .applying(rotation(degrees: degrees, around: center))
    }

    private static func rotation(degrees: Double, around point: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: -point.x, y: -point.y)
            .concatenating(CGAffineTransform(rotationAngle: degrees * .pi / 180))
            .concatenating(CGAffineTransform(translationX: point.x, y: point.y))
    }
}
