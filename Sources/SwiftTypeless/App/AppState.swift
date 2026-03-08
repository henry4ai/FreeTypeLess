import Foundation
import SwiftUI

enum AppStatus: Equatable {
    case ready
    case recording(RecordingMode)
    case processing
    case result(String)
    case error(String)
}

@Observable
final class AppState {
    static let shared = AppState()

    var status: AppStatus = .ready
    var interimText: String = ""
    var audioLevel: Float = 0

    // QA state
    var qaQuestion: String = ""
    var qaContext: String = ""
    var qaAnswer: String = ""
    var qaIsDone: Bool = false
    var qaHasError: Bool = false
    var qaErrorMessage: String = ""
    var showQAWindow: Bool = false

    // Overlay
    var showOverlay: Bool = false
    var processingProgress: Double = 0

    private let keyListener = KeyListener()
    private let audioRecorder = AudioRecorder()
    private let aliyunSTT = AliyunSTTProvider()
    private let soundPlayer = SoundPlayer.shared
    private var processingTask: Task<Void, Never>?
    private var pendingSelectedText: String = ""

    private init() {
        setupKeyListener()
        setupAudioCallbacks()
    }

    func startListening() {
        keyListener.start()
    }

    func stopListening() {
        keyListener.stop()
    }

    // MARK: - Key Listener Setup

    private func setupKeyListener() {
        keyListener.onRecordingStart = { [weak self] mode in
            self?.handleRecordingStart(mode: mode)
        }

        keyListener.onRecordingStop = { [weak self] in
            self?.handleRecordingStop()
        }

        keyListener.onModeChange = { [weak self] mode in
            self?.status = .recording(mode)
        }

        keyListener.onCancel = { [weak self] in
            self?.handleCancel()
        }

        // Detect selected text immediately when Alt is pressed (before recording starts)
        keyListener.onAltPressed = { [weak self] in
            self?.pendingSelectedText = SelectedTextDetector.detect()
            if let text = self?.pendingSelectedText, !text.isEmpty {
                print("[AppState] Detected selected text: \(text.prefix(80))")
            }
        }

        aliyunSTT.onInterimResult = { [weak self] text in
            self?.interimText = text
        }
    }

    private func setupAudioCallbacks() {
        audioRecorder.onAudioLevel = { [weak self] level in
            self?.audioLevel = level
        }

        audioRecorder.onAudioChunk = { [weak self] chunk in
            guard let self else { return }
            let settings = SettingsStore.shared
            // Only stream chunks in Bailian mode (for streaming ASR)
            if settings.provider == .bailian {
                self.aliyunSTT.sendChunk(chunk)
            }
        }
    }

    // MARK: - Recording Flow

    private func handleRecordingStart(mode: RecordingMode) {
        print("[AppState] Recording start: \(mode)")
        status = .recording(mode)
        interimText = ""
        showOverlay = true
        soundPlayer.playBegin()

        do {
            try audioRecorder.startRecording()
            print("[AppState] Audio recorder started")

            // Start streaming ASR in Bailian mode
            if SettingsStore.shared.provider == .bailian {
                aliyunSTT.startStreaming()
            }
        } catch {
            print("[AppState] Microphone error: \(error)")
            status = .error("Microphone error: \(error.localizedDescription)")
        }
    }

    private func handleRecordingStop() {
        print("[AppState] Recording stop")
        soundPlayer.playEnd()
        let wavData = audioRecorder.stopRecording()
        let mode = keyListener.currentMode
        let settings = SettingsStore.shared

        // Capture selected text for QA context, then clear
        let selectedContext = (mode == .qa) ? pendingSelectedText : ""
        pendingSelectedText = ""

        status = .processing
        processingProgress = 0
        showOverlay = true

        processingTask = Task { @MainActor in
            do {
                let result: String

                print("[AppState] Processing: provider=\(settings.provider.rawValue), mode=\(mode.rawValue), context=\(selectedContext.isEmpty ? "(none)" : "\(selectedContext.prefix(60))...")")

                switch settings.provider {
                case .bailian:
                    result = try await processBailian(wavData: wavData, mode: mode, context: selectedContext)
                case .openRouter:
                    result = try await processOpenRouter(wavData: wavData, mode: mode, context: selectedContext)
                }

                if mode == .qa {
                    // QA mode: show in QA window (already streamed via processQA)
                } else {
                    // Transcribe/Translate: paste result then immediately hide overlay
                    await OutputManager.output(result)
                    status = .ready
                    showOverlay = false
                }
            } catch is CancellationError {
                status = .ready
                showOverlay = false
            } catch {
                let msg = friendlyError(error)
                if msg == "Cancelled" || msg.contains("cancelled") {
                    status = .ready
                    showOverlay = false
                } else {
                    // Show error briefly, then auto-hide
                    status = .error(msg)
                    try? await Task.sleep(for: .seconds(2))
                    if case .error = status {
                        status = .ready
                        showOverlay = false
                    }
                }
            }
        }
    }

