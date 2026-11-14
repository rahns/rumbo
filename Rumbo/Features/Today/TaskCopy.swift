import RumboCore

/// User-facing wording for each task kind. Source names come from the language being learned.
enum TaskCopy {
    private static var pack: LanguagePack { ActiveLanguage.pack }
    private static func name(_ source: SourceKind) -> String { pack.sources[source]?.name ?? "" }
    private static func short(_ source: SourceKind) -> String { pack.sources[source]?.shortName ?? "" }

    static func title(for task: TaskKind) -> String {
        switch task {
        case .drillLesson: "\(short(.drillApp)) warm-up"
        case .courseTrack: name(.audioCourse)
        case .gradedWatch: name(.gradedVideo)
        case .gradedEasy: "Easy \(short(.gradedVideo))"
        case .seriesIntensive: name(.learnerSeries)
        case .seriesExtensive: name(.learnerSeries)
        case .contentWatch: "Watch or listen"
        case .writeGuided: "Writing"
        case .writeQuick: "Quick write"
        case .exchangeText: "\(short(.exchange)) message"
        case .exchangeVoice: "\(short(.exchange)) voice note"
        case .exchangeCall: "\(short(.exchange)) call"
        case .fluency432: "4 · 3 · 2 story"
        case .reviewMistakes: "Mistake review"
        case .missionTravel: "Travel mission"
        case .otherStudy: "Other grammar & vocab"
        case .otherOutput: "Other speaking & writing"
        case .otherFluency: "Other fluency practice"
        case .lessonOutput, .lessonInput, .lessonStudy, .lessonMixed: "Class/Tutoring"
        }
    }

    static func symbol(for task: TaskKind) -> String {
        switch task {
        case .drillLesson: "bolt.fill"
        case .courseTrack: "headphones"
        case .gradedWatch, .gradedEasy: "play.tv.fill"
        case .seriesIntensive, .seriesExtensive: "film.fill"
        case .contentWatch: "sparkles.tv.fill"
        case .writeGuided: "pencil.and.scribble"
        case .writeQuick: "timer"
        case .exchangeText: "bubble.left.and.bubble.right.fill"
        case .exchangeVoice: "waveform"
        case .exchangeCall: "phone.fill"
        case .fluency432: "stopwatch.fill"
        case .reviewMistakes: "arrow.triangle.2.circlepath"
        case .missionTravel: "backpack.fill"
        case .otherStudy: "book.fill"
        case .otherOutput: "text.bubble.fill"
        case .otherFluency: "hare.fill"
        case .lessonOutput, .lessonInput, .lessonStudy, .lessonMixed: "person.2.fill"
        }
    }

    /// The specific thing to do, e.g. "Track 13" or "Videos rated 40–48".
    static func detail(_ detail: TaskDetail) -> String? {
        switch detail {
        case .none: nil
        case .track(let track): "Track \(track)"
        case .seriesPart(let episode, let part): "Episode \(episode), part \(part) of \(pack.series?.intensiveParts ?? part)"
        case .seriesEpisode(let episode): "Episode \(episode)"
        case .difficulty(let range): "Videos rated \(range.lowerBound)–\(range.upperBound)"
        }
    }

    /// A one-line "why", for tasks whose point isn't obvious from the name.
    static func purpose(for task: TaskKind) -> String? {
        switch task {
        case .lessonOutput: "Speaking & writing · counts toward today's time"
        case .lessonInput: "Listening · counts toward today's time"
        case .lessonStudy: "Grammar & vocab · counts toward today's time"
        case .lessonMixed: "All-in-one · split across speaking, listening and grammar"
        case .gradedEasy: "Below your level on purpose: easy listening makes what you know come faster."
        default: nil
        }
    }

