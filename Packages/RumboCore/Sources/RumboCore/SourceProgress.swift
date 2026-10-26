/// How Language Transfer and Extra en Español move forward as tasks are logged.
/// See docs/02-learning-engine.md §2.3 (`lt.track`, `extra.intensive`, `extra.extensive`).
public struct SourceProgress: Equatable, Codable, Sendable {
    public enum TrackRating: String, Codable, Sendable {
        case solid
        case shaky
    }

    public var languageTransferLastTrack: Int
    public var languageTransferRepeatPending: Bool
    public var extraEpisodesWatched: Int
    public var extraPartsDoneInEpisode: Int

    public init(languageTransferLastTrack: Int = 0, languageTransferRepeatPending: Bool = false, extraEpisodesWatched: Int = 0, extraPartsDoneInEpisode: Int = 0) {
        self.languageTransferLastTrack = languageTransferLastTrack
        self.languageTransferRepeatPending = languageTransferRepeatPending
        self.extraEpisodesWatched = extraEpisodesWatched
        self.extraPartsDoneInEpisode = extraPartsDoneInEpisode
    }

    /// Updates progress after a task is logged. Other task kinds don't move a course forward.
    public mutating func record(_ kind: TaskKind, trackRating: TrackRating? = nil) {
        switch kind {
        case .ltTrack:
            if languageTransferRepeatPending {
                // That was the one repeat; move on whatever the rating.
                languageTransferRepeatPending = false
            } else {
                languageTransferLastTrack = min(languageTransferLastTrack + 1, Course.languageTransferTracks)
                languageTransferRepeatPending = trackRating == .shaky
            }
        case .extraIntensive:
            extraPartsDoneInEpisode += 1
            if extraPartsDoneInEpisode >= Course.extraIntensivePartsPerEpisode {
                finishExtraEpisode()
            }
        case .extraExtensive:
            finishExtraEpisode()
        default:
            break
        }
    }

    private mutating func finishExtraEpisode() {
        extraEpisodesWatched = min(extraEpisodesWatched + 1, Course.extraEpisodes)
        extraPartsDoneInEpisode = 0
    }
}
