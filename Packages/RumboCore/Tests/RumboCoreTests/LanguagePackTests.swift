import Foundation
import Testing
@testable import RumboCore

@Suite struct LanguagePackTests {
    /// What's written to stores and backups. These date from when Spanish was the only language and must
    /// never change, whatever the cases are called in code.
    @Test func storedIdentifiersNeverChange() {
        #expect(SourceKind.allCases.map(\.rawValue) == [
            "dreamingSpanish", "languageTransfer", "extraEnEspanol", "duolingo", "writing", "tandem", "suggestedContent",
        ])
        #expect(TaskKind.allCases.map(\.rawValue) == [
            "duo.lesson", "lt.track", "ds.watch", "ds.easy", "extra.intensive", "extra.extensive", "content.watch",
            "write.guided", "write.quick", "tandem.text", "tandem.voice", "tandem.call", "fluency.432", "review.mistakes",
            "mission.travel", "other.study", "other.output", "other.fluency",
            "lesson.output", "lesson.input", "lesson.study", "lesson.mixed",
        ])
        let progress = SourceProgress(courseLastTrack: 3, courseRepeatPending: true, seriesEpisodesWatched: 2, seriesPartsDone: 1)
        let json = String(decoding: try! JSONEncoder().encode(progress), as: UTF8.self)
        for key in ["languageTransferLastTrack", "languageTransferRepeatPending", "extraEpisodesWatched", "extraPartsDoneInEpisode"] {
            #expect(json.contains("\"\(key)\""), "\(key) is how saved tasks remember progress for undo")
        }
        #expect(LanguagePack.defaultCode == "es")
    }

    @Test(arguments: LanguagePack.all)
    func everyPackIsComplete(pack: LanguagePack) {
        // Levels: all six, rising.
        let hours = Band.allCases.map(pack.levels.threshold)
        #expect(hours.allSatisfy { $0 > 0 } && hours == hours.sorted() && Set(hours).count == 6, "\(pack.code) levels")
        // Writing, an exchange partner and suggested content exist for every language.
        for role in [SourceKind.writing, .exchange, .suggestedContent] { #expect(pack.has(role), "\(pack.code) \(role)") }
        // A role's numbers and its wording come together.
        #expect(pack.has(.audioCourse) == (pack.course != nil))
        #expect(pack.has(.learnerSeries) == (pack.series != nil))
        #expect(pack.has(.gradedVideo) == (pack.graded != nil))
        #expect(pack.has(.drillApp) == (pack.drill != nil))
        for (role, info) in pack.sources {
            #expect(![info.name, info.role, info.symbol, info.what, info.whereToFind].contains(""), "\(pack.code) \(role)")
            for link in info.links + [info.appURL, info.webURL].compactMap { $0 }.map({ SourceInfo.Link("", $0) }) {
                #expect(URL(string: link.url)?.scheme != nil, "\(pack.code) \(role): \(link.url)")
            }
        }
        #expect(Band.allCases.allSatisfy { pack.anchors[$0] != nil }, "\(pack.code) anchors")
        #expect(pack.phrases.allStrings.allSatisfy { !$0.isEmpty }, "\(pack.code) phrasebook")
        #expect(pack.phrases.daysInARow.contains("%d"))
        #expect(!pack.phrases.squawks.isEmpty)
        #expect(URL(string: pack.catalog.remoteURL)?.scheme == "https")
        #expect(Locale.availableIdentifiers.contains(pack.localeIdentifier))
        #expect(LanguagePack.pack(for: pack.code).code == pack.code)
    }

    @Test func codesAreUniqueAndUnknownOnesFallBackToSpanish() {
        #expect(Set(LanguagePack.all.map(\.code)).count == LanguagePack.all.count)
        #expect(LanguagePack.pack(for: nil).code == "es")
        #expect(LanguagePack.pack(for: "xx").code == "es")
    }

    /// Shared wording says "{language}", never a language's name, and comes out with the pack's.
    @Test func sharedWordingNamesNoLanguage() {
        let shared = Band.allCases.flatMap(CanDo.shared) + Prompts.writingPrompts.values.flatMap { $0 }
            + Prompts.exchangePrompts.values.flatMap { $0 } + Prompts.quickWriteTopics + Prompts.fluencyStories + Prompts.travelMissions
        for name in ["Spanish", "French", "German", "Italian"] {
            #expect(shared.filter { $0.contains(name) }.isEmpty, "\(name) appears in shared wording")
        }
        #expect(shared.contains { $0.contains("{language}") })
        let day = TestCalendar.day(2026, 10, 26)
        for offset in 0..<120 {
            let date = TestCalendar.adding(days: offset, to: day)
            let prompts = [
                Prompts.writing(for: .b1_1, on: date, pack: .spanish, calendar: TestCalendar.utc),
                Prompts.exchange(for: .a2_1, on: date, pack: .spanish, calendar: TestCalendar.utc),
                Prompts.quickWrite(on: date, pack: .spanish, calendar: TestCalendar.utc),
                Prompts.travelMission(on: date, pack: .spanish, calendar: TestCalendar.utc),
            ]
            #expect(prompts.allSatisfy { !$0.contains("{") })
        }
        #expect(CanDo.statements(for: .b1_1, pack: .spanish).contains("I can deal with most situations while travelling where Spanish is spoken."))
    }

    @Test func theTutorIsToldTheLanguageAndItsTraps() {
        let tutor = LanguagePack.spanish.tutor
        let early = tutor.instructions(language: "Spanish", band: .a2_2, maximumErrors: 8)
        #expect(early.contains("Spanish tutor for a A2.2 learner") && early.contains("ser/estar") && early.contains("in English"))
        #expect(tutor.instructions(language: "Spanish", band: .b2_1, maximumErrors: 8).contains("in simple Spanish"))
    }

    @Test func phrasesGreetByTheHour() {
        let phrases = LanguagePack.spanish.phrases
        #expect(phrases.greeting(hour: 9, name: "") == "¡Buenos días!")
        #expect(phrases.greeting(hour: 15, name: "Ana") == "¡Buenas tardes, Ana!")
        #expect(phrases.greeting(hour: 22, name: "Ana") == "¡Buenas noches, Ana!")
        #expect(phrases.streak(days: 30) == "¡30 días seguidos!")
        #expect(LanguagePack.spanish.levelName(.b1_2) == "Conversador")
    }

    /// A language with only the roles every language has (writing, a partner, suggested content): no graded
    /// video, audio course, learner series or drill app. The planner still fills the day.
    static let bare = LanguagePack(
        code: "xx", name: "Testish", nativeName: "Testish", localeIdentifier: "en",
        levels: LevelScale([.a2_1: 300, .a2_2: 500, .b1_1: 700, .b1_2: 1000, .b2_1: 1400, .b2_2: 1900]),
        sources: LanguagePack.spanish.sources.filter { [.writing, .exchange, .suggestedContent].contains($0.key) },
        course: nil, series: nil, graded: nil, drill: nil,
        anchors: LanguagePack.spanish.anchors, tutor: Tutor(focus: "agreement", languageToolCode: nil, explainInLanguageFrom: nil),
        phrases: LanguagePack.spanish.phrases, catalog: LanguagePack.spanish.catalog)

    @Test(arguments: Band.allCases)
    func aLanguageWithFewSourcesStillGetsAFullPlan(band: Band) {
        let planner = DayPlanner(calendar: TestCalendar.utc)
        let learner = LearnerSnapshot(band: band, speakingStage: .calls, pack: Self.bare)
        #expect(!learner.canPlan(.languageFocused) && learner.canPlan(.input))
        for budget in DayPlanner.budgetChoices {
            let plan = planner.plan(budget: budget, learner: learner, history: [], today: TestCalendar.day(2026, 10, 26))
            #expect(plan.totalMinutes <= budget)
            #expect(plan.totalMinutes >= budget - 4, "\(band.rawValue) \(budget) min planned only \(plan.totalMinutes)")
            let missing: Set<SourceKind> = [.gradedVideo, .audioCourse, .learnerSeries, .drillApp]
            #expect(plan.tasks.allSatisfy { task in task.kind.source.map { !missing.contains($0) } ?? true })
            #expect(plan.tasks.allSatisfy { $0.detail == .none })
        }
        #expect(Self.bare.levels.band(forHours: 750) == .b1_1)
        #expect(Self.bare.tutor.instructions(language: "Testish", band: .b2_2, maximumErrors: 8).contains("in English"))
    }

    @Test func eachLanguageHasItsOwnLevelHours() {
        // 600 training hours is B1.1 in Spanish but still A2.2 on a slower scale.
        #expect(LanguagePack.spanish.levels.band(forHours: 600) == .b1_1)
        #expect(Self.bare.levels.band(forHours: 600) == .a2_2)
        let projection = Projection(calendar: TestCalendar.utc)
        let today = TestCalendar.day(2026, 10, 26)
        let spanish = projection.arrivalDates(hours: 600, weeklyHours: 5, from: today, levels: LanguagePack.spanish.levels)
        let slower = projection.arrivalDates(hours: 600, weeklyHours: 5, from: today, levels: Self.bare.levels)
        #expect(spanish[.b1_1] == nil && slower[.b1_1] != nil)
        #expect(spanish[.b1_2]! < slower[.b1_2]!)
    }
}
