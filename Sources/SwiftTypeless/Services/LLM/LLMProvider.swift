import Foundation

struct ChatMessage {
    enum Role: String {
        case system, user, assistant
    }
    let role: Role
    let content: String
}

protocol LLMProvider {
    func chat(messages: [ChatMessage], signal: Task<Void, Never>?) async throws -> String
    func chatStream(messages: [ChatMessage], onChunk: @escaping (String) -> Void, signal: Task<Void, Never>?) async throws -> String
    func processAudio(audioData: Data, systemPrompt: String, signal: Task<Void, Never>?) async throws -> String
    func processAudioStream(audioData: Data, systemPrompt: String, onChunk: @escaping (String) -> Void, signal: Task<Void, Never>?) async throws -> String
}

// Default implementations for optional methods
extension LLMProvider {
    func chatStream(messages: [ChatMessage], onChunk: @escaping (String) -> Void, signal: Task<Void, Never>?) async throws -> String {
        let result = try await chat(messages: messages, signal: signal)
        onChunk(result)
        return result
    }

    func processAudio(audioData: Data, systemPrompt: String, signal: Task<Void, Never>?) async throws -> String {
        throw LLMError.audioNotSupported
    }

    func processAudioStream(audioData: Data, systemPrompt: String, onChunk: @escaping (String) -> Void, signal: Task<Void, Never>?) async throws -> String {
        let result = try await processAudio(audioData: audioData, systemPrompt: systemPrompt, signal: signal)
        onChunk(result)
        return result
    }
}

enum LLMError: LocalizedError {
    case invalidApiKey
    case rateLimited
    case timeout
    case networkError(String)
    case serverError(Int, String)
    case audioNotSupported
    case cancelled

    var errorDescription: String? {
        switch self {
        case .invalidApiKey: return "Invalid API Key. Please check your settings."
        case .rateLimited: return "Rate limit exceeded. Please wait a moment."
        case .timeout: return "Request timed out. Please try again."
        case .networkError(let msg): return "Network error: \(msg)"
        case .serverError(let code, let msg): return "Server error (\(code)): \(msg)"
        case .audioNotSupported: return "This provider does not support audio processing."
        case .cancelled: return "Cancelled"
        }
    }
}
