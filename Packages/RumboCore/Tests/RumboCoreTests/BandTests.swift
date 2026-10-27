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
        (280, .a2_1),
        (410, .a2_2),
        (549.9, .a2_2),
        (550, .b1_1),
        (820, .b1_2),
        (1090, .b2_1),
        (2000, .b2_2),
    ])
    func placementByHours(hours: Double, expected: Band) {
        #expect(Band.forHours(hours) == expected)
    }

    @Test func outputGrowsAndLanguageFocusShrinks() {
        let bands = Band.allCases
        for (lower, higher) in zip(bands, bands.dropFirst()) {
            #expect(higher.strandTargets[.output]! >= lower.strandTargets[.output]!)
            #expect(higher.strandTargets[.languageFocused]! <= lower.strandTargets[.languageFocused]!)
        }
    }
}
