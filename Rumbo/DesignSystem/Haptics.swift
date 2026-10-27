import UIKit

/// Haptic patterns for celebration moments (docs/03-experience.md §3.5). Everyday taps use `.sensoryFeedback`.
@MainActor
enum Haptics {
    static func tap(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .light, intensity: CGFloat = 1) {
        UIImpactFeedbackGenerator(style: style).impactOccurred(intensity: intensity)
    }

    /// `count` taps in a row, e.g. one per quarter of the weekly goal just passed.
    static func taps(_ count: Int, style: UIImpactFeedbackGenerator.FeedbackStyle = .light, spacing: Double = 0.12) {
        for index in 0..<count {
            DispatchQueue.main.asyncAfter(deadline: .now() + spacing * Double(index)) { tap(style) }
        }
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Two beats, twice: for streak milestones.
    static func heartbeat() {
        for (delay, style) in [(0.0, UIImpactFeedbackGenerator.FeedbackStyle.heavy), (0.14, .medium), (0.6, .heavy), (0.74, .medium)] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { tap(style) }
        }
    }

    /// A firm thud: a stamp landing.
    static func stamp() {
        tap(.heavy)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { tap(.rigid, intensity: 0.7) }
    }

    /// A crisp crack: ice breaking.
    static func crack() {
        tap(.rigid)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { tap(.light) }
    }
}
