import Foundation
import Testing
@testable import RumboCore

@Suite struct ContentCatalogTests {
    func item(_ id: String, _ from: Band, _ to: Band, _ country: String) -> ContentItem {
        ContentItem(id: id, title: id, kind: .series, from: from, to: to, country: country, whereToFind: "", url: nil, why: "")
    }

    var catalog: ContentCatalog {
        ContentCatalog(version: 1, items: [
            item("easy-mx", .a2_1, .a2_2, "Mexico"),
            item("easy-es", .a2_1, .a2_2, "Spain"),
            item("b1-co", .b1_1, .b1_2, "Colombia"),
            item("b2-ar", .b2_1, .b2_2, "Argentina"),
        ])
    }

    @Test func suggestsWhatSuitsTheBandAndWhatComesNext() {
        let suggestions = catalog.suggestions(for: .a2_2)
        #expect(Set(suggestions.now.map(\.id)) == ["easy-mx", "easy-es"])
        #expect(suggestions.next.map(\.id) == ["b1-co"])
    }

    @Test func easiestComesFirst() {
        let items = ContentCatalog(version: 1, items: [item("harder", .b1_1, .b1_2, "Mexico"), item("easier", .a2_2, .b1_2, "Spain")])
        #expect(items.suggestions(for: .b1_1).now.map(\.id) == ["easier", "harder"])
    }

    @Test func theLastBandHasNoNext() {
        #expect(catalog.suggestions(for: .b2_2).next.isEmpty)
    }

    @Test func theBundledCatalogDecodesAndCoversEveryBand() throws {
        // Tests run from the package directory; the bundled catalog lives in the app's resources.
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Rumbo/Resources/catalog/content.json")
        let catalog = try ContentCatalog.decode(Data(contentsOf: url))
        #expect(Set(catalog.items.map(\.id)).count == catalog.items.count, "ids are unique")
        for band in Band.allCases {
            #expect(!catalog.suggestions(for: band).now.isEmpty, "\(band.rawValue) has suggestions")
        }
        for item in catalog.items {
            #expect(item.from <= item.to)
            #expect(!item.why.isEmpty && !item.whereToFind.isEmpty)
        }
    }
}

@Suite struct ProgressStatsTests {
    let calendar = TestCalendar.utc
    let today = TestCalendar.day(2026, 10, 28)

    @Test func strandMinutesCoverTheLastSevenDays() {
        let history = [
            ActivityRecord(date: today, kind: .dsWatch, minutes: 20),
            ActivityRecord(date: TestCalendar.adding(days: -6, to: today), kind: .ltTrack, minutes: 10),
            ActivityRecord(date: TestCalendar.adding(days: -7, to: today), kind: .writeGuided, minutes: 99),
        ]
        let minutes = ProgressStats.strandMinutes(history: history, today: today, calendar: calendar)
        #expect(minutes[.input] == 20 && minutes[.languageFocused] == 10 && minutes[.output] == 0)
    }

    @Test func heatMapWeeksAreWholeCalendarWeeks() {
        let history = [ActivityRecord(date: today, kind: .dsWatch, minutes: 15)]
        let weeks = ProgressStats.weeks(12, history: history, today: today, calendar: calendar)
        #expect(weeks.count == 12)
        #expect(weeks.allSatisfy { $0.count == 7 })
        #expect(calendar.component(.weekday, from: weeks[0][0].date) == calendar.firstWeekday)
        #expect(weeks.last?.contains { $0.minutes == 15 } == true)
    }

    @Test func projectionGrowsAtThePace() {
        let end = TestCalendar.adding(days: 28, to: today)
        let points = ProgressStats.projection(currentHours: 100, weeklyHours: 7, from: today, until: end, calendar: calendar)
        #expect(points.count == 3)
        #expect(abs(points.last!.hours - 128) < 0.001)
    }
}

@Suite struct WatchedLevelTests {
    let calendar = TestCalendar.utc
    let today = TestCalendar.day(2026, 10, 28)

    func session(_ daysAgo: Int, _ level: Double, _ minutes: Int) -> WatchedLevel.Session {
        WatchedLevel.Session(date: TestCalendar.adding(days: -daysAgo, to: today), level: level, minutes: minutes)
    }

    @Test func dailyPointsAreMinuteWeighted() {
        // 20 min at 40 and 10 min at 46 on the same day: (800 + 460) / 30 = 42.
        let points = WatchedLevel.series([session(0, 40, 20), session(0, 46, 10), session(3, 38, 15)],
                                         period: .twoWeeks, today: today, calendar: calendar)
        #expect(points.count == 2)
        #expect(abs(points.last!.level - 42) < 0.001)
        #expect(points.last!.minutes == 30)
        #expect(points.first!.level == 38)
    }

    @Test func longerPeriodsUseWeeksAndDropOlderSessions() {
        let sessions = (0..<120).map { session($0, 30 + Double(120 - $0) / 10, 20) }
        let month = WatchedLevel.series(sessions, period: .month, today: today, calendar: calendar)
        #expect(month.count == 30)
        let threeMonths = WatchedLevel.series(sessions, period: .threeMonths, today: today, calendar: calendar)
        #expect(threeMonths.count == 13)
        #expect(threeMonths.first!.level < threeMonths.last!.level, "rising level shows as rising")
        #expect(WatchedLevel.series(sessions, period: .twoWeeks, today: today, calendar: calendar).count == 14)
    }

    @Test func allTimeStartsAtTheFirstSession() {
        let recent = [session(3, 40, 20), session(0, 42, 20)]
        let short = WatchedLevel.window(recent, period: .allTime, today: today, calendar: calendar)
        #expect(short.days == 14 && short.bucketDays == 1, "at least two weeks, daily")
        #expect(WatchedLevel.series(recent, period: .allTime, today: today, calendar: calendar).count == 2)

        let long = [session(800, 30, 20), session(400, 36, 20), session(0, 45, 20)]
        let window = WatchedLevel.window(long, period: .allTime, today: today, calendar: calendar)
        #expect(window.days == 801 && window.bucketDays == 30, "over a year: monthly points")
        let points = WatchedLevel.series(long, period: .allTime, today: today, calendar: calendar)
        #expect(points.map(\.level) == [30, 36, 45], "nothing is cut off")
    }

    @Test func emptyDaysAreLeftOut() {
        #expect(WatchedLevel.series([], period: .year, today: today, calendar: calendar).isEmpty)
        #expect(WatchedLevel.series([session(0, 40, 0)], period: .month, today: today, calendar: calendar).isEmpty)
    }
}
