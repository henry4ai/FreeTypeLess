import Foundation

enum QAService {
    static func ask(
        question: String,
        context: String? = nil,
        using provider: LLMProvider,
        prompt: String,
        onChunk: @escaping (String) -> Void
    ) async throws -> String {
        var systemPrompt = prompt
        if let context, !context.isEmpty {
            systemPrompt += "\n\nReference context:\n\(context)"
        }

        let messages = [
            ChatMessage(role: .system, content: systemPrompt),
            ChatMessage(role: .user, content: question)
        ]

        return try await provider.chatStream(messages: messages, onChunk: onChunk, signal: nil)
    }
}
