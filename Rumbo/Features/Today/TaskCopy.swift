import RumboCore

/// User-facing wording for each task kind.
enum TaskCopy {
    static func title(for task: TaskKind) -> String {
        switch task {
        case .duoLesson: "Duolingo warm-up"
        case .ltTrack: "Language Transfer"
        case .dsWatch: "Dreaming Spanish"
        case .dsEasy: "Easy Dreaming"
        case .extraIntensive: "Extra en Español"
        case .extraExtensive: "Extra en Español"
        case .contentWatch: "Watch or listen"
        case .writeGuided: "Writing"
        case .writeQuick: "Quick write"
        case .tandemText: "Tandem message"
        case .tandemVoice: "Tandem voice note"
        case .tandemCall: "Tandem call"
        case .fluency432: "4 · 3 · 2 story"
        case .reviewMistakes: "Mistake review"
        case .missionTravel: "Travel mission"
        }
    }

    static func symbol(for task: TaskKind) -> String {
        switch task {
        case .duoLesson: "bolt.fill"
        case .ltTrack: "headphones"
        case .dsWatch, .dsEasy: "play.tv.fill"
        case .extraIntensive, .extraExtensive: "film.fill"
        case .contentWatch: "sparkles.tv.fill"
        case .writeGuided: "pencil.and.scribble"
        case .writeQuick: "timer"
        case .tandemText: "bubble.left.and.bubble.right.fill"
        case .tandemVoice: "waveform"
        case .tandemCall: "phone.fill"
        case .fluency432: "stopwatch.fill"
        case .reviewMistakes: "arrow.triangle.2.circlepath"
        case .missionTravel: "backpack.fill"
        }
    }

    /// The specific thing to do, e.g. "Track 13" or "Videos rated 40–48".
    static func detail(_ detail: TaskDetail) -> String? {
        switch detail {
        case .none: nil
        case .languageTransferTrack(let track): "Track \(track)"
        case .extraPart(let episode, let part): "Episode \(episode), part \(part) of \(Course.extraIntensivePartsPerEpisode)"
        case .extraEpisode(let episode): "Episode \(episode)"
        case .dreamingDifficulty(let range): "Videos rated \(range.lowerBound)–\(range.upperBound)"
        }
    }

    /// How to do the task, shown in the task session.
    static func instructions(for task: TaskKind, detail: TaskDetail, band: Band) -> String {
        switch task {
        case .duoLesson:
            "Do one or two lessons to warm up your recall."
        case .ltTrack:
            if case .languageTransferTrack(let track) = detail {
                "Listen to track \(track). Pause before each answer and say it out loud before the student does."
            } else {
                "Listen to your next track and answer out loud before the student does."
            }
        case .dsWatch:
            "Pick a video in your range that looks interesting. Aim to understand most of it; don't pause to look words up."
        case .dsEasy:
            "Watch something easy, below your level, at normal speed. Easy and fast builds fluency."
        case .extraIntensive:
            if case .extraPart(_, let part) = detail, part == 1 {
                "Watch the first half with Spanish subtitles. Then rewatch one short scene and shadow it: speak along with the actors for 2–3 minutes."
            } else {
                "Watch the second half with Spanish subtitles. Then pick one short scene and shadow it for 2–3 minutes."
            }
        case .extraExtensive:
            "Watch the whole episode for enjoyment. Subtitles only if you get lost."
        case .contentWatch:
            "Watch or listen to something from your Library suggestions, or any Spanish you enjoy."
        case .writeGuided:
            "Write \(Prompts.wordTarget(for: band).lowerBound)–\(Prompts.wordTarget(for: band).upperBound) words. Don't look things up while writing; check afterwards."
        case .writeQuick:
            "Write as much as you can for 5 minutes on an easy topic. No corrections, no dictionary. Just keep going."
        case .tandemText:
            "Send your partner a message using the prompt. Ask them to correct anything that sounds odd."
        case .tandemVoice:
            "Spend 3 minutes writing bullet points (not sentences), then record a 1–2 minute voice note."
        case .tandemCall:
            "Have a short call. Before it, jot down three questions you want to ask."
        case .fluency432:
            "Tell the story out loud in 4 minutes, then the same story in 3, then in 2. Record yourself or send it as voice notes."
        case .reviewMistakes:
            "Review the mistakes that are due."
        case .missionTravel:
            "Do it for real, then come back and log it."
        }
    }

    /// A sentence nudging output to reuse today's structure (R4).
    static func reuseHint(for focus: TaskDetail) -> String? {
        switch focus {
        case .languageTransferTrack(let track): "Try to use something from Language Transfer track \(track)."
        case .extraPart(let episode, _), .extraEpisode(let episode): "Try to reuse a phrase from Extra episode \(episode)."
        default: nil
        }
    }

    static func minutesLabel(_ minutes: Int) -> String {
        "\(minutes) min"
    }
}
