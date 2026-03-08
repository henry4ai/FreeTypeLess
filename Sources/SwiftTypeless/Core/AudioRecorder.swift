import Foundation
import AVFoundation

@Observable
final class AudioRecorder {
    private(set) var isRecording = false
    private(set) var audioLevel: Float = 0

    var onAudioChunk: ((Data) -> Void)?
    var onAudioLevel: ((Float) -> Void)?

    private var audioEngine: AVAudioEngine?
    private var pcmChunks: [Data] = []
    private let sampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 1024

    // Adaptive level: track recent RMS history to normalize against ambient noise
    private var rmsHistory: [Float] = []
    private let rmsHistoryMax = 60 // ~1-2s of history at typical callback rate
    private var recentPeak: Float = 0.001 // avoid division by zero

    func startRecording() throws {
        guard !isRecording else { return }

        let engine = AVAudioEngine()
        let inputNode = engine.inputNode
        let inputFormat = inputNode.inputFormat(forBus: 0)

        // Target format: 16kHz mono Float32
        guard let targetFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: false
        ) else {
            throw AudioRecorderError.formatError
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: targetFormat) else {
            throw AudioRecorderError.converterError
        }

        pcmChunks = []
        rmsHistory = []
        recentPeak = 0.001

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            guard let self else { return }

            // Convert to target format
            let frameCount = AVAudioFrameCount(
                Double(buffer.frameLength) * self.sampleRate / inputFormat.sampleRate
            )
            guard let convertedBuffer = AVAudioPCMBuffer(pcmFormat: targetFormat, frameCapacity: frameCount) else { return }

            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                outStatus.pointee = .haveData
                return buffer
            }

            guard status != .error, error == nil else { return }

            // Calculate RMS level
            let channelData = convertedBuffer.floatChannelData?[0]
            let frameLength = Int(convertedBuffer.frameLength)
            var rms: Float = 0
            if let data = channelData, frameLength > 0 {
                var sum: Float = 0
                for i in 0..<frameLength {
                    sum += data[i] * data[i]
                }
                rms = sqrt(sum / Float(frameLength))
            }

            // Update adaptive peak from recent history
            self.rmsHistory.append(rms)
            if self.rmsHistory.count > self.rmsHistoryMax {
                self.rmsHistory.removeFirst()
            }
            // Peak tracks the recent max, with a floor so quiet environments still show movement
            let historyMax = self.rmsHistory.max() ?? 0.001
            // Smooth peak: rise fast, decay slow
            if historyMax > self.recentPeak {
                self.recentPeak = historyMax
            } else {
                self.recentPeak = self.recentPeak * 0.95 + historyMax * 0.05
            }
            let floor: Float = 0.002
            let effectivePeak = max(self.recentPeak, floor)
            // Normalize current RMS against adaptive peak
            let normalized = min(rms / effectivePeak, 1.0)
            // Apply curve for better visual response
            let level = min(pow(normalized, 0.6) * 1.2, 1.0)

            DispatchQueue.main.async {
                self.audioLevel = level
                self.onAudioLevel?(self.audioLevel)
            }

            // Convert Float32 to Int16 PCM
            let int16Data = self.float32ToInt16(convertedBuffer)
            self.pcmChunks.append(int16Data)
            self.onAudioChunk?(int16Data)
        }

        try engine.start()
        audioEngine = engine
        isRecording = true
    }

    func stopRecording() -> Data {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        audioLevel = 0

        // Combine all chunks into WAV
        let pcmData = pcmChunks.reduce(Data()) { $0 + $1 }
        pcmChunks = []

        return WavBuilder.build(pcmData: pcmData)
    }

    func cancel() {
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        isRecording = false
        audioLevel = 0
        pcmChunks = []
    }

    // MARK: - Conversion

    private func float32ToInt16(_ buffer: AVAudioPCMBuffer) -> Data {
        guard let channelData = buffer.floatChannelData?[0] else { return Data() }
        let frameLength = Int(buffer.frameLength)
        var int16Data = Data(count: frameLength * 2)

        int16Data.withUnsafeMutableBytes { rawBuffer in
            let int16Buffer = rawBuffer.bindMemory(to: Int16.self)
            for i in 0..<frameLength {
                let sample = max(-1.0, min(1.0, channelData[i]))
                int16Buffer[i] = Int16(sample * 32767)
            }
        }

        return int16Data
    }
}

enum AudioRecorderError: LocalizedError {
    case formatError
    case converterError

    var errorDescription: String? {
        switch self {
        case .formatError: return "Failed to create audio format"
        case .converterError: return "Failed to create audio converter"
        }
    }
}
