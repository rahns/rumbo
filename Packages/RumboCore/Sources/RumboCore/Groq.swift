import Foundation

/// The free backup writing checker: Groq, with the learner's own free key (docs/05-architecture.md §5.3).
/// Tried when Gemini can't answer. Like `Gemini`, the request and reply handling live here so they can be
/// tested without a network; the app sends them.
public enum Groq {
    /// OpenAI-compatible chat completions.
    public static let endpoint = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
    /// Where to create a free key.
    public static let keyPage = URL(string: "https://console.groq.com/keys")!
    /// A production model with strict structured outputs and reasoning effort, about 1,000 free requests a day.
    public static let model = "openai/gpt-oss-120b"
    /// Shown under feedback: "Checked by Groq (GPT-OSS 120B)".
    public static let displayName = "Groq (GPT-OSS 120B)"

    /// The JSON body for one check. Not streamed: Groq's structured outputs don't support streaming, and it's
    /// quick enough without. Reasoning effort follows the thinking setting; the reasoning itself isn't returned.
    public static func requestBody(instructions: String, input: String, thinking: Gemini.ThinkingLevel = .standard) -> Data {
        let body: [String: Any] = [
            "model": model,
            "messages": [
                ["role": "system", "content": instructions],
                ["role": "user", "content": input],
            ],
            "response_format": [
                "type": "json_schema",
                "json_schema": ["name": "writing_feedback", "strict": true, "schema": Gemini.feedbackSchema(closed: true)],
            ],
            "reasoning_effort": thinking.rawValue,
            "include_reasoning": false,
            // Room for the reasoning as well as the answer (the default of 1,024 can cut it off).
            "max_completion_tokens": 8192,
        ]
        return (try? JSONSerialization.data(withJSONObject: body, options: [.sortedKeys])) ?? Data()
    }

    /// The answer's text: the first choice's message content.
    public static func outputText(from data: Data) throws -> String {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choice = (object["choices"] as? [[String: Any]])?.first else {
            throw Gemini.Failure.other("Unexpected reply from Groq.")
        }
        if (choice["finish_reason"] as? String) == "length" { throw Gemini.Failure.other("Groq's answer was cut off.") }
        guard let text = (choice["message"] as? [String: Any])?["content"] as? String, !text.isEmpty else {
            throw Gemini.Failure.other("Groq sent an empty reply.")
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
        case 429: return .rateLimited
        // 498: Groq's own "capacity exceeded".
        case 498, 500, 502, 503, 504: return .busy
        default: return .other(message.isEmpty ? "Groq returned error \(status)." : message)
        }
    }
}
