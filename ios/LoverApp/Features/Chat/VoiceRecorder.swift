import SwiftUI

// Voice recording UI — translation of VoiceRecorder in chat.jsx.
// Pulsing indicator, animated waveform, cancel + send buttons.
// Real recording (AVAudioRecorder) is wired up later — this is the visual shell.

struct VoiceRecorder: View {
    @Environment(\.theme) private var theme

    let onCancel: () -> Void
    /// Called with the recorded audio Data + duration in seconds. The
    /// caller is responsible for encrypt + upload + insert.
    let onSend: (Data, Int) -> Void

    @StateObject private var recorder = AudioRecorder()

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Circle()
                    .fill(recorder.isRecording ? theme.rose : theme.inkMuted)
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                HStack(spacing: 2) {
                    ForEach(0..<28) { i in
                        let active = i < (recorder.seconds * 2) % 28
                        Capsule()
                            .fill(active ? theme.rose : Color.black.opacity(0.15))
                            .frame(width: 2.5,
                                   height: active
                                   ? 8 + abs(sin(Double(i) + Double(recorder.seconds))) * 8
                                   : 5)
                    }
                }
                .frame(height: 28)

                Text(formatted(recorder.seconds))
                    .font(DSText.mono(theme, 13))
                    .foregroundStyle(theme.rose)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(theme.roseSoft)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            if let err = recorder.lastError {
                Text(err)
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.rose)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 10) {
                Button(action: cancel) {
                    Text("取消")
                        .font(DSText.ui(theme, 14))
                        .foregroundStyle(theme.inkSoft)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(theme.line, lineWidth: 0.5)
                        )
                }
                .buttonStyle(.plain)

                Button(action: send) {
                    Text("傳送 (\(formatted(recorder.seconds)))")
                        .font(DSText.ui(theme, 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(recorder.isRecording ? theme.rose : theme.line)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(!recorder.isRecording)
                .layoutPriority(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 20)
        .padding(.bottom, 16)
        .background(theme.paper)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
            alignment: .top
        )
        .task {
            // Start recording the moment the recorder appears. The OS will
            // prompt for mic permission on first use.
            pulseScale = 0.6
            _ = await recorder.start()
        }
        .onDisappear { recorder.cancel() }
    }

    @State private var pulseScale: CGFloat = 1.0

    private func formatted(_ s: Int) -> String { String(format: "0:%02d", s) }

    private func send() {
        guard let result = recorder.stop() else {
            onCancel()
            return
        }
        onSend(result.data, result.durationSec)
    }

    private func cancel() {
        recorder.cancel()
        onCancel()
    }
}
