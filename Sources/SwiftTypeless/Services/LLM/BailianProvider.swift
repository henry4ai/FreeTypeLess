import Foundation

final class BailianProvider: LLMProvider {
    private let settings = SettingsStore.shared
    private let timeoutInterval: TimeInterval = 30

    func chat(messages: [ChatMessage], signal: Task<Void, Never>? = nil) async throws -> String {
        let result = try await chatStream(messages: messages, onChunk: { _ in }, signal: signal)
        return result
    }

    func chatStream(messages: [ChatMessage], onChunk: @escaping (String) -> Void, signal: Task<Void, Never>? = nil) async throws -> String {
        let apiKey = settings.bailianApiKey
        guard !apiKey.isEmpty else { throw LLMError.invalidApiKey }

        let url = URL(string: "\(settings.bailianBaseUrl)/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval

        let model = settings.bailianModel
        let systemPrompt = messages.first { $0.role == .system }?.content ?? ""
        print("[Bailian] model=\(model), system_prompt=\(systemPrompt.prefix(80))...")

        let body: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role.rawValue, "content": $0.content] },
            "stream": true,
            "enable_thinking": false
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        return try await streamSSE(request: request, onChunk: onChunk)
    }

    func processAudio(audioData: Data, systemPrompt: String, signal: Task<Void, Never>?) async throws -> String {
        throw LLMError.audioNotSupported
    }

    // MARK: - SSE Streaming

    private func streamSSE(request: URLRequest, onChunk: @escaping (String) -> Void) async throws -> String {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.networkError("Invalid response")
        }

        try checkHTTPStatus(httpResponse)

        var fullText = ""

        for try await line in bytes.lines {
            try Task.checkCancellation()

            guard line.hasPrefix("data: ") else { continue }
            let jsonStr = String(line.dropFirst(6))

            if jsonStr == "[DONE]" { break }

            guard let data = jsonStr.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String
            else { continue }

            fullText += content
            onChunk(content)
        }

        return fullText
    }

    private func checkHTTPStatus(_ response: HTTPURLResponse) throws {
        switch response.statusCode {
        case 200...299: return
        case 401, 403: throw LLMError.invalidApiKey
        case 429: throw LLMError.rateLimited
        default: throw LLMError.serverError(response.statusCode, HTTPURLResponse.localizedString(forStatusCode: response.statusCode))
        }
    }
}
