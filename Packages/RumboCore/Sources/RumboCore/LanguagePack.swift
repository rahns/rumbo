import Foundation

/// Everything about one language being learned: its sources and their numbers, the hours each level
/// starts at, the tutor's checklist, and the words the app decorates itself with. The engine and the app
/// read the active pack; nothing else names a language. See docs/09-multi-language.md.
public struct LanguagePack: Sendable, Identifiable {
    /// BCP 47 code, e.g. "es". Stored on every record (`languageCode`).
    public let code: String
    /// The language's name in English ("Spanish"), used in the app's sentences.
    public let name: String
    /// Its own name ("Español"), for the language picker.
    public let nativeName: String
    /// Locale for day and month names on the path.
    public let localeIdentifier: String
    public let levels: LevelScale
    /// The product that fills each role, with its wording. A role with no entry doesn't exist for this
    /// language: it isn't offered, and its tasks are never planned.
    public let sources: [SourceKind: SourceInfo]
    public let course: AudioCourse?
    public let series: LearnerSeries?
    public let graded: GradedVideo?
    public let drill: DrillApp?
    public let anchors: [Band: AnchorTargets]
    public let tutor: Tutor
    public let phrases: Phrasebook
    public let catalog: CatalogSource
    /// Prompts and can-do statements that only make sense for this language, added to the shared lists.
    public let extraTravelMissions: [String]

    public var id: String { code }
    public var locale: Locale { Locale(identifier: localeIdentifier) }

    public init(code: String, name: String, nativeName: String, localeIdentifier: String, levels: LevelScale,
                sources: [SourceKind: SourceInfo], course: AudioCourse?, series: LearnerSeries?, graded: GradedVideo?,
                drill: DrillApp?, anchors: [Band: AnchorTargets], tutor: Tutor, phrases: Phrasebook,
                catalog: CatalogSource, extraTravelMissions: [String] = []) {
        self.code = code
        self.name = name
        self.nativeName = nativeName
        self.localeIdentifier = localeIdentifier
        self.levels = levels
        self.sources = sources
        self.course = course
        self.series = series
        self.graded = graded
        self.drill = drill
        self.anchors = anchors
        self.tutor = tutor
        self.phrases = phrases
        self.catalog = catalog
        self.extraTravelMissions = extraTravelMissions
    }

    /// Every language the app can teach.
    public static let all: [LanguagePack] = [.spanish]
    /// Shown in the language picker as on the way.
    public static let upcoming: [String] = ["French"]
    /// The language of records saved before languages were tagged.
    public static let defaultCode = "es"

    /// The pack for a stored code; Spanish for an unknown or missing one.
    public static func pack(for code: String?) -> LanguagePack {
        all.first { $0.code == code } ?? .spanish
    }

    /// Whether the language has a source for `role`.
    public func has(_ role: SourceKind) -> Bool { sources[role] != nil }

    /// The roles this language offers, in the app's usual order.
    public var roles: [SourceKind] { SourceKind.allCases.filter(has) }

    public func anchorTargets(for band: Band) -> AnchorTargets { anchors[band] ?? AnchorTargets() }

    /// Fills `{language}` in shared wording ("Order food entirely in {language}").
    public func fill(_ text: String) -> String {
        text.replacingOccurrences(of: "{language}", with: name)
    }

    /// The level's friendly name ("Explorador").
    public func levelName(_ band: Band) -> String { phrases.levelNames[band] ?? band.rawValue }
}

/// Training hours (all practice, every minute counted) at which each level starts.
public struct LevelScale: Equatable, Sendable {
    public let hours: [Band: Double]

    public init(_ hours: [Band: Double]) {
        self.hours = hours
    }

    public func threshold(_ band: Band) -> Double { hours[band] ?? 0 }

    /// The level an amount of training hours falls into, before any can-do adjustment.
    /// Learners below the first level's threshold are still placed in it.
    public func band(forHours hours: Double) -> Band {
        Band.allCases.last { hours >= threshold($0) } ?? .a2_1
    }
}

/// How a source is described to the learner, and how to open it.
public struct SourceInfo: Equatable, Sendable {
    public struct Link: Equatable, Sendable {
        public let title: String
        public let url: String

        public init(_ title: String, _ url: String) {
            self.title = title
            self.url = url
        }
    }

    public let name: String
    /// One line under the name in onboarding ("Your main listening engine").
    public let role: String
    /// SF Symbol.
    public let symbol: String
    public let what: String
    public let whereToFind: String
    public let links: [Link]
    /// What switching it on adds to the plan, when that isn't obvious.
    public let inYourPlan: String?
    /// Opens the source's app ("duolingo://"), if it has one.
    public let appURL: String?
    /// Opened when the app isn't installed.
    public let webURL: String?

