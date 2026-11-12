/// How the audio course and the learner series move forward as tasks are logged.
/// Stored with each planned task (for undo), under the names from when Spanish was the only language.
/// See docs/02-learning-engine.md §2.3 (`lt.track`, `extra.intensive`, `extra.extensive`).
public struct SourceProgress: Equatable, Codable, Sendable {
    public enum TrackRating: String, Codable, Sendable {
        case solid
        case shaky
    }

    public var courseLastTrack: Int
    public var courseRepeatPending: Bool
    public var seriesEpisodesWatched: Int
    public var seriesPartsDone: Int

    enum CodingKeys: String, CodingKey {
        case courseLastTrack = "languageTransferLastTrack"
        case courseRepeatPending = "languageTransferRepeatPending"
        case seriesEpisodesWatched = "extraEpisodesWatched"
        case seriesPartsDone = "extraPartsDoneInEpisode"
    }

    public init(courseLastTrack: Int = 0, courseRepeatPending: Bool = false, seriesEpisodesWatched: Int = 0, seriesPartsDone: Int = 0) {
        self.courseLastTrack = courseLastTrack
        self.courseRepeatPending = courseRepeatPending
        self.seriesEpisodesWatched = seriesEpisodesWatched
        self.seriesPartsDone = seriesPartsDone
    }

    /// Updates progress after a task is logged. Other task kinds don't move a course forward.
    public mutating func record(_ kind: TaskKind, trackRating: TrackRating? = nil, pack: LanguagePack) {
        switch kind {
        case .courseTrack:
            if courseRepeatPending {
                // That was the one repeat; move on whatever the rating.
                courseRepeatPending = false
            } else {
                courseLastTrack = min(courseLastTrack + 1, pack.course?.tracks ?? 0)
                courseRepeatPending = trackRating == .shaky
            }
        case .seriesIntensive:
            seriesPartsDone += 1
            if seriesPartsDone >= (pack.series?.intensiveParts ?? 1) {
                finishEpisode(pack)
            }
        case .seriesExtensive:
            finishEpisode(pack)
        default:
            break
        }
    }

    /// Reverses `record(kind)` by restoring only the fields that kind changes from `before`,
    /// so undoing one task doesn't roll back progress made by another task since.
    public mutating func undo(_ kind: TaskKind, before: SourceProgress) {
        switch kind {
        case .courseTrack:
            courseLastTrack = before.courseLastTrack
            courseRepeatPending = before.courseRepeatPending
        case .seriesIntensive, .seriesExtensive:
            seriesEpisodesWatched = before.seriesEpisodesWatched
            seriesPartsDone = before.seriesPartsDone
        default:
            break
        }
    }

    private mutating func finishEpisode(_ pack: LanguagePack) {
        seriesEpisodesWatched = min(seriesEpisodesWatched + 1, pack.series?.episodes ?? 0)
        seriesPartsDone = 0
    }
}
