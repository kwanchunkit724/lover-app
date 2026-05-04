import Foundation
import AVFoundation
import Combine

// AVAudioPlayer wrapper used by EncryptedAudioPlayback to play decrypted
// voice messages from in-memory Data. One player per bubble; multiple
// instances co-exist (no global "now playing" coordination yet — Phase 8
// can add stop-others-on-play if it gets noisy).

@MainActor
final class AudioPlayer: NSObject, ObservableObject {

    @Published private(set) var isPlaying = false
    @Published private(set) var progress: Double = 0   // 0.0 - 1.0
    @Published private(set) var durationSec: Double = 0

    private var player: AVAudioPlayer?
    private var tickTask: Task<Void, Never>?

    /// Loads audio data into the player. Call once per bubble.
    func load(data: Data) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            let p = try AVAudioPlayer(data: data)
            p.delegate = self
            p.prepareToPlay()
            self.player = p
            self.durationSec = p.duration
        } catch {
            self.player = nil
        }
    }

    func toggle() {
        guard let player else { return }
        if player.isPlaying {
            player.pause()
            isPlaying = false
            tickTask?.cancel()
        } else {
            player.play()
            isPlaying = true
            startTicking()
        }
    }

    func reset() {
        player?.stop()
        player?.currentTime = 0
        isPlaying = false
        progress = 0
        tickTask?.cancel()
    }

    private func startTicking() {
        tickTask?.cancel()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 80_000_000)   // 12.5 fps
                guard let self else { break }
                await MainActor.run {
                    if let p = self.player, self.durationSec > 0 {
                        self.progress = p.currentTime / self.durationSec
                    }
                }
            }
        }
    }
}

extension AudioPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.isPlaying = false
            self.progress = 0
            self.tickTask?.cancel()
        }
    }
}
