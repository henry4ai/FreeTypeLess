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
        if let url = ResourceLocator.url(forResource: name, withExtension: ext, subdirectory: "audio"),
           let player = try? AVAudioPlayer(contentsOf: url) {
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
