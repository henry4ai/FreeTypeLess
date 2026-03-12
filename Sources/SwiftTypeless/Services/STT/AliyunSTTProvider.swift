import Foundation

final class AliyunSTTProvider {
    private let settings = SettingsStore.shared
    private var webSocketTask: URLSessionWebSocketTask?
    private var transcription = ""
    private var continuation: CheckedContinuation<String, Error>?

    var onInterimResult: ((String) -> Void)?

    // MARK: - Batch Transcription

    func transcribe(wavData: Data) async throws -> String {
        let pcmData = WavBuilder.stripHeader(wavData)
        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont
            self.transcription = ""
            connectAndTranscribe(pcmData: pcmData, streaming: false)
        }
    }

    // MARK: - Streaming (during recording)

    private var streamingSession: URLSessionWebSocketTask?
    private(set) var isStreaming = false
    private var isConnected = false

    func startStreaming() {
        let apiKey = settings.bailianApiKey
        guard !apiKey.isEmpty, !isStreaming else { return }
        isStreaming = true
        isConnected = false
        transcription = ""
        connectForStreaming()
    }

    func sendChunk(_ pcmData: Data) {
        guard let ws = streamingSession, isStreaming, isConnected else { return }
        let base64 = pcmData.base64EncodedString()
        let msg: [String: Any] = [
            "type": "input_audio_buffer.append",
            "audio": base64
        ]
        if let data = try? JSONSerialization.data(withJSONObject: msg) {
            ws.send(.string(String(data: data, encoding: .utf8)!)) { _ in }
        }
    }

    func stopStreaming() async throws -> String {
        guard isStreaming else { return transcription }
        isStreaming = false

        // If WebSocket never connected, return whatever we have
        guard isConnected, streamingSession != nil else {
            cleanupStreaming()
            return transcription
        }

        return try await withCheckedThrowingContinuation { cont in
            self.continuation = cont

            // Send commit + finish
            sendJSON(to: streamingSession, ["type": "input_audio_buffer.commit"])

            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .milliseconds(100))
                self?.sendJSON(to: self?.streamingSession, ["type": "session.finish"])
            }

            // Safety timeout: if server doesn't respond within 10s, resume with what we have
            Task { @MainActor [weak self] in
                try? await Task.sleep(for: .seconds(10))
                guard let self, let cont = self.continuation else { return }
                self.continuation = nil
                self.cleanupStreaming()
                cont.resume(returning: self.transcription)
            }
        }
    }

    func cancelStreaming() {
        isStreaming = false
        let pending = continuation
        continuation = nil
        cleanupStreaming()
        pending?.resume(returning: transcription)
    }

    private func cleanupStreaming() {
        streamingSession?.cancel(with: .normalClosure, reason: nil)
        streamingSession = nil
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    // MARK: - WebSocket Connection

    private func connectAndTranscribe(pcmData: Data, streaming: Bool) {
        let apiKey = settings.bailianApiKey
        guard !apiKey.isEmpty else {
            let pending = continuation
            continuation = nil
            pending?.resume(throwing: LLMError.invalidApiKey)
            return
        }

        let urlString = "wss://dashscope.aliyuncs.com/api-ws/v1/realtime?model=qwen3-asr-flash-realtime"
        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        let ws = session.webSocketTask(with: request)
        webSocketTask = ws
        ws.resume()

        receiveMessages(ws: ws)

        // Wait for connection, then send session.update
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendSessionUpdate(ws: ws, streaming: false)

            // Send audio chunks with delay
            DispatchQueue.global().async {
                let chunkSize = 3200 // 100ms at 16kHz, 16-bit
                var offset = 0
                while offset < pcmData.count {
                    let end = min(offset + chunkSize, pcmData.count)
                    let chunk = pcmData.subdata(in: offset..<end)
                    let base64 = chunk.base64EncodedString()

                    let msg: [String: Any] = [
                        "type": "input_audio_buffer.append",
                        "audio": base64
                    ]
                    self?.sendJSON(to: ws, msg)
                    offset = end
                    Thread.sleep(forTimeInterval: 0.05)
                }

                // Commit and finish
                self?.sendJSON(to: ws, ["type": "input_audio_buffer.commit"])
                Thread.sleep(forTimeInterval: 0.1)
                self?.sendJSON(to: ws, ["type": "session.finish"])
            }
        }
    }

    private func connectForStreaming() {
        let apiKey = settings.bailianApiKey
        guard !apiKey.isEmpty else {
            isStreaming = false
            return
        }

        let urlString = "wss://dashscope.aliyuncs.com/api-ws/v1/realtime?model=qwen3-asr-flash-realtime"
        var request = URLRequest(url: URL(string: urlString)!)
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        let session = URLSession(configuration: .default)
        let ws = session.webSocketTask(with: request)
        streamingSession = ws
        ws.resume()

        receiveMessages(ws: ws)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.sendSessionUpdate(ws: ws, streaming: true)
        }
    }

    private func sendSessionUpdate(ws: URLSessionWebSocketTask, streaming: Bool) {
        var sessionConfig: [String: Any] = [
            "modalities": ["text"],
            "input_audio_format": "pcm",
            "sample_rate": 16000
        ]

        if streaming {
            sessionConfig["turn_detection"] = [
                "type": "server_vad",
                "threshold": 0.5,
                "prefix_padding_ms": 500,
                "silence_duration_ms": 800
            ] as [String: Any]
        } else {
            sessionConfig["turn_detection"] = NSNull()
        }

        let msg: [String: Any] = [
            "type": "session.update",
            "session": sessionConfig
        ]
        sendJSON(to: ws, msg)
    }

    private func receiveMessages(ws: URLSessionWebSocketTask) {
        ws.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                case .data(let data):
                    if let text = String(data: data, encoding: .utf8) {
                        self.handleMessage(text)
                    }
                @unknown default:
                    break
                }
                // Continue receiving
                self.receiveMessages(ws: ws)

            case .failure(let error):
                let nsError = error as NSError
                // Suppress -999 cancelled (expected when we close the WebSocket ourselves)
                if nsError.code == -999 {
                    // WebSocket was cancelled by us — continuation already handled
                    let pending = self.continuation
                    self.continuation = nil
                    // Return whatever we have instead of throwing
                    pending?.resume(returning: self.transcription)
                } else {
                    print("[AliyunSTT] WebSocket error: \(error)")
                    let pending = self.continuation
                    self.continuation = nil
                    pending?.resume(throwing: error)
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String
        else { return }

        switch type {
        case "session.created":
            print("[AliyunSTT] session.created")

        case "session.updated":
            print("[AliyunSTT] session.updated")
            isConnected = true

        case "conversation.item.input_audio_transcription.text":
            if let transcript = json["transcript"] as? String {
                DispatchQueue.main.async { [weak self] in
                    self?.onInterimResult?(transcript)
                }
            }

        case "conversation.item.input_audio_transcription.completed":
            if let transcript = json["transcript"] as? String, !transcript.isEmpty {
                transcription += transcript
            }

        case "session.finished":
            if let transcript = json["transcript"] as? String, !transcript.isEmpty {
                transcription = transcript
            }
            let finalResult = transcription
            cleanupStreaming()
            let pending = continuation
            continuation = nil
            pending?.resume(returning: finalResult)

        case "error":
            // Try multiple fields for error message
            let errorMsg = (json["message"] as? String)
                ?? (json["msg"] as? String)
                ?? (json["error"] as? String)
                ?? {
                    // Log the full error JSON for debugging
                    if let rawData = try? JSONSerialization.data(withJSONObject: json, options: []),
                       let raw = String(data: rawData, encoding: .utf8) {
                        print("[AliyunSTT] Raw error JSON: \(raw)")
                    }
                    return "ASR error"
                }()
            print("[AliyunSTT] Error: \(errorMsg)")

            // If we already have some transcription, return it instead of throwing
            let pending = continuation
            continuation = nil
            cleanupStreaming()
            if !transcription.isEmpty {
                print("[AliyunSTT] Returning partial transcription despite error")
                pending?.resume(returning: transcription)
            } else {
                // No transcription and error (e.g. no speech detected) — return empty string silently
                print("[AliyunSTT] No transcription available, returning empty")
                pending?.resume(returning: "")
            }

        default:
            break
        }
    }

    // MARK: - Helpers

    private func sendJSON(to ws: URLSessionWebSocketTask?, _ dict: [String: Any]) {
        guard let ws, let data = try? JSONSerialization.data(withJSONObject: dict),
              let str = String(data: data, encoding: .utf8) else { return }
        ws.send(.string(str)) { error in
            if let error { print("[AliyunSTT] Send error: \(error)") }
        }
    }
}
