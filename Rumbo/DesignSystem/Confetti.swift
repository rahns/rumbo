import SwiftUI

/// A burst of confetti from the middle of the view whenever `trigger` changes. Skipped with Reduce Motion.
struct ConfettiView: View {
    let trigger: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?
    @State private var pieces: [ConfettiPiece] = []

    private static let duration: TimeInterval = 2.6
    private static let gravity: Double = 900

    var body: some View {
        TimelineView(.animation(paused: startedAt == nil)) { timeline in
            Canvas { context, size in
                guard let startedAt else { return }
                let t = timeline.date.timeIntervalSince(startedAt)
                guard t >= 0, t < Self.duration else { return }
                for piece in pieces {
                    let x = size.width * 0.5 + piece.velocity.dx * t
                    let y = size.height * 0.45 + piece.velocity.dy * t + 0.5 * Self.gravity * t * t
                    var drawing = context
                    drawing.opacity = max(0, 1 - t / Self.duration)
                    drawing.translateBy(x: x, y: y)
                    drawing.rotate(by: .degrees(piece.spin * t))
                    drawing.fill(Path(roundedRect: CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2,
                                                          width: piece.size.width, height: piece.size.height), cornerRadius: 1.5),
                                 with: .color(piece.color))
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) { _, _ in
            guard !reduceMotion else { return }
            pieces = (0..<90).map { _ in ConfettiPiece.random() }
            startedAt = .now
            Task {
                try? await Task.sleep(for: .seconds(Self.duration + 0.1))
                startedAt = nil
            }
        }
    }
}

struct ConfettiPiece {
    var velocity: CGVector
    var spin: Double
    var size: CGSize
    var color: Color

    static func random() -> ConfettiPiece {
        let angle = Double.random(in: (-160 * .pi / 180)...(-20 * .pi / 180))
        let speed = Double.random(in: 350...800)
        return ConfettiPiece(
            velocity: CGVector(dx: cos(angle) * speed, dy: sin(angle) * speed),
            spin: Double.random(in: -540...540),
            size: CGSize(width: Double.random(in: 6...10), height: Double.random(in: 4...6)),
            color: [Palette.coral, Palette.sun, Palette.leaf, Palette.sky, Palette.lilac].randomElement()!
        )
    }
}
