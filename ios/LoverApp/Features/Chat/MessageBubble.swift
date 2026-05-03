import SwiftUI

// Single message bubble — translation of MessageRow + VoicePlayback in chat.jsx.
// Renders text, photo, and voice variants with consistent layout for me/them.

struct MessageBubble: View {
    @Environment(\.theme) private var theme

    let message: Message
    let isFromMe: Bool
    let isContinuation: Bool
    let onReact: () -> Void
    let onReply: () -> Void

    var body: some View {
        VStack(alignment: isFromMe ? .trailing : .leading, spacing: 0) {
            if let reply = message.replyTo {
                replyPreview(reply)
            }

            HStack(alignment: .bottom, spacing: 6) {
                if isFromMe { Spacer(minLength: 40) }

                bubbleContent
                    .contextMenu {
                        Button { onReact() } label: { Label("回應", systemImage: "face.smiling") }
                        Button { onReply() } label: { Label("回覆", systemImage: "arrowshape.turn.up.left") }
                    }

                timestamp

                if !isFromMe { Spacer(minLength: 40) }
            }

            if !message.reactions.isEmpty {
                reactionsRow
            }
        }
        .padding(.top, isContinuation ? 0 : 8)
        .padding(.bottom, message.reactions.isEmpty ? 4 : 18)
    }

    // MARK: - Bubble content

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.kind {
        case .text, .kaomoji:
            textBubble
        case .photo:
            photoBubble
        case .voice:
            voiceBubble
        }
    }

    private var textBubble: some View {
        Text(message.text ?? "")
            .font(DSText.ui(theme, 15))
            .foregroundStyle(isFromMe ? theme.bubbleMeText : theme.bubbleThemText)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                BubbleShape(isFromMe: isFromMe)
                    .fill(isFromMe ? theme.bubbleMe : theme.bubbleThem)
            )
            .overlay(
                BubbleShape(isFromMe: isFromMe)
                    .stroke(isFromMe ? Color.clear : theme.bubbleThemBorder, lineWidth: 0.5)
            )
            .frame(maxWidth: 270, alignment: .leading)
    }

    private var photoBubble: some View {
        VStack(spacing: 0) {
            // Real photos coming from the backend have photoSrc set to a
            // chat-media storage path ("couple-{uuid}/{uuid}.bin"). Mock
            // photos in previews / MockData use a short placeholder id.
            // EncryptedAsyncImage handles the download + decrypt path.
            if let path = message.photoSrc, path.hasPrefix("couple-") {
                EncryptedAsyncImage(mediaHandle: path, maxHeight: 260, cornerRadius: 0)
                    .frame(width: 220)
            } else {
                DSPhotoPlaceholder(id: message.photoSrc ?? message.id, height: 260, cornerRadius: 0)
                    .frame(width: 220)
            }

            if let caption = message.caption {
                Text(caption)
                    .font(DSText.ui(theme, 14))
                    .foregroundStyle(isFromMe ? theme.bubbleMeText : theme.bubbleThemText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(isFromMe ? theme.bubbleMe : theme.bubbleThem)
            }
        }
        .clipShape(BubbleShape(isFromMe: isFromMe))
    }

    private var voiceBubble: some View {
        VoicePlayback(
            messageID: message.id,
            durationSec: message.voiceDurationSec ?? 0,
            isFromMe: isFromMe
        )
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            BubbleShape(isFromMe: isFromMe)
                .fill(isFromMe ? theme.bubbleMe : theme.bubbleThem)
        )
        .overlay(
            BubbleShape(isFromMe: isFromMe)
                .stroke(isFromMe ? Color.clear : theme.bubbleThemBorder, lineWidth: 0.5)
        )
    }

    // MARK: - Auxiliary

    private var timestamp: some View {
        HStack(spacing: 4) {
            Text(message.timestamp)
                .font(DSText.mono(theme, 10))
                .foregroundStyle(theme.inkMuted)

            if isFromMe {
                Text(message.read ? "✓✓" : "✓")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(message.read ? theme.sage : theme.inkMuted)
            }
        }
        .padding(.bottom, 2)
    }

    private var reactionsRow: some View {
        let kaos = message.reactions.map(\.kao).joined(separator: " ")
        return Text(kaos)
            .font(DSText.mono(theme, 12))
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(theme.surface)
            .overlay(
                Capsule().stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(Capsule())
            .padding(.top, -10)
            .padding(.horizontal, 8)
    }

    private func replyPreview(_ reply: Message.ReplyPreview) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("↰ 回覆")
                .font(DSText.mono(theme, 10))
                .foregroundStyle(theme.inkSoft)
            Text(reply.preview)
                .font(DSText.ui(theme, 11))
                .foregroundStyle(theme.inkMuted)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(theme.paperAlt)
        .overlay(
            Rectangle()
                .frame(width: 2)
                .foregroundStyle(theme.rose),
            alignment: .leading
        )
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .frame(maxWidth: 200, alignment: isFromMe ? .trailing : .leading)
        .padding(.bottom, 3)
    }
}

// Asymmetric bubble: rounded everywhere except the bottom corner closest to the
// avatar side, which is tighter (6pt vs 18pt) to give the "tail" effect.
// iOS 17 UnevenRoundedRectangle handles per-corner radii natively.
struct BubbleShape: Shape {
    let isFromMe: Bool

    func path(in rect: CGRect) -> Path {
        let big: CGFloat = 18
        let small: CGFloat = 6
        let radii = RectangleCornerRadii(
            topLeading: big,
            bottomLeading: isFromMe ? big : small,
            bottomTrailing: isFromMe ? small : big,
            topTrailing: big
        )
        return UnevenRoundedRectangle(cornerRadii: radii, style: .continuous)
            .path(in: rect)
    }
}

#Preview {
    VStack(spacing: 8) {
        MessageBubble(
            message: MockData.messages[0],
            isFromMe: false,
            isContinuation: false,
            onReact: {},
            onReply: {}
        )
        MessageBubble(
            message: MockData.messages[3],
            isFromMe: true,
            isContinuation: false,
            onReact: {},
            onReply: {}
        )
    }
    .padding()
    .background(Theme.jbeam.paper)
    .theme(.jbeam)
}
