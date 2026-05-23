import SwiftUI

// Bottom message composer — translation of Composer in chat.jsx.
// Plus / camera / [text input + kao] / [send|mic] swap on text presence.

struct Composer: View {
    @Environment(\.theme) private var theme
    @Binding var input: String
    @FocusState.Binding var inputFocused: Bool
    let onSend: () -> Void
    let onTapKaomoji: () -> Void
    let onTapVideo: () -> Void
    let onTapPlus: () -> Void
    let onTapCamera: () -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            iconButton(.plus, action: onTapPlus)
            iconButton(.camera, action: onTapCamera)

            HStack(spacing: 4) {
                TextField("訊息…", text: $input, axis: .vertical)
                    .font(DSText.ui(theme, 15))
                    .foregroundStyle(theme.ink)
                    .focused($inputFocused)
                    .padding(.leading, 14)
                    .padding(.vertical, 8)
                    .lineLimit(1...5)
                    .submitLabel(.send)
                    .onSubmit(onSend)

                Button(action: onTapKaomoji) {
                    DSIcon(name: .kao, size: 18, color: theme.inkSoft)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
            }
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .frame(minHeight: 36)

            if input.trimmingCharacters(in: .whitespaces).isEmpty {
                // v1.6.0 — mic replaced by video. VoiceRecorder was deleted
                // from the build; existing voice bubbles still render via
                // EncryptedAudioPlayback so the historic message stream is
                // unaffected.
                iconButton(.video, action: onTapVideo)
            } else {
                Button(action: onSend) {
                    DSIcon(name: .arrow, size: 18, color: .white, strokeWidth: 2.4)
                        .frame(width: 36, height: 36)
                        .background(theme.rose)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(theme.paper)
        .overlay(
            Rectangle()
                .frame(height: 0.5)
                .foregroundStyle(theme.line),
            alignment: .top
        )
    }

    private func iconButton(_ name: DSIconName, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            DSIcon(name: name, size: 20, color: theme.inkSoft)
                .frame(width: 36, height: 36)
                .background(theme.paperAlt)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
