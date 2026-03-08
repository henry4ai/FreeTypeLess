import Foundation

enum TranslationService {
    static func translate(
        text: String,
        targetLanguage: String,
        using provider: LLMProvider,
        promptTemplate: String
    ) async throws -> String {
        let prompt = promptTemplate.replacingOccurrences(of: "{language}", with: targetLanguage)
        let messages = [
            ChatMessage(role: .system, content: prompt),
            ChatMessage(role: .user, content: text)
        ]
        return try await provider.chat(messages: messages, signal: nil)
    }
}
