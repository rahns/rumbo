import Foundation

/// Writing correction with the learner's own free Gemini API key (docs/05-architecture.md §5.3).
/// The request and response handling lives here so it can be tested without a network; the app sends it.
public enum Gemini {
    public static let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!
    /// Where to create a free key.
    public static let keyPage = URL(string: "https://aistudio.google.com/apikey")!
    /// Tried in order. Flash-Lite is plenty for short A2–B1 corrections and is rarely busy; Flash, with its own free
    /// quota and load, picks up when Flash-Lite is used up or busy.
    public static let models = ["gemini-3.5-flash-lite", "gemini-3.8-flash"]

    /// The name shown under feedback, e.g. "Gemini Flash-Lite".
    public static func displayName(for model: String) -> String {
        model.contains("lite") ? "Gemini Flash-Lite" : "Gemini Flash"
    }

    /// How long a model that was busy, too slow or out of free requests is tried last, so checks don't wait on it.
    public static let restAfterFailure: TimeInterval = 30 * 60

    /// The models in the order to try now: ones resting after a recent failure go last (still tried if the rest fail).
    public static func order(resting: [String: Date], now: Date = .now) -> [String] {
        let ready = models.filter { (resting[$0] ?? .distantPast) <= now }
        return ready + models.filter { !ready.contains($0) }
    }

    /// What the model returns: the same shape as the on-device checker's `WritingFeedback`.
    public struct Feedback: Codable, Equatable, Sendable {
        public struct Error: Codable, Equatable, Sendable {
            public var original: String
            public var corrected: String
            public var explanation: String
        }

        public var errors: [Error]
        public var naturalRewrite: String
        public var strengths: [String]

        public var corrections: [Correction] {
            errors.map { Correction(original: $0.original, corrected: $0.corrected, explanation: $0.explanation, source: "gemini") }
        }
    }

    public enum Failure: Swift.Error, Hashable, Sendable {
        /// 429: the free per-minute or daily limit is used up.
        case rateLimited
        /// 401/403, or a 400 that names the key: the key is wrong, expired or not allowed.
        case invalidKey
        /// 404: this model isn't available to the key; try the next one.
        case modelUnavailable
        /// 500/503/504: Google is overloaded ("high demand") or had a hiccup. The key is fine; try the next model.
        case busy
        /// No answer in time, usually because Google is overloaded. Treated like busy.
        case timedOut
        /// Anything else, with the server's message when there is one.
        case other(String)
    }

    /// The JSON body for one check. `store: false` keeps the text off Google's interaction history.
    public static func requestBody(model: String, instructions: String, input: String) -> Data {
        let errorSchema: [String: Any] = [
            "type": "object",
            "properties": [
                "original": ["type": "string", "description": "The exact wrong words, copied from the learner's text."],
                "corrected": ["type": "string", "description": "The corrected words. Must be different from original."],
                "explanation": ["type": "string", "description": "One short sentence explaining the rule."],
            ],
            "required": ["original", "corrected", "explanation"],
        ]
        let schema: [String: Any] = [
            "type": "object",
            "properties": [
                "errors": ["type": "array", "items": errorSchema,
                           "description": "Each real error in the learner's text, most important first. Skip anything already correct."],
                "naturalRewrite": ["type": "string",
                                   "description": "The whole text rewritten the way a native speaker would say it, keeping the learner's meaning."],
                "strengths": ["type": "array", "items": ["type": "string"],
                              "description": "One or two short, specific things the learner did well."],
            ],
            "required": ["errors", "naturalRewrite", "strengths"],
        ]
        let body: [String: Any] = [
            "model": model,
            "input": input,
            "system_instruction": instructions,
            "store": false,
            "response_format": ["type": "text", "mime_type": "application/json", "schema": schema],
            // A little reasoning helps with tense and agreement; "low" is the lowest level both models accept above
            // Flash-Lite's "minimal" and keeps checks quick.
            "generation_config": ["thinking_level": "low"],
        ]
        return (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
    }

    /// The text of the model's answer: every text part of the `model_output` steps.
    public static func outputText(from data: Data) throws -> String {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure.other("Unexpected reply from Gemini.")
        }
        let steps = object["steps"] as? [[String: Any]] ?? []
        let text = steps
            .filter { ($0["type"] as? String) == "model_output" }
            .flatMap { $0["content"] as? [[String: Any]] ?? [] }
            .filter { ($0["type"] as? String ?? "text") == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        // Older or SDK-style shapes, just in case.
        if text.isEmpty, let direct = object["output_text"] as? String { return direct }
        guard !text.isEmpty else { throw Failure.other("Gemini sent an empty reply.") }
        return text
    }

    /// The feedback inside the answer, tolerating a ```json fence around it.
    public static func feedback(from text: String) throws -> Feedback {
        var json = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = json.firstIndex(of: "{"), let end = json.lastIndex(of: "}") {
            json = String(json[start...end])
        }
        do {
            return try JSONDecoder().decode(Feedback.self, from: Data(json.utf8))
        } catch {
            throw Failure.other("Gemini's reply wasn't in the expected format.")
        }
    }

    /// Classifies an HTTP error. Returns nil for success.
    public static func failure(status: Int, body: Data) -> Failure? {
        guard !(200..<300).contains(status) else { return nil }
        let error = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["error"] as? [String: Any]
        let code = (error?["code"] as? String ?? error?["status"] as? String ?? "").lowercased()
        let message = error?["message"] as? String ?? ""
        switch status {
        case 429: return .rateLimited
        case 401, 403: return .invalidKey
        case 404: return .modelUnavailable
        case 500, 502, 503, 504: return .busy
        case 400 where code.contains("key") || message.lowercased().contains("api key"): return .invalidKey
        default: return .other(message.isEmpty ? "Gemini returned error \(status)." : message)
        }
    }
}

extension Gemini.Failure: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .rateLimited: "Free limit reached"
        case .invalidKey: "Key not accepted"
        case .modelUnavailable: "Model not available"
        case .busy: "Gemini is busy"
        case .timedOut: "Gemini didn't answer in time"
        case .other(let message): message
        }
    }
}
