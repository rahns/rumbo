import ActivityKit
import Foundation

/// Live Activity for a running task timer (Lock Screen + Dynamic Island).
struct RumboTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// When the timer would have started had it never been paused, so `Text(timerInterval:)` counts correctly.
        var startedAt: Date
        var endsAt: Date
        var isPaused: Bool = false
        /// Elapsed seconds frozen at the moment of pausing.
        var pausedElapsed: Double = 0
    }

    var taskTitle: String
    var sourceSymbol: String
    /// The task's strand colour as a hex value, so the activity matches the card.
    var colorHex: UInt32
}
