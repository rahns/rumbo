import Foundation
import Testing
@testable import RumboCore

@Suite struct MistakesTests {
    let text = "Ayer yo voy a la playa con mis amigo. Nosotros comimos mucho pescados."

    func correction(_ original: String, _ corrected: String, source: String = "model") -> Correction {
        Correction(original: original, corrected: corrected, explanation: "Because.", source: source)
    }

    @Test func mergeDropsNoOpsAndDuplicates() {
        let merged = Mistakes.merge(
            model: [correction("yo voy", "yo fui"), correction("comimos", "comimos")],
            languageTool: [correction("voy", "fui", source: "languagetool"), correction("mis amigo", "mis amigos", source: "languagetool")]
        )
        #expect(merged.map(\.original) == ["yo voy", "mis amigo"], "LanguageTool's 'voy' overlaps the model's 'yo voy'")
        #expect(merged.first?.source == "model")
    }

    @Test func mergeCapsTheNumberOfErrors() {
        let many = (0..<12).map { correction("error\($0)x", "fix\($0)") }
        #expect(Mistakes.merge(model: many, languageTool: []).count == Mistakes.maximumErrors)
    }

    @Test func rangeIgnoresCaseAndAccents() {
        #expect(Mistakes.range(of: "AYER", in: "ayer fui") != nil)
        #expect(Mistakes.range(of: "cafe", in: "Tomé un café") != nil)
        #expect(Mistakes.range(of: "  ", in: "algo") == nil)
    }

    @Test func clozeCardBlanksTheErrorInItsSentence() {
        let card = Mistakes.card(from: text, correction: correction("voy", "fui"))
        #expect(card.front == "Ayer yo \(Mistakes.blank) a la playa con mis amigo.\n(you wrote: voy)")
        #expect(card.back == "fui\nAyer yo fui a la playa con mis amigo.")
    }

    @Test func clozeCardUsesOnlyTheSentenceWithTheError() {
        let card = Mistakes.card(from: text, correction: correction("pescados", "pescado"))
        #expect(card.front.hasPrefix("Nosotros comimos mucho \(Mistakes.blank)."))
    }

    @Test func cardFallsBackWhenTheErrorIsNotInTheText() {
        let card = Mistakes.card(from: text, correction: correction("no está", "no es"))
        #expect(card.front == "Fix it: no está")
        #expect(card.back == "no es")
    }
}
