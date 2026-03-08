import AVFoundation
import Foundation

final class SoundPlayer {
    static let shared = SoundPlayer()

    private var players: [String: AVAudioPlayer] = [:]

    private init() {
        preload("beg", ext: "WAV")
        preload("end", ext: "WAV")
    }

    func playBegin() {
        play("beg")
    }

    func playEnd() {
        play("end")
    }

    private func preload(_ name: String, ext: String) {
        // Look in Resources/audio/ relative to executable
        let candidates = [
            Bundle.main.url(forResource: name, withExtension: ext),
            Bundle.main.url(forResource: name, withExtension: ext, subdirectory: "Resources/audio"),
        ]

        // Also check working directory
        let cwdPath = FileManager.default.currentDirectoryPath + "/Resources/audio/\(name).\(ext)"

        for candidate in candidates {
            if let url = candidate, let player = try? AVAudioPlayer(contentsOf: url) {
                player.prepareToPlay()
                players[name] = player
                return
            }
        }

        // Fallback: check cwd path
        let cwdURL = URL(fileURLWithPath: cwdPath)
        if FileManager.default.fileExists(atPath: cwdPath),
           let player = try? AVAudioPlayer(contentsOf: cwdURL) {
            player.prepareToPlay()
            players[name] = player
        }
    }

    private func play(_ name: String) {
        guard let player = players[name] else { return }
        player.currentTime = 0
        player.play()
    }
}
