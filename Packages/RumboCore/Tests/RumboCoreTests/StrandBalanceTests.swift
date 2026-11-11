import Foundation
import Testing
@testable import RumboCore

@Suite struct StrandBalanceTests {
    func total(_ balance: StrandBalance) -> Int { Strand.allCases.reduce(0) { $0 + balance[$1] } }

    @Test(arguments: Band.allCases)
    func theBandsSplitStartsTheCustomOneInStepsOfFive(band: Band) {
        let balance = StrandBalance(band: band)
        #expect(total(balance) == 100)
        #expect(Strand.allCases.allSatisfy { balance[$0] % 5 == 0 })
        #expect(balance[.input] == 55)
    }

    @Test func movingOneStrandScalesTheOthersInProportion() {
        var balance = StrandBalance(shares: [.input: 50, .output: 20, .languageFocused: 20, .fluency: 10])
        balance.set(.input, to: 75)
        // 25 left for 20 : 20 : 10, in steps of 5.
        #expect(balance[.input] == 75)
        #expect(total(balance) == 100)
        #expect(balance[.output] == 10 && balance[.languageFocused] == 10 && balance[.fluency] == 5)
        balance.set(.fluency, to: 23)
        #expect(balance[.fluency] == 25, "rounded to a step of 5")
        #expect(total(balance) == 100)
    }

    @Test func fromAllOnOneStrandTheRestIsSharedEvenly() {
        var balance = StrandBalance(shares: [.input: 1, .output: 0, .languageFocused: 0, .fluency: 0])
        #expect(balance[.input] == 100)
        balance.set(.input, to: 40)
        #expect(balance[.output] == 20 && balance[.languageFocused] == 20 && balance[.fluency] == 20)
        balance.set(.output, to: 100)
        #expect(balance[.output] == 100 && total(balance) == 100)
    }

    @Test func theCustomBalanceDrivesThePlan() {
        let planner = DayPlanner(calendar: TestCalendar.utc)
        let today = TestCalendar.day(2026, 10, 26)
        var learner = LearnerSnapshot(band: .b1_1, speakingStage: .voiceNotes, languageTransferLastTrack: 60, extraEpisodesWatched: 5)
        learner.alwaysIncludeDuolingo = false
        learner.balance = StrandBalance(shares: [.input: 0, .output: 60, .languageFocused: 40, .fluency: 0])
        #expect(learner.strandTargets[.output] == 0.6)
        for budget in DayPlanner.budgetChoices {
            let plan = planner.plan(budget: budget, learner: learner, history: [], today: today)
            #expect(plan.tasks.allSatisfy { $0.kind.strand != .input && $0.kind.strand != .fluency },
                    "a strand at 0% gets no card: \(budget) min, \(plan.tasks.map(\.kind.rawValue))")
        }
        learner.balance = nil
        #expect(learner.strandTargets == Band.b1_1.strandTargets, "no custom balance: the band's split")
    }
}