    private func handleCancel() {
        processingTask?.cancel()
        processingTask = nil
        audioRecorder.cancel()
        aliyunSTT.cancelStreaming()
        status = .ready
        showOverlay = false
        interimText = ""
    }

    // MARK: - Bailian Processing

    private func processBailian(wavData: Data, mode: RecordingMode, context: String) async throws -> String {
        let settings = SettingsStore.shared
        let provider = BailianProvider()

        // Stop streaming ASR and get final transcription
        let transcription: String
        if aliyunSTT.isStreaming {
            transcription = try await aliyunSTT.stopStreaming()
        } else {
            transcription = try await aliyunSTT.transcribe(wavData: wavData)
        }

        guard !transcription.isEmpty else {
            throw LLMError.serverError(0, "No speech detected")
        }

        // ASR done → 50%
        withAnimation(.easeInOut(duration: 0.3)) { processingProgress = 0.5 }

        let result: String
        switch mode {
        case .transcribe:
            result = try await PolishService.polish(
                text: transcription,
                using: provider,
                prompt: settings.bailianPromptAsr
            )

        case .translate:
            result = try await TranslationService.translate(
                text: transcription,
                targetLanguage: settings.targetLanguage,
                using: provider,
                promptTemplate: settings.bailianPromptTranslation
            )

        case .qa:
            result = try await processQA(question: transcription, context: context, using: provider, prompt: settings.bailianPromptQa)
        }

        // LLM done → 100%
        withAnimation(.easeInOut(duration: 0.3)) { processingProgress = 1.0 }
        return result
    }

    // MARK: - OpenRouter Processing

    private func processOpenRouter(wavData: Data, mode: RecordingMode, context: String) async throws -> String {
        let settings = SettingsStore.shared
        let provider = OpenRouterProvider()

        var prompt: String
        switch mode {
        case .transcribe:
            prompt = settings.orPromptAsr
        case .translate:
            prompt = settings.orPromptTranslation.replacingOccurrences(of: "{language}", with: settings.targetLanguage)
        case .qa:
            prompt = settings.orPromptQa
            // Append context to system prompt for end-to-end audio QA
            if !context.isEmpty {
                prompt += "\n\nContext:\n\"\"\"\n\(context)\n\"\"\""
            }
        }

        if mode == .qa {
            return try await processQAAudio(wavData: wavData, using: provider, prompt: prompt)
        } else {
            // Audio-to-text multimodal: first token → 50%, done → 100%
            var receivedFirstToken = false
            let result = try await provider.processAudioStream(
                audioData: wavData,
                systemPrompt: prompt,
                onChunk: { [weak self] _ in
                    guard let self, !receivedFirstToken else { return }
                    receivedFirstToken = true
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.3)) { self.processingProgress = 0.5 }
                    }
                }
            )
            withAnimation(.easeInOut(duration: 0.3)) { processingProgress = 1.0 }
            return result
        }
    }

    // MARK: - QA Processing

    private func processQA(question: String, context: String = "", using provider: LLMProvider, prompt: String) async throws -> String {
        qaQuestion = question
        qaContext = context
        qaAnswer = ""
        qaIsDone = false
        qaHasError = false
        showQAWindow = true

        do {
            let result = try await QAService.ask(
                question: question,
                context: context.isEmpty ? nil : context,
                using: provider,
                prompt: prompt
            ) { [weak self] chunk in
                DispatchQueue.main.async {
                    self?.qaAnswer += chunk
                }
            }
            qaIsDone = true
            status = .ready
            showOverlay = false
            return result
        } catch {
            qaHasError = true
            qaErrorMessage = friendlyError(error)
            throw error
        }
    }

    private func processQAAudio(wavData: Data, using provider: OpenRouterProvider, prompt: String) async throws -> String {
        qaQuestion = "(Audio question)"
        qaAnswer = ""
        qaIsDone = false
        qaHasError = false
        showQAWindow = true

        do {
            let result = try await provider.processAudioStream(
                audioData: wavData,
                systemPrompt: prompt
            ) { [weak self] chunk in
                DispatchQueue.main.async {
                    self?.qaAnswer += chunk
                }
            }
            qaIsDone = true
            status = .ready
            showOverlay = false
            return result
        } catch {
            qaHasError = true
            qaErrorMessage = friendlyError(error)
            throw error
        }
    }

    // MARK: - Error Handling

    private func friendlyError(_ error: Error) -> String {
        if let llmError = error as? LLMError {
            return llmError.localizedDescription
        }

        let desc = error.localizedDescription
        if desc.contains("cancelled") || desc.contains("cancel") {
            return "Cancelled"
        }
        if desc.contains("timed out") || desc.contains("timeout") {
            return "Request timed out"
        }
        if desc.contains("network") || desc.contains("internet") || desc.contains("offline") {
            return "Network error"
        }
        return desc
    }
}
