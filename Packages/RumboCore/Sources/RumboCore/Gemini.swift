import Foundation

/// Writing correction with the learner's own free Gemini API key (docs/05-architecture.md §5.3).
/// The request and response handling lives here so it can be tested without a network; the app sends it.
public enum Gemini {
    public static let endpoint = URL(string: "https://generativelanguage.googleapis.com/v1beta/interactions")!
    /// Where to create a free key.
    public static let keyPage = URL(string: "https://aistudio.google.com/apikey")!
    /// Flash-Lite at medium thinking: plenty for short A2–B1 corrections. In testing it answered in about 3 s,
    /// streamed or not, while Flash (`gemini-3.8-flash`) never started, so Flash isn't used.
    public static let model = "gemini-3.5-flash-lite"
    /// Shown under feedback: "Checked by Gemini Flash-Lite".
    public static let displayName = "Gemini Flash-Lite"

    /// How much the model reasons before answering. More catches subtler errors but takes longer.
    public enum ThinkingLevel: String, CaseIterable, Sendable {
        case low, medium, high

        public static let standard = ThinkingLevel.medium
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
    /// Streamed requests also ask for thought summaries, so events keep arriving while the model thinks.
    public static func requestBody(model: String, instructions: String, input: String, stream: Bool = false,
                                   thinking: ThinkingLevel = .standard) -> Data {
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
        var generation: [String: Any] = ["thinking_level": thinking.rawValue]
        if stream { generation["thinking_summaries"] = "auto" }
        var body: [String: Any] = [
            "model": model,
            "input": input,
            "system_instruction": instructions,
            "store": false,
            "response_format": ["type": "text", "mime_type": "application/json", "schema": schema],
            // Medium by default: catches more tense, agreement and naturalness errors; the learner can change it.
            "generation_config": generation,
        ]
        if stream { body["stream"] = true }
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
        if let failure = failure(code: code, message: message), status != 400 || failure == .invalidKey { return failure }
        switch status {
        case 429: return .rateLimited
        case 401, 403: return .invalidKey
        case 404: return .modelUnavailable
        case 500, 502, 503, 504: return .busy
        case 400 where code.contains("key") || message.lowercased().contains("api key"): return .invalidKey
        default: return .other(message.isEmpty ? "Gemini returned error \(status)." : message)
        }
    }

    /// Classifies an error by its code, e.g. "quota_exceeded" or "UNAVAILABLE" (also used for errors inside a stream).
    public static func failure(code: String, message: String) -> Failure? {
        let code = code.lowercased()
        switch code {
        case "rate_limit_exceeded", "quota_exceeded", "too_many_requests", "resource_exhausted": return .rateLimited
        case "authentication", "permission_denied", "unauthenticated": return .invalidKey
        case "model_not_found": return .modelUnavailable
        case "unavailable", "internal", "gateway_timeout", "deadline_exceeded", "overloaded", "service_unavailable": return .busy
        default:
            if code.contains("key") || message.lowercased().contains("api key") { return .invalidKey }
            return nil
        }
    }

    // MARK: - Streaming

    /// When to give up on a streamed answer. A model that has started keeps sending events while it thinks,
    /// so silence means stuck: no first event, or a long gap after it.
    public struct StreamLimits: Equatable, Sendable {
        public var firstEvent: TimeInterval = 10
        public var silence: TimeInterval = 25
        public var total: TimeInterval = 90

        public init() {}

        public enum Stall: Equatable, Sendable {
            case neverStarted, wentQuiet, tooLong
        }

        /// Why the stream should be abandoned, or nil while it's fine.
        public func stall(started: Date, firstEvent first: Date?, lastEvent: Date?, now: Date) -> Stall? {
            if now.timeIntervalSince(started) > total { return .tooLong }
            guard first != nil, let lastEvent else { return now.timeIntervalSince(started) > firstEvent ? .neverStarted : nil }
            return now.timeIntervalSince(lastEvent) > silence ? .wentQuiet : nil
        }
    }

    /// Reads a streamed reply (server-sent events), one line at a time.
    public struct StreamReader: Sendable {
        public enum Event: Equatable, Sendable {
            /// Any sign of life: the interaction started, a thought, a status update.
            case activity
            /// A piece of the answer.
            case text(String)
            case completed
            case failed(Failure)
        }

        /// Step types by index, so only `model_output` text counts as the answer.
        private var stepTypes: [Int: String] = [:]

        public init() {}

        public mutating func read(line: String) -> Event? {
            guard line.hasPrefix("data:") else { return line.isEmpty ? nil : .activity }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if payload == "[DONE]" { return .completed }
            guard let object = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else { return .activity }
            let index = object["index"] as? Int ?? -1
            switch object["event_type"] as? String {
            case "step.start":
                stepTypes[index] = (object["step"] as? [String: Any])?["type"] as? String
                return .activity
            case "step.delta":
                let delta = object["delta"] as? [String: Any] ?? [:]
                let isOutput = (stepTypes[index] ?? "model_output") == "model_output"
                if isOutput, (delta["type"] as? String) == "text", let text = delta["text"] as? String { return .text(text) }
                return .activity
            case "interaction.completed":
                let status = (object["interaction"] as? [String: Any])?["status"] as? String
                return status == "failed" ? .failed(.other("Gemini couldn't finish this check.")) : .completed
            case "error":
                let error = object["error"] as? [String: Any] ?? [:]
                let code = error["code"] as? String ?? ""
                let message = error["message"] as? String ?? ""
                return .failed(Gemini.failure(code: code, message: message) ?? .other(message.isEmpty ? "Gemini stopped with an error." : message))
            default:
                return .activity
            }
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
