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

    @Test func destinationAccentComesFirst() {
        #expect(catalog.suggestions(for: .a2_1, destination: "Spain").now.first?.id == "easy-es")
        #expect(catalog.suggestions(for: .a2_1, destination: "Mexico").now.first?.id == "easy-mx")
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
