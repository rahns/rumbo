import Testing
@testable import RumboCore

@Suite struct BandTests {
    @Test func strandTargetsSumToOne() {
        for band in Band.allCases {
            let total = band.strandTargets.values.reduce(0, +)
            #expect(abs(total - 1) < 0.0001, "\(band.rawValue) sums to \(total)")
        }
    }

    @Test func everyBandCoversEveryStrand() {
        for band in Band.allCases {
            #expect(Set(band.strandTargets.keys) == Set(Strand.allCases))
        }
    }

    @Test(arguments: [
        (0.0, Band.a2_1),
        (154, .a2_1),
        (225, .a2_2),
        (299.9, .a2_2),
        (300, .b1_1),
        (450, .b1_2),
        (600, .b2_1),
        (1200, .b2_2),
    ])
    func placementByHours(hours: Double, expected: Band) {
        #expect(Band.forInputHours(hours) == expected)
    }

    @Test func outputGrowsAndLanguageFocusShrinks() {
        let bands = Band.allCases
        for (lower, higher) in zip(bands, bands.dropFirst()) {
            #expect(higher.strandTargets[.output]! >= lower.strandTargets[.output]!)
            #expect(higher.strandTargets[.languageFocused]! <= lower.strandTargets[.languageFocused]!)
        }
    }
}
