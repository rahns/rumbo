import Foundation

extension LanguagePack {
    /// French. Its sources mirror Spanish's (Dreaming, Language Transfer, Extra, Duolingo), with two differences
    /// that matter to the plan: the audio course is an introduction of 40 tracks, so it runs out early, and
    /// the level hours are a little higher. See docs/09-multi-language.md §9.7 for where each number comes from.
    public static let french = LanguagePack(
        code: "fr",
        name: "French",
        nativeName: "Français",
        flag: "🇫🇷",
        localeIdentifier: "fr",
        // Spanish's hours raised by 15%, rounded to 10. Dreaming publishes no French roadmap; its FAQ says the
        // early phase "may be slightly longer if instead of Spanish or Italian you are learning Portuguese,
        // or especially French". A judgement, to revisit if Dreaming publishes French milestones.
        levels: LevelScale([.a1_1: 0, .a1_2: 100, .a2_1: 310, .a2_2: 470, .b1_1: 630, .b1_2: 940, .b2_1: 1250, .b2_2: 1670]),
        sources: [
            .gradedVideo: SourceInfo(
                name: "Dreaming French",
                shortName: "Dreaming",
                role: "Your main listening engine",
                symbol: "play.tv.fill",
                what: "A video library of French made to be understood: videos where native speakers explain, chat and tell stories, using pictures and gestures at the easy levels. Videos are graded by difficulty, and it counts your hours of listening. It's built on comprehensible input: you pick up French by understanding lots of it. It's from the makers of Dreaming Spanish, on the same site and app.",
                whereToFind: "The Dreaming app and dreaming.com/french.",
                links: [.init("Open dreaming.com", "https://www.dreaming.com/french")],
                appURL: "dreaming://",
                webURL: "https://www.dreaming.com/french"),
            .audioCourse: SourceInfo(
                name: "Language Transfer",
                role: "Grammar head start, from zero",
                symbol: "headphones",
                what: "\"Introduction to French\": a free audio course of 40 short tracks, about six and a half hours in all. A teacher guides a student to build sentences by thinking, not memorising, and you answer out loud before the student does. It's an introduction, so it gives you the main structures of French and then hands over to your other sources.",
                whereToFind: "The free Language Transfer app or languagetransfer.org.",
                links: [.init("Open languagetransfer.org", "https://www.languagetransfer.org/french")],
                appURL: "languagetransfer://",
                webURL: "https://www.languagetransfer.org/french"),
            .learnerSeries: SourceInfo(
                name: "Extra French",
                shortName: "Extra",
                role: "Sitcom with subtitles and shadowing",
                symbol: "film.fill",
                what: "A sitcom made for French learners (also written \"Extr@\"): 13 episodes about flatmates in Paris and an American friend who arrives knowing little French. The speech is clear and slow at first, and it's funny.",
                whereToFind: "Free on YouTube: search \"Extra French\".",
                links: [.init("Search on YouTube", "https://www.youtube.com/results?search_query=Extra%20French%20episode%201")]),
            .drillApp: SourceInfo(
                name: "Duolingo",
                role: "Short daily warm-up",
                symbol: "bolt.fill",
                what: "The green-owl app of short, game-like lessons and a daily streak.",
                whereToFind: "The Duolingo app and duolingo.com.",
                links: [.init("Open duolingo.com", "https://www.duolingo.com")],
                appURL: "duolingo://",
                webURL: "https://www.duolingo.com"),
            .writing: SourceInfo(
                name: "Writing",
                role: "Short writing tasks in Rumbo",
                symbol: "pencil.and.scribble",
                what: "Short writing tasks inside Rumbo: guided writing with a prompt, and quick timed writes. Pico checks your writing with AI using your own Gemini or GroqCloud key, which are both free to get (Settings → Writing feedback).",
                whereToFind: "Right here in Rumbo; there's nothing else to install."),
            .exchange: SourceInfo(
                name: "Tandem/HelloTalk partner",
                shortName: "Tandem/HelloTalk",
                role: "I have a language exchange partner",
                symbol: "bubble.left.and.bubble.right.fill",
                what: "Language-exchange apps where you chat with native French speakers who are learning your language: you help each other.",
                whereToFind: "The Tandem and HelloTalk apps.",
                links: [.init("Open tandem.net", "https://www.tandem.net"), .init("Open hellotalk.com", "https://www.hellotalk.com")],
                appURL: "tandem://",
                webURL: "https://www.tandem.net"),
            .suggestedContent: SourceInfo(
                name: "Suggested shows & podcasts",
                role: "Native shows in your plan once Extra is done",
                symbol: "sparkles.tv.fill",
                what: "Real shows, series, podcasts and YouTube channels in French, picked for each level in Rumbo's Library.",
                whereToFind: "The Library tab: each suggestion says where to find it (YouTube, Netflix, Spotify, …).",
                inYourPlan: "With this switched on, your plan includes watching one of these from B1, once Extra French is done (or at any level if you don't use Dreaming French). Switch it off to keep your listening to your courses; the Library is there either way."),
        ],
        // Introduction to French: each track's length in seconds, measured from the files in Language Transfer's
        // own download (downloads.languagetransfer.org/french/french.zip, November 2026).
        course: AudioCourse(trackSeconds: [
            736, 485, 389, 526, 569, 741, 779, 473, 627, 699,
            641, 499, 373, 558, 511, 677, 657, 821, 518, 380,
            637, 730, 473, 400, 741, 474, 391, 599, 547, 458,
            514, 536, 861, 616, 515, 516, 759, 707, 744, 951,
        ]),
        // The same series as Extra en Español, remade in French: 13 episodes, used the same way.
        series: LearnerSeries(episodes: 13, intensiveParts: 2, intensiveBands: .a2_1 ... .a2_2, extensiveBands: .b1_1 ... .b1_2,
                              minimumBudget: 20, searchPrefix: "Extra French episode"),
        // The same platform as Dreaming Spanish: a 0–100 difficulty on each video, and an hours counter.
        graded: GradedVideo(scale: 0...100, windowWidth: 5, easyOffset: 10...15, countsHours: true),
        drill: DrillApp(lastBand: .b1_2, optionalBand: .b2_1, sections: 1...10, units: 1...300),
        anchors: LanguagePack.spanish.anchors,
        tutor: Tutor(
            focus: "that verb tenses match time expressions (for example \"hier\" needs a past tense), the choice between passé composé and imparfait, être or avoir as the auxiliary and past participle agreement, gender and number agreement, articles (du, de la, des, and de after a negative), the pronouns y and en, prepositions, the subjunctive where an expression needs it, elision and contractions (l', au, du)",
            languageToolCode: "fr",
            explainInLanguageFrom: .b2_1),
        // A no-break space before "!" and "?", as French is written.
        phrases: Phrasebook(
            week: "Semaine",
            weekComplete: "Semaine terminée",
            weekCompleteGold: "Semaine terminée\u{00A0}!",
            today: "Aujourd'hui",
            done: "C'est fait\u{00A0}!",
            goodMorning: "Bonjour",
            goodAfternoon: "Bonjour",
            goodEvening: "Bonsoir",
            exclamationEnd: "\u{00A0}!",
            hello: "Salut\u{00A0}!",
            yes: "Oui\u{00A0}!",
            notYet: "Pas encore",
            congratulations: "Félicitations\u{00A0}!",
            letsGo: "C'est parti\u{00A0}!",
            wellDone: "Très bien\u{00A0}!",
            amazing: "Incroyable\u{00A0}!",
            goalReached: "Objectif atteint\u{00A0}!",
            daysInARow: "%d jours d'affilée\u{00A0}!",
            reminderTitle: "On y va\u{00A0}?",
            squawks: ["Allez\u{00A0}!", "Bravo\u{00A0}!", "Salut\u{00A0}!", "Super\u{00A0}!", "Génial\u{00A0}!", "Courage\u{00A0}!"],
            levelNames: [.a1_1: "Débutant", .a1_2: "Apprenti", .a2_1: "Explorateur", .a2_2: "Voyageur", .b1_1: "Flâneur", .b1_2: "Bavard", .b2_1: "À l'aise", .b2_2: "Habitué"]),
        catalog: CatalogSource(
            resource: "content.fr",
            remoteURL: "https://raw.githubusercontent.com/rahns/rumbo/main/Rumbo/Resources/catalog/content.fr.json",
            cacheFile: "content-catalog.fr.json"),
        wording: ["region": "France", "regional": "French", "places": "France, Quebec or Belgium",
                  "filmOrigin": "France or Quebec"]
    )
}
