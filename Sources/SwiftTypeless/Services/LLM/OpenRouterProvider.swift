import Foundation

final class OpenRouterProvider: LLMProvider {
    private let settings = SettingsStore.shared
    private let baseURL = "https://openrouter.ai/api/v1/chat/completions"
    private let timeoutInterval: TimeInterval = 60

    func chat(messages: [ChatMessage], signal: Task<Void, Never>? = nil) async throws -> String {
        try await chatStream(messages: messages, onChunk: { _ in }, signal: signal)
    }

    func chatStream(messages: [ChatMessage], onChunk: @escaping (String) -> Void, signal: Task<Void, Never>? = nil) async throws -> String {
        let request = try buildRequest(
            messages: messages.map { msg in
                ["role": msg.role.rawValue, "content": msg.content] as [String: Any]
            },
            stream: true
        )
        return try await streamSSE(request: request, onChunk: onChunk)
    }

    func processAudio(audioData: Data, systemPrompt: String, signal: Task<Void, Never>? = nil) async throws -> String {
        try await processAudioStream(audioData: audioData, systemPrompt: systemPrompt, onChunk: { _ in }, signal: signal)
    }

    func processAudioStream(audioData: Data, systemPrompt: String, onChunk: @escaping (String) -> Void, signal: Task<Void, Never>? = nil) async throws -> String {
        let base64Audio = audioData.base64EncodedString()

        let messages: [[String: Any]] = [
            ["role": "system", "content": systemPrompt],
            [
                "role": "user",
                "content": [
                    [
                        "type": "input_audio",
                        "input_audio": [
                            "data": base64Audio,
                            "format": "wav"
                        ]
                    ]
                ]
            ]
        ]

        let request = try buildRequest(messages: messages, stream: true)
        return try await streamSSE(request: request, onChunk: onChunk)
    }

    // MARK: - Private

    private func buildRequest(messages: [[String: Any]], stream: Bool) throws -> URLRequest {
        let apiKey = settings.openRouterApiKey
        guard !apiKey.isEmpty else { throw LLMError.invalidApiKey }

        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = timeoutInterval

        let model = settings.openRouterModel
        print("[OpenRouter] model=\(model), stream=\(stream)")

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "stream": stream
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

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

// MARK: - Model Fetching

extension OpenRouterProvider {
    struct ModelInfo: Identifiable {
        let id: String
        let name: String
    }

    static func fetchModels(apiKey: String) async throws -> [ModelInfo] {
        guard apiKey.count >= 10 else { return [] }

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/models")!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30

        let (data, _) = try await URLSession.shared.data(for: request)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let models = json["data"] as? [[String: Any]]
        else {
            print("[OpenRouter] Failed to parse models response")
            return []
        }

        print("[OpenRouter] Total models returned: \(models.count)")

        let filtered = models.compactMap { model -> ModelInfo? in
            guard let id = model["id"] as? String,
                  let name = model["name"] as? String
            else { return nil }

            // Match original filter: architecture.input_modalities includes "audio"
            //                        AND architecture.output_modalities includes "text"
            if let arch = model["architecture"] as? [String: Any],
               let inputMods = arch["input_modalities"] as? [String],
               let outputMods = arch["output_modalities"] as? [String],
               inputMods.contains("audio"),
               outputMods.contains("text") {
                return ModelInfo(id: id, name: name)
            }
            return nil
        }
        print("[OpenRouter] Audio-capable models found: \(filtered.count)")
        return filtered
    }
}
