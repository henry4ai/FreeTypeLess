import Foundation

enum PolishService {
    static func polish(text: String, using provider: LLMProvider, prompt: String) async throws -> String {
        let messages = [
            ChatMessage(role: .system, content: prompt),
            ChatMessage(role: .user, content: text)
        ]
        return try await provider.chat(messages: messages, signal: nil)
    }
}
