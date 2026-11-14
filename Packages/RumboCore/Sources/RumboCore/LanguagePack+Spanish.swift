import Foundation

extension LanguagePack {
    /// Spanish: the first language, and the one every rule was tuned on.
    public static let spanish = LanguagePack(
        code: "es",
        name: "Spanish",
        nativeName: "Español",
        flag: "🇪🇸",
        localeIdentifier: "es",
        // The listening-hour milestones (0 / 50 / 150 / 225 / 300 / 450 / 600 / 800, Dreaming Spanish's roadmap) divided
        // by the plan's listening share, rounded to 10 (docs/02-learning-engine.md §2.1).
        levels: LevelScale([.a1_1: 0, .a1_2: 90, .a2_1: 270, .a2_2: 410, .b1_1: 550, .b1_2: 820, .b2_1: 1090, .b2_2: 1450]),
        sources: [
            .gradedVideo: SourceInfo(
                name: "Dreaming Spanish",
                shortName: "Dreaming",
                role: "Your main listening engine",
                symbol: "play.tv.fill",
                what: "A video library of Spanish made to be understood: thousands of videos where native speakers explain, chat and tell stories, using pictures and gestures at the easy levels. Every video has a difficulty from 0 to 100, and it counts your hours of listening. It's built on comprehensible input: you pick up Spanish by understanding lots of it.",
                whereToFind: "The Dreaming Spanish app and dreaming.com.",
                links: [.init("Open dreaming.com", "https://www.dreaming.com/spanish")],
                appURL: "dreaming://",
                webURL: "https://www.dreaming.com/spanish"),
            .audioCourse: SourceInfo(
                name: "Language Transfer",
                role: "Grammar skeleton, from zero to early B1",
                symbol: "headphones",
                what: "\"Complete Spanish\": a free audio course of 90 short tracks. A teacher guides a student to build sentences by thinking, not memorising, and you answer out loud before the student does. It starts from zero and gives you the skeleton of Spanish grammar up to early B1.",
                whereToFind: "The free Language Transfer app or languagetransfer.org.",
                links: [.init("Open languagetransfer.org", "https://www.languagetransfer.org")],
                appURL: "languagetransfer://",
                webURL: "https://www.languagetransfer.org"),
            .learnerSeries: SourceInfo(
                name: "Extra en Español",
                shortName: "Extra",
                role: "Sitcom with subtitles and shadowing",
                symbol: "film.fill",
                what: "A sitcom made for Spanish learners: 13 episodes about flatmates in Spain and an American friend who arrives knowing little Spanish. The speech is clear and slow at first, and it's funny.",
                whereToFind: "Free on YouTube: search \"Extra en Español\".",
                links: [.init("Search on YouTube", "https://www.youtube.com/results?search_query=Extra%20en%20Espa%C3%B1ol")]),
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
                what: "Language-exchange apps where you chat with native Spanish speakers who are learning your language: you help each other.",
                whereToFind: "The Tandem and HelloTalk apps.",
                links: [.init("Open tandem.net", "https://www.tandem.net"), .init("Open hellotalk.com", "https://www.hellotalk.com")],
                appURL: "tandem://",
                webURL: "https://www.tandem.net"),
            .suggestedContent: SourceInfo(
                name: "Suggested shows & podcasts",
                role: "Native shows in your plan once Extra is done",
                symbol: "sparkles.tv.fill",
                what: "Real shows, series, podcasts and YouTube channels made for native speakers, picked for each level in Rumbo's Library.",
                whereToFind: "The Library tab: each suggestion says where to find it (YouTube, Netflix, Spotify, …).",
                inYourPlan: "With this switched on, your plan includes watching one of these from B1, once Extra en Español is done (or at any level if you don't use Dreaming Spanish). Switch it off to keep your listening to your courses; the Library is there either way."),
        ],
        // Complete Spanish: each track's length in seconds (Language Transfer's SoundCloud uploads, as
        // archived at archive.org/details/55_20260801; spot-checked against SoundCloud).
        course: AudioCourse(trackSeconds: [
            334, 479, 375, 509, 565, 425, 615, 453, 548, 748,
            652, 834, 578, 910, 540, 458, 803, 411, 422, 562,
            733, 791, 419, 345, 727, 524, 645, 682, 527, 451,
            420, 580, 524, 547, 342, 663, 800, 565, 635, 760,
            787, 424, 545, 607, 772, 650, 575, 660, 650, 563,
            740, 870, 499, 583, 939, 824, 690, 549, 643, 506,
            479, 713, 298, 804, 906, 298, 703, 490, 570, 658,
            760, 781, 484, 548, 560, 491, 415, 564, 430, 430,
            716, 404, 491, 472, 292, 539, 618, 578, 498, 413,
        ]),
        series: LearnerSeries(episodes: 13, intensiveParts: 2, intensiveBands: .a2_1 ... .a2_2, extensiveBands: .b1_1 ... .b1_2,
                              minimumBudget: 20, searchPrefix: "Extra en Español episodio"),
        graded: GradedVideo(scale: 0...100, windowWidth: 5, easyOffset: 10...15, countsHours: true),
        // A daily warm-up from A2.1 to B1.2, optional at B2.1 and dropped at B2.2 (R15).
        drill: DrillApp(lastBand: .b1_2, optionalBand: .b2_1, sections: 1...10, units: 1...300),
        anchors: [
            // Beginners: no weekly anchors at A1.1 (writing and a partner come when there's something to say);
            // a short write and one message a week at A1.2.
            .a1_1: AnchorTargets(writing: 0, seriesIntensiveParts: 0, seriesEpisodes: 0, exchanges: 0, fluency432: 0),
            .a1_2: AnchorTargets(writing: 1, seriesIntensiveParts: 0, seriesEpisodes: 0, exchanges: 1, fluency432: 0),
            // Dreaming Spanish is the main input; Extra is a once-a-week change of pace.
            .a2_1: AnchorTargets(writing: 1, seriesIntensiveParts: 1, seriesEpisodes: 0, exchanges: 2, fluency432: 0),
            .a2_2: AnchorTargets(writing: 1, seriesIntensiveParts: 1, seriesEpisodes: 0, exchanges: 2, fluency432: 0),
            .b1_1: AnchorTargets(writing: 2, seriesIntensiveParts: 0, seriesEpisodes: 1, exchanges: 3, fluency432: 1),
            .b1_2: AnchorTargets(writing: 2, seriesIntensiveParts: 0, seriesEpisodes: 1, exchanges: 3, fluency432: 1),
            .b2_1: AnchorTargets(writing: 2, seriesIntensiveParts: 0, seriesEpisodes: 0, exchanges: 3, fluency432: 1),
            .b2_2: AnchorTargets(writing: 3, seriesIntensiveParts: 0, seriesEpisodes: 0, exchanges: 3, fluency432: 1),
        ],
        tutor: Tutor(
            focus: "that verb tenses match time expressions (for example \"ayer\" needs the preterite), gender and number agreement, ser/estar, por/para, prepositions",
            languageToolCode: "es",
            explainInLanguageFrom: .b2_1),
        phrases: Phrasebook(
            week: "Semana",
            weekComplete: "Semana completa",
            weekCompleteGold: "¡Semana completa!",
            today: "Hoy",
            done: "¡Hecho!",
            goodMorning: "¡Buenos días",
            goodAfternoon: "¡Buenas tardes",
            goodEvening: "¡Buenas noches",
            exclamationEnd: "!",
            hello: "¡Hola!",
            yes: "¡Sí!",
            notYet: "Todavía no",
            congratulations: "¡Felicidades!",
            letsGo: "¡Vamos!",
            wellDone: "¡Muy bien!",
            amazing: "¡Increíble!",
            goalReached: "¡Meta cumplida!",
            daysInARow: "¡%d días seguidos!",
            reminderTitle: "¿Rumbo a dónde?",
            squawks: ["¡Vamos!", "¡Olé!", "¡Hola!", "¡Dale!", "¡Qué bien!", "¡Ánimo!"],
            levelNames: [.a1_1: "Novato", .a1_2: "Aprendiz", .a2_1: "Explorador", .a2_2: "Viajero", .b1_1: "Andante", .b1_2: "Conversador", .b2_1: "Fluido", .b2_2: "Local"]),
        catalog: CatalogSource(
            resource: "content",
            remoteURL: "https://raw.githubusercontent.com/rahns/rumbo/main/Rumbo/Resources/catalog/content.json",
            cacheFile: "content-catalog.json"),
        wording: ["region": "Latin America", "regional": "Latin American", "places": "Mexico, Colombia or Argentina",
                  "filmOrigin": "Latin America or Spain"]
    )
}