    /// How to do the task, shown in the task session.
    static func instructions(for task: TaskKind, detail: TaskDetail, band: Band) -> String {
        switch task {
        case .drillLesson:
            "Do one or two lessons to warm up your recall."
        case .courseTrack:
            if case .track(let track) = detail {
                "Listen to track \(track). Pause before each answer and say it out loud before the student does."
            } else {
                "Listen to your next track and answer out loud before the student does."
            }
        case .gradedWatch:
            "Pick a video in your range that looks interesting. Aim to understand most of it; don't pause to look words up."
        case .gradedEasy:
            "Watch something easy, below your level, at normal speed. Easy and fast builds fluency."
        case .seriesIntensive:
            if case .seriesPart(_, let part) = detail, part == 1 {
                "Watch the first half with \(pack.name) subtitles. Then rewatch one short scene and shadow it: speak along with the actors for 2–3 minutes."
            } else {
                "Watch the second half with \(pack.name) subtitles. Then pick one short scene and shadow it for 2–3 minutes."
            }
        case .seriesExtensive:
            "Watch the whole episode for enjoyment. Subtitles only if you get lost."
        case .contentWatch:
            "Watch or listen to what you picked in Library, or any \(pack.name) you enjoy. Follow the story; don't stop to look words up."
        case .writeGuided:
            band < .a2_1
                ? "Write \(Prompts.wordTarget(for: band).lowerBound)–\(Prompts.wordTarget(for: band).upperBound) words in short, simple sentences, with words you know. Looking up a word or two is fine."
                : "Write \(Prompts.wordTarget(for: band).lowerBound)–\(Prompts.wordTarget(for: band).upperBound) words. Don't look things up while writing; check afterwards."
        case .writeQuick:
            "Write as much as you can for 5 minutes on an easy topic. No corrections, no dictionary. Just keep going."
        case .exchangeText:
            "Send your partner a message using the prompt. Ask them to correct anything that sounds odd."
        case .exchangeVoice:
            "Spend 3 minutes writing bullet points (not sentences), then record a 1–2 minute voice note."
        case .exchangeCall:
            "Have a short call. Before it, jot down three questions you want to ask."
        case .fluency432:
            "Tell the story out loud in 4 minutes, then the same story in 3, then in 2. Record yourself or send it as voice notes."
        case .reviewMistakes:
            "Review the mistakes that are due."
        case .missionTravel:
            "Do it for real, then come back and log it."
        case .otherStudy, .otherOutput, .otherFluency:
            "Logged with Log other."
        case .lessonOutput, .lessonInput, .lessonStudy, .lessonMixed:
            "Your class or tutoring today. Log it once it's done."
        }
    }

    /// A sentence nudging output to reuse today's structure (R4).
    static func reuseHint(for focus: TaskDetail) -> String? {
        switch focus {
        case .track(let track): "Try to use something from \(name(.audioCourse)) track \(track)."
        case .seriesPart(let episode, _), .seriesEpisode(let episode): "Try to reuse a phrase from Extra episode \(episode)."
        default: nil
        }
    }

    /// "Log other": what each kind of practice covers, and its name in the form.
    static func otherName(_ strand: Strand) -> String {
        switch strand {
        case .input: "Listening"
        case .languageFocused: "Grammar & vocab"
        case .output: "Speaking & writing"
        case .fluency: "Fluency practice"
        }
    }

    /// A lesson type's name: the strand's, or "All-in-one".
    static func lessonTypeName(_ type: LessonType) -> String {
        type.strand.map(otherName) ?? "All-in-one"
    }

    static func otherExamples(_ strand: Strand) -> String {
        switch strand {
        case .input: "Podcasts, a show, a tour in \(pack.name), a long conversation you mostly listened to."
        case .languageFocused: "A grammar book, a class, flashcards, another app."
        case .output: "A conversation, a class where you spoke, messages or a diary in \(pack.name)."
        case .fluency: "Easy reading or listening at speed, retelling a story, chatting about familiar things."
        }
    }

    /// All-in-one other practice: split across speaking & writing, listening and grammar & vocab.
    static let allInOneSymbol = "square.stack.3d.up.fill"
    static let allInOneExamples = "A class, tutoring or an exchange that mixed speaking, listening and grammar. It's split evenly across the three."

    static func otherSymbol(_ strand: Strand) -> String {
        strand == .input ? "ear.fill" : symbol(for: TaskKind.other(for: strand))
    }

    static func minutesLabel(_ minutes: Int) -> String {
        "\(minutes) min"
    }
}
