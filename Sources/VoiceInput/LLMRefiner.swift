import Foundation

final class LLMRefiner {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func refine(text: String, baseURL: String, apiKey: String, model: String) async -> String {
        guard let url = chatCompletionsURL(from: baseURL) else {
            return text
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let body = ChatRequest(
            model: model,
            temperature: 0,
            messages: [
                ChatMessage(role: "system", content: Self.systemPrompt),
                ChatMessage(role: "user", content: text)
            ]
        )

        do {
            request.httpBody = try JSONEncoder().encode(body)
            let (data, response) = try await session.data(for: request)
            guard
                let http = response as? HTTPURLResponse,
                (200..<300).contains(http.statusCode)
            else { return text }

            let decoded = try JSONDecoder().decode(ChatResponse.self, from: data)
            let refined = decoded.choices.first?.message.content.trimmingCharacters(in: .whitespacesAndNewlines)
            return refined?.isEmpty == false ? refined! : text
        } catch {
            return text
        }
    }

    private func chatCompletionsURL(from baseURL: String) -> URL? {
        let trimmed = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else { return nil }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !path.hasSuffix("chat/completions") {
            components.path = "/" + ([path, "chat/completions"].filter { !$0.isEmpty }.joined(separator: "/"))
        }
        return components.url
    }

    private static let systemPrompt = """
You correct raw speech-recognition text with extreme conservatism.

Return only the corrected text, with no explanation, no quotes, and no Markdown.

Rules:
- Only fix obvious speech recognition mistakes.
- Preserve the user's wording, order, punctuation style, line breaks, and meaning.
- Never rewrite, polish, summarize, expand, or remove content that appears correct.
- If the input already looks correct, return it exactly as-is.
- For Chinese, you may fix clear homophone/substitution errors only when the intended word is obvious from context.
- For mixed Chinese-English technical speech, fix obvious technical terms incorrectly converted into Chinese sounds, for example 配森 -> Python, 杰森 -> JSON, 加瓦斯科瑞普特 -> JavaScript, 瑞艾克特 -> React, 斯威夫特 -> Swift.
- Do not translate between languages.
- Do not add facts, formatting, greetings, or commentary.
"""

    private struct ChatRequest: Encodable {
        let model: String
        let temperature: Double
        let messages: [ChatMessage]
    }

    private struct ChatMessage: Codable {
        let role: String
        let content: String
    }

    private struct ChatResponse: Decodable {
        let choices: [Choice]
    }

    private struct Choice: Decodable {
        let message: ChatMessage
    }
}
