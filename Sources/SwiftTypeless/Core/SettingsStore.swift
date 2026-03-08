import Foundation
import Combine

enum Provider: String, CaseIterable {
    case bailian = "bailian"
    case openRouter = "openrouter"

    var displayName: String {
        switch self {
        case .bailian: return "Aliyun Bailian"
        case .openRouter: return "OpenRouter"
        }
    }
}

@Observable
final class SettingsStore {
    static let shared = SettingsStore()

    // MARK: - Provider

    var provider: Provider {
        get { Provider(rawValue: UserDefaults.standard.string(forKey: "provider") ?? "bailian") ?? .bailian }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: "provider") }
    }

    // MARK: - Bailian

    var bailianApiKey: String {
        get { UserDefaults.standard.string(forKey: "bailianApiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "bailianApiKey") }
    }

    var bailianBaseUrl: String {
        get { UserDefaults.standard.string(forKey: "bailianBaseUrl") ?? "https://dashscope.aliyuncs.com/compatible-mode/v1" }
        set { UserDefaults.standard.set(newValue, forKey: "bailianBaseUrl") }
    }

    var bailianModel: String {
        get { UserDefaults.standard.string(forKey: "bailianModel") ?? "qwen3.5-plus" }
        set { UserDefaults.standard.set(newValue, forKey: "bailianModel") }
    }

    var bailianPromptAsr: String {
        get {
            UserDefaults.standard.string(forKey: "bailianPromptAsr")
                ?? "你是一个文字整理助手。用户会提供一段语音识别（ASR）的原始文本，可能包含口语化表达、语气词或轻微的识别错误。请将其整理为通顺、准确的书面文字，保留原意，不要添加额外内容。只输出整理后的文本，不要解释。"
        }
        set { UserDefaults.standard.set(newValue, forKey: "bailianPromptAsr") }
    }

    var bailianPromptTranslation: String {
        get {
            UserDefaults.standard.string(forKey: "bailianPromptTranslation")
                ?? "你是一位专业翻译。请将用户发来的文字翻译为{language}。保持原意，语句通顺自然。只输出译文，不要解释。"
        }
        set { UserDefaults.standard.set(newValue, forKey: "bailianPromptTranslation") }
    }

    var bailianPromptQa: String {
        get {
            UserDefaults.standard.string(forKey: "bailianPromptQa")
                ?? "You are a helpful assistant. Answer the user's question concisely and accurately."
        }
        set { UserDefaults.standard.set(newValue, forKey: "bailianPromptQa") }
    }

    // MARK: - OpenRouter

    var openRouterApiKey: String {
        get { UserDefaults.standard.string(forKey: "openRouterApiKey") ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: "openRouterApiKey") }
    }

    var openRouterModel: String {
        get { UserDefaults.standard.string(forKey: "openRouterModel") ?? "google/gemini-2.5-flash" }
        set { UserDefaults.standard.set(newValue, forKey: "openRouterModel") }
    }

    var orPromptAsr: String {
        get {
            UserDefaults.standard.string(forKey: "orPromptAsr")
                ?? "Listen to the audio and transcribe it accurately. Output only the transcribed text, nothing else."
        }
        set { UserDefaults.standard.set(newValue, forKey: "orPromptAsr") }
    }

    var orPromptTranslation: String {
        get {
            UserDefaults.standard.string(forKey: "orPromptTranslation")
                ?? "Listen to the audio and translate the speech into {language}. Output only the translation, nothing else."
        }
        set { UserDefaults.standard.set(newValue, forKey: "orPromptTranslation") }
    }

    var orPromptQa: String {
        get {
            UserDefaults.standard.string(forKey: "orPromptQa")
                ?? "You are a helpful assistant. Listen to the user's audio question and provide a concise, accurate answer."
        }
        set { UserDefaults.standard.set(newValue, forKey: "orPromptQa") }
    }

    // MARK: - General

    var targetLanguage: String {
        get { UserDefaults.standard.string(forKey: "targetLanguage") ?? "English" }
        set { UserDefaults.standard.set(newValue, forKey: "targetLanguage") }
    }

    var autoStart: Bool {
        get { UserDefaults.standard.bool(forKey: "autoStart") }
        set { UserDefaults.standard.set(newValue, forKey: "autoStart") }
    }

    // MARK: - Computed

    var isConfigured: Bool {
        switch provider {
        case .bailian: return !bailianApiKey.isEmpty
        case .openRouter: return !openRouterApiKey.isEmpty
        }
    }

    var modelDescription: String {
        switch provider {
        case .bailian:
            if bailianApiKey.isEmpty { return "No model configured" }
            return "Bailian · ASR: qwen3-asr-flash-realtime · LLM: \(bailianModel)"
        case .openRouter:
            if openRouterApiKey.isEmpty { return "No model configured" }
            return "OpenRouter · \(openRouterModel)"
        }
    }

    private init() {
        loadEnvIfNeeded()
    }

    // MARK: - .env Loading

    /// Load API keys from .env file on first launch (if UserDefaults are empty)
    private func loadEnvIfNeeded() {
        guard UserDefaults.standard.string(forKey: "envLoaded") == nil else { return }

        // Look for .env in the app bundle directory or working directory
        let candidates = [
            Bundle.main.bundlePath + "/../.env",
            FileManager.default.currentDirectoryPath + "/.env"
        ]

        for path in candidates {
            let resolved = (path as NSString).standardizingPath
            if let contents = try? String(contentsOfFile: resolved, encoding: .utf8) {
                parseEnv(contents)
                UserDefaults.standard.set("1", forKey: "envLoaded")
                print("[SettingsStore] Loaded API keys from \(resolved)")
                return
            }
        }
    }

    private func parseEnv(_ contents: String) {
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else { continue }

            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            guard !value.isEmpty else { continue }

            switch key {
            case "ALIYUN_API_KEY":
                if bailianApiKey.isEmpty { bailianApiKey = value }
            case "OPENROUTER_API_KEY":
                if openRouterApiKey.isEmpty { openRouterApiKey = value }
            default:
                break
            }
        }
    }
}
