import AppIntents
import Foundation

/// The Pause / Resume button on the Live Activity. Live Activity intents run in the app's process,
/// so the app registers what pausing does at launch; the widget extension only needs the type.
struct PauseTimerIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or resume the timer"

    init() {}

    func perform() async throws -> some IntentResult {
        await MainActor.run { TimerControl.togglePause?() }
        return .result()
    }
}

@MainActor
enum TimerControl {
    /// Set by the app at launch.
    static var togglePause: (() -> Void)?
}
