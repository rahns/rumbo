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

enum PicoDrawing {
    static let green = Color(red: 0.16, green: 0.70, blue: 0.48)
    static let greenDark = Color(red: 0.09, green: 0.50, blue: 0.35)
    static let belly = Color(red: 0.85, green: 0.96, blue: 0.88)
    static let ink = Color(red: 0.12, green: 0.16, blue: 0.29)
    static let brown = Color(red: 0.55, green: 0.36, blue: 0.20)

    static func draw(in context: inout GraphicsContext, size: CGSize, time t: Double, mood: PicoMood, still: Bool) {
        context.scaleBy(x: size.width / 100, y: size.height / 100)
        let sleepy = mood == .sleepy
        let excited = mood == .cheering || mood == .proud

        if sleepy {
            drawBranch(in: context)
            context.translateBy(x: 0, y: 8)
            rotate(&context, degrees: -10, around: CGPoint(x: 50, y: 55))
        } else if !still {
            context.translateBy(x: 0, y: sin(t * (excited ? 4.5 : 2.4)) * 3)
        }

        // Tail
        var tail = Path()
        tail.move(to: CGPoint(x: 36, y: 60))
        tail.addLine(to: CGPoint(x: 9, y: 73))
        tail.addLine(to: CGPoint(x: 14, y: 82))
        tail.addLine(to: CGPoint(x: 40, y: 67))
        tail.closeSubpath()
        context.fill(tail, with: .color(greenDark))

        // Body and belly
        context.fill(ellipse(center: CGPoint(x: 50, y: 58), width: 46, height: 30, degrees: -18), with: .color(green))
        context.fill(ellipse(center: CGPoint(x: 55, y: 64), width: 28, height: 14, degrees: -18), with: .color(belly))

        if mood == .backpacker {
            let pack = Path(roundedRect: CGRect(x: 30, y: 42, width: 18, height: 20), cornerRadius: 5)
                .applying(rotation(degrees: -18, around: CGPoint(x: 39, y: 52)))
            context.fill(pack, with: .color(brown))
            var strap = Path()
            strap.move(to: CGPoint(x: 46, y: 45))
            strap.addQuadCurve(to: CGPoint(x: 58, y: 62), control: CGPoint(x: 58, y: 48))
            context.stroke(strap, with: .color(brown.opacity(0.9)), lineWidth: 2.5)
        }

        // Head, throat (Rumbo coral) and beak
        context.fill(Path(ellipseIn: CGRect(x: 54, y: 24, width: 28, height: 28)), with: .color(green))
        context.fill(Path(ellipseIn: CGRect(x: 58, y: 41, width: 17, height: 12)), with: .color(Palette.coral))
        var beak = Path()
        beak.move(to: CGPoint(x: 80, y: 35))
        beak.addLine(to: CGPoint(x: 99, y: 32))
        beak.addLine(to: CGPoint(x: 80, y: 40))
        beak.closeSubpath()
        context.fill(beak, with: .color(ink))

        if mood == .backpacker {
            // Little explorer hat
            context.fill(Path(ellipseIn: CGRect(x: 54, y: 22, width: 30, height: 7)), with: .color(brown))
            context.fill(Path(roundedRect: CGRect(x: 60, y: 14, width: 18, height: 11), cornerRadius: 4), with: .color(brown))
        }

        // Eye
        if sleepy {
            var lid = Path()
            lid.move(to: CGPoint(x: 67, y: 34))
            lid.addQuadCurve(to: CGPoint(x: 76, y: 34), control: CGPoint(x: 71.5, y: 38))
            context.stroke(lid, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
        } else {
            let blink = !still && t.truncatingRemainder(dividingBy: 4) < 0.12
            if blink {
                var lid = Path()
                lid.move(to: CGPoint(x: 67, y: 34))
                lid.addLine(to: CGPoint(x: 76, y: 34))
                context.stroke(lid, with: .color(ink), style: StrokeStyle(lineWidth: 2, lineCap: .round))
            } else {
                context.fill(Path(ellipseIn: CGRect(x: 67, y: 29, width: 9, height: 9)), with: .color(.white))
                context.fill(Path(ellipseIn: CGRect(x: 70, y: 31, width: 5, height: 5)), with: .color(ink))
                context.fill(Path(ellipseIn: CGRect(x: 71, y: 31.5, width: 1.8, height: 1.8)), with: .color(.white))
            }
        }

        if mood == .listening {
            var band = Path()
            band.move(to: CGPoint(x: 56, y: 36))
            band.addQuadCurve(to: CGPoint(x: 80, y: 32), control: CGPoint(x: 66, y: 12))
            context.stroke(band, with: .color(ink), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            context.fill(Path(ellipseIn: CGRect(x: 51, y: 31, width: 9, height: 12)), with: .color(Palette.coral))
        }

        // Wing: a fast flap with ghost copies for a blur, or folded when asleep.
        let pivot = CGPoint(x: 50, y: 48)
        if sleepy || still {
            drawWing(in: context, pivot: pivot, degrees: sleepy ? -12 : 30, opacity: 1)
        } else {
            let flap = 35 + sin(t * 2 * .pi * (excited ? 10 : 7)) * 40
            drawWing(in: context, pivot: pivot, degrees: flap - 22, opacity: 0.25)
            drawWing(in: context, pivot: pivot, degrees: flap + 22, opacity: 0.25)
            drawWing(in: context, pivot: pivot, degrees: flap, opacity: 1)
        }

        if excited && !still {
            drawSparkles(in: context, time: t)
        }
        if sleepy {
            drawZzz(in: context, time: still ? 0 : t)
        }
    }

    // MARK: Pieces

    private static func drawWing(in context: GraphicsContext, pivot: CGPoint, degrees: Double, opacity: Double) {
        var wing = context
        wing.opacity = opacity
        wing.translateBy(x: pivot.x, y: pivot.y)
        wing.rotate(by: .degrees(degrees))
        wing.fill(Path(ellipseIn: CGRect(x: -36, y: -7, width: 38, height: 13)), with: .color(greenDark))
        wing.fill(Path(ellipseIn: CGRect(x: -30, y: -4, width: 24, height: 6)), with: .color(green.opacity(0.6)))
    }

    private static func drawBranch(in context: GraphicsContext) {
        var branch = Path()
        branch.move(to: CGPoint(x: 10, y: 86))
        branch.addQuadCurve(to: CGPoint(x: 94, y: 82), control: CGPoint(x: 50, y: 90))
        context.stroke(branch, with: .color(brown), style: StrokeStyle(lineWidth: 5, lineCap: .round))
        context.fill(ellipse(center: CGPoint(x: 24, y: 80), width: 12, height: 6, degrees: -30), with: .color(green))
    }

    private static func drawSparkles(in context: GraphicsContext, time t: Double) {
        for index in 0..<5 {
            let angle = t * 1.6 + Double(index) * (2 * .pi / 5)
            let center = CGPoint(x: 50 + cos(angle) * 46, y: 50 + sin(angle) * 40)
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
                at: CGPoint(x: 84 + phase * 8, y: 22 - phase * 16)
            )
        }
    }

    // MARK: Geometry

    private static func ellipse(center: CGPoint, width: CGFloat, height: CGFloat, degrees: Double) -> Path {
        Path(ellipseIn: CGRect(x: center.x - width / 2, y: center.y - height / 2, width: width, height: height))
            .applying(rotation(degrees: degrees, around: center))
    }

    private static func rotation(degrees: Double, around point: CGPoint) -> CGAffineTransform {
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