    public init(name: String, role: String, symbol: String, what: String, whereToFind: String, links: [Link] = [],
                inYourPlan: String? = nil, appURL: String? = nil, webURL: String? = nil) {
        self.name = name
        self.role = role
        self.symbol = symbol
        self.what = what
        self.whereToFind = whereToFind
        self.links = links
        self.inYourPlan = inYourPlan
        self.appURL = appURL
        self.webURL = webURL
    }
}

/// An audio course worked through one track at a time (Language Transfer).
public struct AudioCourse: Equatable, Sendable {
    /// Length of each track in seconds, track 1 first.
    public let trackSeconds: [Int]

    public init(trackSeconds: [Int]) {
        self.trackSeconds = trackSeconds
    }

    public var tracks: Int { trackSeconds.count }

    /// Minutes to plan for a track: its real length, rounded up.
    public func minutes(track: Int) -> Int {
        guard !trackSeconds.isEmpty else { return 0 }
        let index = min(max(track, 1), tracks) - 1
        return Int((Double(trackSeconds[index]) / 60).rounded(.up))
    }
}

/// A series made for learners, watched an episode at a time (Extra).
public struct LearnerSeries: Equatable, Sendable {
    public let episodes: Int
    /// At the intensive levels, one episode is split into this many parts.
    public let intensiveParts: Int
    /// Levels that watch it in parts, with subtitles and shadowing.
    public let intensiveBands: ClosedRange<Band>
    /// Levels that watch whole episodes for enjoyment.
    public let extensiveBands: ClosedRange<Band>
    /// Days with less time than this stay with the main listening source.
    public let minimumBudget: Int
    /// Searched on YouTube with the episode number appended ("Extra en Español episodio").
    public let searchPrefix: String

    public init(episodes: Int, intensiveParts: Int, intensiveBands: ClosedRange<Band>, extensiveBands: ClosedRange<Band>,
                minimumBudget: Int, searchPrefix: String) {
        self.episodes = episodes
        self.intensiveParts = intensiveParts
        self.intensiveBands = intensiveBands
        self.extensiveBands = extensiveBands
        self.minimumBudget = minimumBudget
        self.searchPrefix = searchPrefix
    }
}

/// A video library graded by difficulty (Dreaming Spanish).
public struct GradedVideo: Equatable, Sendable {
    /// The difficulty scale videos are rated on.
    public let scale: ClosedRange<Int>
    /// The learner's range is always this wide (40–45).
    public let windowWidth: Int
    /// Easy viewing for fluency sits this far below the range's lower end.
    public let easyOffset: ClosedRange<Int>
    /// It counts the learner's hours, so onboarding can ask for that number.
    public let countsHours: Bool

    public init(scale: ClosedRange<Int>, windowWidth: Int, easyOffset: ClosedRange<Int>, countsHours: Bool) {
        self.scale = scale
        self.windowWidth = windowWidth
        self.easyOffset = easyOffset
        self.countsHours = countsHours
    }

    /// The easy range for a learner whose range starts at `lowerBound`.
    public func easyRange(below lowerBound: Int) -> ClosedRange<Int> {
        let low = max(scale.lowerBound, lowerBound - easyOffset.upperBound)
        let high = max(low, lowerBound - easyOffset.lowerBound)
        return low...high
    }
}

/// A drill app used as a short daily warm-up (Duolingo).
public struct DrillApp: Equatable, Sendable {
    /// A daily warm-up up to this level.
    public let lastBand: Band
    /// Optional at this level (the learner chooses), and dropped after it.
    public let optionalBand: Band?
    /// How the app counts progress, for Settings.
    public let sections: ClosedRange<Int>
    public let units: ClosedRange<Int>

    public init(lastBand: Band, optionalBand: Band?, sections: ClosedRange<Int>, units: ClosedRange<Int>) {
        self.lastBand = lastBand
        self.optionalBand = optionalBand
        self.sections = sections
        self.units = units
    }
}

/// How often each anchor should happen in a rolling 7 days (docs/02-learning-engine.md §2.5 "Weekly anchors").
public struct AnchorTargets: Equatable, Sendable {
    public var writing: Int
    public var seriesIntensiveParts: Int
    public var seriesEpisodes: Int
    public var exchanges: Int
    public var fluency432: Int

    public init(writing: Int = 0, seriesIntensiveParts: Int = 0, seriesEpisodes: Int = 0, exchanges: Int = 0, fluency432: Int = 0) {
        self.writing = writing
        self.seriesIntensiveParts = seriesIntensiveParts
        self.seriesEpisodes = seriesEpisodes
        self.exchanges = exchanges
        self.fluency432 = fluency432
    }
}

