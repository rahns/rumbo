import Foundation
import FoundationModels
import RumboCore

/// Writing correction (docs/05-architecture.md §5.3). With the learner's free Gemini key, Gemini checks the
/// writing. Without one, or when Gemini can't answer (free limit used up, bad key, offline), the basic checker
/// runs instead: LanguageTool finds errors when online and the on-device Apple model explains them; the result
/// then carries a `notice` saying why. Apple's cloud model isn't used: it crashes sideloaded builds.
enum CorrectionService {
    struct Result: Codable, Equatable {
        var corrections: [Correction]
        var naturalRewrite: String
        var strengths: [String]
        /// Which checker ran, e.g. "Gemini" or "LanguageTool + on-device model".
        var engine: String
        /// Shown above the feedback when Gemini was set up but the basic checker had to stand in.
        var notice: String? = nil
    }

    enum Failure: LocalizedError {
        case nothingAvailable(notice: String?)

        var errorDescription: String? {
            let base = "Can't check right now: you're offline and the on-device model isn't available. Your writing is still saved."
            if case .nothingAvailable(let notice?) = self { return "\(notice) \(base)" }
            return base
        }
    }

    static var modelAvailable: Bool {
        if case .available = SystemLanguageModel.default.availability { return true }
        return false
    }

    static func correct(_ text: String, band: Band, prompt: String) async throws -> Result {
        var notice: String?
        if let key = GeminiKey.current {
            do {
                return try await GeminiClient.correct(text, band: band, prompt: prompt, key: key)
            } catch {
                notice = GeminiClient.notice(for: error)
            }
        }
        var result = try await basicCheck(text, band: band, prompt: prompt, notice: notice)
        result.notice = notice
        return result
    }

    /// The older checker: LanguageTool plus the on-device model, merged.
    private static func basicCheck(_ text: String, band: Band, prompt: String, notice: String?) async throws -> Result {
        let matches = try? await LanguageTool.check(text)
        let toolCorrections = (matches ?? []).compactMap { $0.correction(in: text) }

        guard modelAvailable else {
            guard let matches else { throw Failure.nothingAvailable(notice: notice) }
            return Result(corrections: Mistakes.merge(model: [], languageTool: toolCorrections), naturalRewrite: "", strengths: [],
                          engine: matches.isEmpty ? "LanguageTool (found nothing)" : "LanguageTool")
        }

        let session = LanguageModelSession(instructions: instructions(for: band))
        var request = "Writing task: \(prompt)\n\nLearner's text:\n\(text)"
        if let matches, !matches.isEmpty {
            request += "\n\nA grammar checker flagged:\n" + matches.map { "- «\($0.flaggedText(in: text))»: \($0.message)" }.joined(separator: "\n")
        }
        let feedback = try await session.respond(to: request, generating: WritingFeedback.self).content
        let modelCorrections = feedback.errors.map {
            Correction(original: $0.original, corrected: $0.corrected, explanation: $0.explanation, source: "model")
        }
        return Result(
            corrections: Mistakes.merge(model: modelCorrections, languageTool: toolCorrections),
            naturalRewrite: feedback.naturalRewrite,
            strengths: Array(feedback.strengths.prefix(2)),
            engine: matches == nil ? "On-device model (offline)" : "LanguageTool + on-device model"
        )
    }

    /// Explanations in English up to B1, in simple Spanish from B2.
    static func instructions(for band: Band) -> String {
        let language = band >= .b2_1 ? "in simple Spanish" : "in English"
        return """
            You are a warm, encouraging Spanish tutor for a \(band.rawValue) learner (CEFR). Find the real errors in the learner's text, \
            most important first, at most \(Mistakes.maximumErrors). Check that verb tenses match time expressions (for example "ayer" \
            needs the preterite), gender and number agreement, ser/estar, por/para, prepositions, and phrasing a native speaker \
            wouldn't use. Use the grammar checker's hints when given. Never list something that is already correct. Copy the wrong words exactly as the learner wrote them. \
            Explain each error in one short sentence \(language), at the learner's level. Also give one or two specific things they did well.
            """
    }
}

@Generable
struct WritingFeedback {
    @Guide(description: "Each real error in the learner's text, most important first. Skip anything already correct.")
    var errors: [WritingError]
    @Guide(description: "The whole text rewritten the way a native speaker would say it, keeping the learner's meaning.")
    var naturalRewrite: String
    @Guide(description: "One or two short, specific things the learner did well.")
    var strengths: [String]
}

@Generable
struct WritingError {
    @Guide(description: "The exact wrong words, copied from the learner's text.")
    var original: String
    @Guide(description: "The corrected words. Must be different from original.")
    var corrected: String
    @Guide(description: "One short sentence explaining the rule.")
    var explanation: String
}

/// The public LanguageTool API: free, no key, about 20 requests a minute.
enum LanguageTool {
    struct Match: Decodable {
        struct Replacement: Decodable { let value: String }

        let message: String
        let offset: Int
        let length: Int
        let replacements: [Replacement]

        /// LanguageTool offsets count UTF-16 code units.
        func flaggedText(in text: String) -> String {
            let utf16 = Array(text.utf16)
            guard offset >= 0, length > 0, offset + length <= utf16.count else { return "" }
            return String(decoding: utf16[offset..<offset + length], as: UTF16.self)
        }

        func correction(in text: String) -> Correction? {
            let flagged = flaggedText(in: text)
            guard !flagged.isEmpty, let fix = replacements.first?.value else { return nil }
            return Correction(original: flagged, corrected: fix, explanation: message, source: "languagetool")
        }
    }

    private struct Response: Decodable {
        let matches: [Match]
    }

    static func check(_ text: String) async throws -> [Match] {
        var request = URLRequest(url: URL(string: "https://api.languagetool.org/v2/check")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 15
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [
            URLQueryItem(name: "language", value: "es"),
            URLQueryItem(name: "text", value: text),
        ]
        request.httpBody = form.percentEncodedQuery?.data(using: .utf8)
        let (data, response) = try await URLSession.shared.data(for: request)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        return try JSONDecoder().decode(Response.self, from: data).matches
    }
}
