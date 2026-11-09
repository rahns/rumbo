import Foundation

/// The AI models that can check writing (Settings → Writing feedback), each with the learner's own key for
/// its provider. See docs/05-architecture.md §5.3.
public enum WritingModel: String, CaseIterable, Sendable {
    /// Free with a Google key. The default: plenty for short A2–B1 corrections, and it answered in about 3 s
    /// in testing.
    case geminiFlashLite = "gemini-3.5-flash-lite"
    /// Free with a Google key, but was busy almost every time in testing.
    case geminiFlash = "gemini-3.8-flash"
    /// Paid, with an Anthropic key. Cheapest and quickest Claude.
    case claudeHaiku = "claude-haiku-5-5"
    case claudeSonnet = "claude-sonnet-5-5"
    /// Paid. Anthropic's current Opus: the most thorough of these.
    case claudeOpus = "claude-opus-5-5"

    public enum Provider: String, CaseIterable, Sendable {
        case gemini, claude

        public var name: String { self == .gemini ? "Gemini" : "Claude" }
    }

    public static let standard = WritingModel.geminiFlashLite

    public var provider: Provider {
        switch self {
        case .geminiFlashLite, .geminiFlash: .gemini
        case .claudeHaiku, .claudeSonnet, .claudeOpus: .claude
        }
    }

    /// Shown under feedback: "Checked by Claude Haiku 5.5".
    public var displayName: String {
        switch self {
        case .geminiFlashLite: "Gemini Flash-Lite"
        case .geminiFlash: "Gemini Flash"
        case .claudeHaiku: "Claude Haiku 5.5"
        case .claudeSonnet: "Claude Sonnet 5.5"
        case .claudeOpus: "Claude Opus 5.5"
        }
    }
}

/// Writing correction with the learner's own Anthropic API key, through the Messages API. Like `Gemini`, the
/// request and reply handling live here so they can be tested without a network; the app sends them.
public enum Claude {
    public static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    public static let apiVersion = "2026-10-21"
    /// Where to create a key (it needs credit added to the account).
    public static let keyPage = URL(string: "https://platform.claude.com/settings/keys")!
    /// Server-side refusal fallback, on by default for Opus and Sonnet: if a safety classifier declines, the
    /// API retries on a fallback model inside the same call.
    public static let fallbackBeta = "server-side-fallback-2026-07-01"

    public static func usesFallbacks(_ model: String) -> Bool {
        model == WritingModel.claudeOpus.rawValue || model == WritingModel.claudeSonnet.rawValue
    }

    /// The JSON body for one check: the instructions as the system prompt, adaptive thinking at the chosen effort,
    /// and the feedback schema as structured output. Streamed requests ask for thinking summaries, so events keep
    /// arriving while the model thinks.
    public static func requestBody(model: String, instructions: String, input: String, stream: Bool = false,
                                   thinking: Gemini.ThinkingLevel = .standard) -> Data {
        var thinkingConfig: [String: Any] = ["type": "adaptive"]
        if stream { thinkingConfig["display"] = "summarized" }
        var body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "system": instructions,
            "messages": [["role": "user", "content": input]],
            "thinking": thinkingConfig,
            "output_config": [
                "effort": thinking.rawValue,
                "format": ["type": "json_schema", "schema": Gemini.feedbackSchema(closed: true)],
            ],
        ]
        if stream { body["stream"] = true }
        if usesFallbacks(model) { body["fallbacks"] = "default" }
        return (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
    }

    static let declined = Gemini.Failure.other("Claude declined to check this text.")

    /// The text blocks of a whole (not streamed) reply.
    public static func outputText(from data: Data) throws -> String {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Gemini.Failure.other("Unexpected reply from Claude.")
        }
        if (object["stop_reason"] as? String) == "refusal" { throw declined }
        let text = (object["content"] as? [[String: Any]] ?? [])
            .filter { ($0["type"] as? String) == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
        guard !text.isEmpty else { throw Gemini.Failure.other("Claude sent an empty reply.") }
        return text
    }

    /// Classifies an HTTP error. Returns nil for success.
    public static func failure(status: Int, body: Data) -> Gemini.Failure? {
        guard !(200..<300).contains(status) else { return nil }
        let error = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["error"] as? [String: Any]
        let type = error?["type"] as? String ?? ""
        let message = error?["message"] as? String ?? ""
        if let failure = failure(type: type) { return failure }
        switch status {
        case 401, 403: return .invalidKey
        case 404: return .modelUnavailable
        case 429: return .rateLimited
        case 500, 502, 503, 504, 529: return .busy
        default: return .other(message.isEmpty ? "Claude returned error \(status)." : message)
        }
    }

    /// Classifies an API error type, e.g. "overloaded_error" (also used for errors inside a stream).
    public static func failure(type: String) -> Gemini.Failure? {
        switch type {
        case "rate_limit_error": .rateLimited
        case "authentication_error", "permission_error": .invalidKey
        case "not_found_error": .modelUnavailable
        case "overloaded_error", "api_error", "timeout_error": .busy
        default: nil
        }
    }

    /// Reads a streamed reply (server-sent events), one line at a time, into the same events as Gemini's reader.
    public struct StreamReader: Sendable {
        /// Content block types by index, so only `text` blocks count as the answer (not thinking).
        private var blockTypes: [Int: String] = [:]

        public init() {}

        public mutating func read(line: String) -> Gemini.StreamReader.Event? {
            guard line.hasPrefix("data:") else { return line.isEmpty ? nil : .activity }
            let payload = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            guard let object = try? JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [String: Any] else { return .activity }
            let index = object["index"] as? Int ?? -1
            switch object["type"] as? String {
            case "content_block_start":
                blockTypes[index] = (object["content_block"] as? [String: Any])?["type"] as? String
                return .activity
            case "content_block_delta":
                let delta = object["delta"] as? [String: Any] ?? [:]
                if blockTypes[index] == "text", (delta["type"] as? String) == "text_delta", let text = delta["text"] as? String {
                    return .text(text)
                }
                return .activity
            case "message_delta":
                let stop = (object["delta"] as? [String: Any])?["stop_reason"] as? String
                return stop == "refusal" ? .failed(Claude.declined) : .activity
            case "message_stop":
                return .completed
            case "error":
                let error = object["error"] as? [String: Any] ?? [:]
                let message = error["message"] as? String ?? ""
                return .failed(Claude.failure(type: error["type"] as? String ?? "")
                               ?? .other(message.isEmpty ? "Claude stopped with an error." : message))
            default:
                // message_start, content_block_stop, ping (a keep-alive) and anything new: signs of life.
                return .activity
            }
        }
    }
}
