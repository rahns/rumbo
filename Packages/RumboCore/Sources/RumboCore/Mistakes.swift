import Foundation

/// One correction to a learner's text, whichever checker found it.
public struct Correction: Equatable, Codable, Sendable {
    public var original: String
    public var corrected: String
    public var explanation: String
    /// "gemini", "model" (on-device) or "languagetool".
    public var source: String

    public init(original: String, corrected: String, explanation: String, source: String) {
        self.original = original
        self.corrected = corrected
        self.explanation = explanation
        self.source = source
    }

    /// A "correction" that changes nothing (the on-device model sometimes produces these).
    public var isNoOp: Bool {
        Mistakes.normalized(original) == Mistakes.normalized(corrected)
    }
}

/// Front and back of a mistake-deck card. See docs/03-experience.md §3.4 "Mistake deck".
public struct MistakeCardContent: Equatable, Sendable {
    public var front: String
    public var back: String
    public var explanation: String
}

public enum Mistakes {
    public static let blank = "＿＿＿"
    /// The model is asked for at most this many errors, most important first.
    public static let maximumErrors = 8

    /// Combines the model's corrections with LanguageTool's: drops no-ops and duplicates, keeps the
    /// model's wording where both found the same error, and adds what only LanguageTool caught.
    public static func merge(model: [Correction], languageTool: [Correction]) -> [Correction] {
        var result: [Correction] = []
        for correction in model + languageTool where !correction.isNoOp {
            let original = normalized(correction.original)
            let overlaps = result.contains { existing in
                let other = normalized(existing.original)
                return other == original || other.contains(original) || original.contains(other)
            }
            if !overlaps {
                result.append(correction)
            }
        }
        return Array(result.prefix(maximumErrors))
    }

    /// Where `fragment` appears in `text`, ignoring case and accents.
    public static func range(of fragment: String, in text: String) -> Range<String.Index>? {
        let trimmed = fragment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return text.range(of: trimmed, options: [.caseInsensitive, .diacriticInsensitive])
    }

    /// The sentence of `text` containing `range`.
    public static func sentence(around range: Range<String.Index>, in text: String) -> Range<String.Index> {
        let enders: Set<Character> = [".", "!", "?", "\n"]
        var start = range.lowerBound
        while start > text.startIndex {
            let previous = text.index(before: start)
            if enders.contains(text[previous]) { break }
            start = previous
        }
        var end = range.upperBound
        while end < text.endIndex {
            let character = text[end]
            end = text.index(after: end)
            if enders.contains(character) { break }
        }
        return start..<end
    }

    /// A cloze card: the learner's sentence with the error blanked (and shown as a hint) on the front,
    /// the correct words and the corrected sentence on the back.
    public static func card(from text: String, correction: Correction) -> MistakeCardContent {
        let fixed = correction.corrected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let errorRange = range(of: correction.original, in: text) else {
            return MistakeCardContent(
                front: "Fix it: \(correction.original.trimmingCharacters(in: .whitespacesAndNewlines))",
                back: fixed,
                explanation: correction.explanation
            )
        }
        let sentenceRange = sentence(around: errorRange, in: text)
        let before = String(text[sentenceRange.lowerBound..<errorRange.lowerBound])
        let after = String(text[errorRange.upperBound..<sentenceRange.upperBound])
        let wrote = String(text[errorRange])
        let front = (before + blank + after).trimmingCharacters(in: .whitespacesAndNewlines) + "\n(you wrote: \(wrote))"
        let corrected = (before + fixed + after).trimmingCharacters(in: .whitespacesAndNewlines)
        return MistakeCardContent(front: front, back: "\(fixed)\n\(corrected)", explanation: correction.explanation)
    }

    static func normalized(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines.union(.punctuationCharacters))
    }
}