/// What the writing checker is told about the language.
public struct Tutor: Equatable, Sendable {
    /// The things to check, as the middle of a sentence ("that verb tenses match time expressions (…), …").
    public let focus: String
    /// LanguageTool's code for the basic checker, or nil if it doesn't cover the language.
    public let languageToolCode: String?
    /// From this level, explanations are in the language itself; below it, in English.
    public let explainInLanguageFrom: Band?

    public init(focus: String, languageToolCode: String?, explainInLanguageFrom: Band?) {
        self.focus = focus
        self.languageToolCode = languageToolCode
        self.explainInLanguageFrom = explainInLanguageFrom
    }

    /// The checker's instructions for a learner at `band`.
    public func instructions(language: String, band: Band, maximumErrors: Int) -> String {
        let explainIn = explainInLanguageFrom.map { band >= $0 } == true ? "in simple \(language)" : "in English"
        return "You are a warm, encouraging \(language) tutor for a \(band.rawValue) learner (CEFR). Find the real errors in the learner's text, "
            + "most important first, at most \(maximumErrors). Check \(focus), and phrasing a native speaker "
            + "wouldn't use. Use the grammar checker's hints when given. Never list something that is already correct. Copy the wrong words exactly as the learner wrote them. "
            + "Explain each error in one short sentence \(explainIn), at the learner's level. Also give one or two specific things they did well."
    }
}

/// Where the suggested shows and podcasts come from.
public struct CatalogSource: Equatable, Sendable {
    /// Bundled file name without ".json".
    public let resource: String
    /// The newest copy, checked when online.
    public let remoteURL: String
    /// Cache file name for a downloaded copy.
    public let cacheFile: String

    public init(resource: String, remoteURL: String, cacheFile: String) {
        self.resource = resource
        self.remoteURL = remoteURL
        self.cacheFile = cacheFile
    }
}

/// The words of the language the app decorates itself with. Every field is required, so a language
/// can't ship with one missing.
public struct Phrasebook: Equatable, Sendable {
    /// "Semana": followed by the week's number.
    public let week: String
    /// A week that's over.
    public let weekComplete: String
    /// A week with no missed day.
    public let weekCompleteGold: String
    public let today: String
    public let done: String
    /// Greetings without their closing mark ("¡Buenos días"); a name may follow.
    public let goodMorning: String
    public let goodAfternoon: String
    public let goodEvening: String
    /// Closes a greeting ("!", or " !" in French).
    public let exclamationEnd: String
    public let hello: String
    public let yes: String
    public let congratulations: String
    public let letsGo: String
    public let wellDone: String
    public let amazing: String
    public let goalReached: String
    /// "%d" is the number of days ("¡%d días seguidos!").
    public let daysInARow: String
    /// The daily reminder's title.
    public let reminderTitle: String
    /// What Pico says when tapped.
    public let squawks: [String]
    public let levelNames: [Band: String]

    public init(week: String, weekComplete: String, weekCompleteGold: String, today: String, done: String,
                goodMorning: String, goodAfternoon: String, goodEvening: String, exclamationEnd: String, hello: String,
                yes: String, congratulations: String, letsGo: String, wellDone: String, amazing: String, goalReached: String,
                daysInARow: String, reminderTitle: String, squawks: [String], levelNames: [Band: String]) {
        self.week = week
        self.weekComplete = weekComplete
        self.weekCompleteGold = weekCompleteGold
        self.today = today
        self.done = done
        self.goodMorning = goodMorning
        self.goodAfternoon = goodAfternoon
        self.goodEvening = goodEvening
        self.exclamationEnd = exclamationEnd
        self.hello = hello
        self.yes = yes
        self.congratulations = congratulations
        self.letsGo = letsGo
        self.wellDone = wellDone
        self.amazing = amazing
        self.goalReached = goalReached
        self.daysInARow = daysInARow
        self.reminderTitle = reminderTitle
        self.squawks = squawks
        self.levelNames = levelNames
    }

    /// "¡Buenas tardes, Ana!" for the hour of the day (0–23); without a name, just the greeting.
    public func greeting(hour: Int, name: String) -> String {
        let hello = hour < 12 ? goodMorning : hour < 20 ? goodAfternoon : goodEvening
        return name.isEmpty ? hello + exclamationEnd : "\(hello), \(name)\(exclamationEnd)"
    }

    public func streak(days: Int) -> String {
        daysInARow.replacingOccurrences(of: "%d", with: String(days))
    }

    /// Every string, for checking that none is empty.
    public var allStrings: [String] {
        [week, weekComplete, weekCompleteGold, today, done, goodMorning, goodAfternoon, goodEvening, exclamationEnd, hello,
         yes, congratulations, letsGo, wellDone, amazing, goalReached, daysInARow, reminderTitle] + squawks + Band.allCases.map { levelNames[$0] ?? "" }
    }
}
