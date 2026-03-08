import Foundation

enum WavBuilder {
    /// Build a WAV file from raw PCM Int16 data
    /// - Parameters:
    ///   - pcmData: Raw PCM Int16 samples
    ///   - sampleRate: Sample rate (default 16000)
    ///   - channels: Number of channels (default 1 = mono)
    ///   - bitsPerSample: Bits per sample (default 16)
    /// - Returns: Complete WAV file data including header
    static func build(
        pcmData: Data,
        sampleRate: UInt32 = 16000,
        channels: UInt16 = 1,
        bitsPerSample: UInt16 = 16
    ) -> Data {
        var data = Data()
        let byteRate = sampleRate * UInt32(channels) * UInt32(bitsPerSample / 8)
        let blockAlign = channels * (bitsPerSample / 8)
        let dataSize = UInt32(pcmData.count)
        let fileSize = 36 + dataSize

        // RIFF header
        data.append(contentsOf: "RIFF".utf8)
        data.append(littleEndian: fileSize)
        data.append(contentsOf: "WAVE".utf8)

        // fmt subchunk
        data.append(contentsOf: "fmt ".utf8)
        data.append(littleEndian: UInt32(16))       // Subchunk1Size
        data.append(littleEndian: UInt16(1))         // AudioFormat (PCM)
        data.append(littleEndian: channels)
        data.append(littleEndian: sampleRate)
        data.append(littleEndian: byteRate)
        data.append(littleEndian: blockAlign)
        data.append(littleEndian: bitsPerSample)

        // data subchunk
        data.append(contentsOf: "data".utf8)
        data.append(littleEndian: dataSize)
        data.append(pcmData)

        return data
    }

    /// Strip the 44-byte WAV header from WAV data to get raw PCM
    static func stripHeader(_ wavData: Data) -> Data {
        guard wavData.count > 44 else { return wavData }
        return wavData.subdata(in: 44..<wavData.count)
    }
}

private extension Data {
    mutating func append(littleEndian value: UInt16) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 2))
    }

    mutating func append(littleEndian value: UInt32) {
        var v = value.littleEndian
        append(Data(bytes: &v, count: 4))
    }
}
