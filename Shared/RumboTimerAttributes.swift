import ActivityKit
import Foundation

/// Live Activity for a running task timer (Lock Screen + Dynamic Island).
struct RumboTimerAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startedAt: Date
        var endsAt: Date
    }

    var taskTitle: String
    var sourceSymbol: String
}
