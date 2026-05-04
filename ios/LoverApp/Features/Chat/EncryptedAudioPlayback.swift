import SwiftUI

// E2EE voice bubble. Shows the same waveform + duration UI as VoicePlayback
// but tapping play triggers an on-demand download + decrypt + load via
// MediaService → AudioPlayer. Once loaded, play/pause toggles work normally.

struct EncryptedAudioPlayback: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var chat: ChatService
    @StateObject private var player = AudioPlayer()

    let messageID: String
    let mediaHandle: String
    let durationSec: Int
    let isFromMe: Bool

    @State private var isLoading = false
    @State private var loadedOnce = false
    @State private var failed = false

    var body: some View {
        let fg = isFromMe ? theme.bubbleMeText : theme.ink
        let dim = isFromMe ? theme.bubbleMeText.opacity(0.4) : theme.inkMuted
        let bars = waveform()

        HStack(spacing: 8) {
            Button(action: handlePlayTap) {
                Group {
                    if isLoading {
                        ProgressView().tint(fg)
                    } else if failed {
                        Image(systemName: "exclamationmark")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(fg)
                    } else {
                        DSIcon(name: player.isPlaying ? .pause : .play2,
                               size: 14, color: fg)
                    }
                }
                .frame(width: 30, height: 30)
                .background(isFromMe ? theme.bubbleMeText.opacity(0.2) : theme.paperAlt)
                .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .disabled(isLoading)

            HStack(spacing: 2) {
                ForEach(Array(bars.enumerated()), id: \.offset) { idx, h in
                    let played = Double(idx) / Double(bars.count) < player.progress
                    Capsule()
                        .fill(played ? fg : dim)
                        .frame(width: 2.5, height: max(6, h * 28))
                }
            }
            .frame(height: 28)

            Text(String(format: "0:%02d", durationSec))
                .font(DSText.mono(theme, 10))
                .foregroundStyle(dim)
        }
        .frame(minWidth: 160)
    }

    private func handlePlayTap() {
        if !loadedOnce {
            isLoading = true
            Task {
                do {
                    let data = try await chat.mediaService.downloadAndDecrypt(path: mediaHandle)
                    player.load(data: data)
                    loadedOnce = true
                    isLoading = false
                    player.toggle()
                } catch {
                    failed = true
                    isLoading = false
                }
            }
        } else {
            player.toggle()
        }
    }

    /// Same deterministic pseudo-waveform as VoicePlayback for visual
    /// continuity. Phase 8 can replace with real audio analysis if we want
    /// to render the actual envelope.
    private func waveform() -> [Double] {
        let seed = messageID.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return (1...22).map { i in
            let n = (seed * (i + 1)) % 100
            return 0.3 + Double(n) / 100.0 * 0.7
        }
    }
}
