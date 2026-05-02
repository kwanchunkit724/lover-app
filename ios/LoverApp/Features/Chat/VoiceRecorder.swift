import SwiftUI

// Voice recording UI — translation of VoiceRecorder in chat.jsx.
// Pulsing indicator, animated waveform, cancel + send buttons.
// Real recording (AVAudioRecorder) is wired up later — this is the visual shell.

struct VoiceRecorder: View {
    @Environment(\.theme) private var theme

    let onCancel: () -> Void
    let onSend: (Int) -> Void

    @State private var seconds: Int = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 14) {
                Circle()
                    .fill(theme.rose)
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulseScale)
                    .animation(
                        .easeInOut(duration: 1.4).repeatForever(autoreverses: true),
                        value: pulseScale
                    )

                HStack(spacing: 2) {
                    ForEach(0..<28) { i in
                        let active = i < (seconds * 2) % 28
                        Capsule()
                            .fill(active ? theme.rose : Color.black.opacity(0.15))
                            .frame(width: 2.5,
                                   height: active
                                   ? 8 + abs(sin(Double(i) + Double(seconds))) * 8
                                   : 5)
                    }
                }
                .frame(height: 28)

                Text(formatted(seconds))
                    .font(DSText.mono(theme, 13))
                    .foregroundStyle(theme.rose)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(theme.roseSoft)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

            HStack(spacing: 10) {
                Button(action: onCancel) {
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

                Button {
                    onSend(max(seconds, 1))
                } label: {
                    Text("傳送 (\(formatted(seconds)))")
                        .font(DSText.ui(theme, 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(theme.rose)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
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
        .onReceive(timer) { _ in seconds += 1 }
    }

    @State private var pulseScale: CGFloat = 1.0

    private func formatted(_ s: Int) -> String { String(format: "0:%02d", s) }
}
