import SwiftUI

// Inline voice playback bubble with deterministic pseudo-waveform.
// Translation of VoicePlayback in chat.jsx — same visual cadence,
// SwiftUI Timer drives progress.

struct VoicePlayback: View {
    @Environment(\.theme) private var theme

    let messageID: String
    let durationSec: Int
    let isFromMe: Bool

    @State private var playing = false
    @State private var progress: Double = 0
    private let timer = Timer.publish(every: 0.08, on: .main, in: .common).autoconnect()

    var body: some View {
        let fg = isFromMe ? theme.bubbleMeText : theme.ink
        let dim = isFromMe ? theme.bubbleMeText.opacity(0.4) : theme.inkMuted
        let bars = waveform()

        HStack(spacing: 8) {
            Button {
                playing.toggle()
                if !playing { progress = 0 }
            } label: {
                DSIcon(name: playing ? .pause : .play2, size: 14, color: fg)
                    .frame(width: 30, height: 30)
                    .background(isFromMe ? theme.bubbleMeText.opacity(0.2) : theme.paperAlt)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)

            HStack(spacing: 2) {
                ForEach(Array(bars.enumerated()), id: \.offset) { idx, h in
                    let played = Double(idx) / Double(bars.count) < progress
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
        .onReceive(timer) { _ in
            guard playing else { return }
            let step = 0.08 / max(0.5, Double(durationSec))
            progress += step
            if progress >= 1 { playing = false; progress = 0 }
        }
    }

    private func waveform() -> [Double] {
        let seed = messageID.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return (1...22).map { i in
            let n = (seed * (i + 1)) % 100
            return 0.3 + Double(n) / 100.0 * 0.7
        }
    }
}
