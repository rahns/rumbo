import Foundation

/// The free backup writing checker: Groq, with the learner's own free key (docs/05-architecture.md §5.3).
/// Tried when Gemini can't answer. Like `Gemini`, the request and reply handling live here so they can be
/// tested without a network; the app sends them.
public enum Groq {
    /// OpenAI-compatible chat completions.
    public static let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    /// Where to create a free key.
    public static let keyPage = URL(string: "https://console.groq.com/keys")!
    /// The models list, to pick a model automatically in case Groq adds, retires or renames them.
    public static let modelsEndpoint = URL(string: "https://api.groq.com/openai/v1/models")!
    /// Used until the list has been read: a production model with strict structured outputs and reasoning effort,
    /// about 1,000 free requests a day.
    public static let defaultModel = "openai/gpt-oss-120b"

    /// Shown under feedback: "Checked by Groq (gpt-oss-120b)".
    public static func displayName(for model: String) -> String {
        "GroqCloud (\(model.split(separator: "/").last.map(String.init) ?? model))"
    }

    /// The chat model ids in a `GET /models` reply (inactive ones left out).
    public static func modelIDs(from data: Data) -> [String] {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = object["data"] as? [[String: Any]] else { return [] }
        return models.filter { ($0["active"] as? Bool) ?? true }.compactMap { $0["id"] as? String }
    }

    /// The best model on the list for checking writing: GPT-OSS 120B, then other GPT-OSS, Qwen and large Llama
    /// models, then any other general chat model. Speech, safety-guard and other special models are skipped.
    public static func chooseModel(from ids: [String]) -> String? {
        let skip = ["whisper", "orpheus", "tts", "guard", "playai", "distil", "embed", "vision", "compound"]
        let candidates = ids.filter { id in !skip.contains { id.lowercased().contains($0) } }
        let ranks: [(String) -> Bool] = [
            { $0 == defaultModel },
            { $0.contains("gpt-oss-120b") },
            { $0.contains("gpt-oss") },
            { $0.contains("qwen") },
            { $0.contains("llama") && $0.contains("70b") },
            { $0.contains("kimi") || $0.contains("deepseek") || $0.contains("llama-4") },
            { $0.contains("llama") && !$0.contains("8b") },
            { _ in true },
        ]
        for rank in ranks {
            if let match = candidates.filter({ rank($0.lowercased()) }).sorted().first { return match }
        }
        return nil
    }

    /// Whether a model takes strict JSON schemas and `reasoning_effort` (GPT-OSS and Qwen, per Groq's docs).
    /// Others get JSON mode, with the shape described in the instructions, and no reasoning setting.
    public static func supportsStrictSchema(_ model: String) -> Bool {
        let id = model.lowercased()
        return id.contains("gpt-oss") || id.contains("qwen")
    }

    /// The JSON body for one check. Not streamed: Groq's structured outputs don't support streaming, and it's
    /// quick enough without. Reasoning effort follows the thinking setting; the reasoning itself isn't returned.
    public static func requestBody(model: String = defaultModel, instructions: String, input: String,
                                   thinking: Gemini.ThinkingLevel = .standard) -> Data {
        let strict = supportsStrictSchema(model)
        let system = strict ? instructions : instructions + " Reply with only a JSON object with these keys: \"errors\" (an array of objects "
            + "with \"original\", \"corrected\" and \"explanation\"), \"naturalRewrite\" (a string) and \"strengths\" (an array of strings)."
        var body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": input],
            ],
            // Room for the reasoning as well as the answer (the default of 1,024 can cut it off).
            "max_completion_tokens": 8192,
        ]
        if strict {
            body["response_format"] = [
                "type": "json_schema",
                "json_schema": ["name": "writing_feedback", "strict": true, "schema": Gemini.feedbackSchema(closed: true)],
            ]
            body["reasoning_effort"] = thinking.rawValue
            if model.lowercased().contains("gpt-oss") { body["include_reasoning"] = false }
            else { body["reasoning_format"] = "hidden" }
        } else {
            body["response_format"] = ["type": "json_object"]
        }
        return (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
    }

    /// The answer's text: the first choice's message content.
    public static func outputText(from data: Data) throws -> String {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choice = (object["choices"] as? [[String: Any]])?.first else {
            throw Gemini.Failure.other("Unexpected reply from GroqCloud.")
        }
        if (choice["finish_reason"] as? String) == "length" { throw Gemini.Failure.other("GroqCloud's answer was cut off.") }
        guard let text = (choice["message"] as? [String: Any])?["content"] as? String, !text.isEmpty else {
            throw Gemini.Failure.other("GroqCloud sent an empty reply.")
        }
        return text
    }

    /// Classifies an HTTP error. Returns nil for success.
    public static func failure(status: Int, body: Data) -> Gemini.Failure? {
        guard !(200..<300).contains(status) else { return nil }
        let error = (try? JSONSerialization.jsonObject(with: body) as? [String: Any])?["error"] as? [String: Any]
        let message = error?["message"] as? String ?? ""
        switch status {
        case 401, 403: return .invalidKey
        case 404: return .modelUnavailable
        // A retired or renamed model can also come back as a 400 that names the model.
        case 400 where message.lowercased().contains("model")
            && ["decommission", "not exist", "not found", "no longer"].contains(where: message.lowercased().contains):
            return .modelUnavailable
        case 429: return .rateLimited
        // 498: Groq's own "capacity exceeded".
        case 498, 500, 502, 503, 504: return .busy
        default: return .other(message.isEmpty ? "GroqCloud returned error \(status)." : message)
        }
    }
}
