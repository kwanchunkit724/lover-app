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
    var onUnsend: (() -> Void)? = nil

    var body: some View {
        VStack(alignment: isFromMe ? .trailing : .leading, spacing: 0) {
            if let reply = message.replyTo {
                replyPreview(reply)
            }

            HStack(alignment: .bottom, spacing: 6) {
                if isFromMe { Spacer(minLength: 40) }

                bubbleContent
                    .contextMenu {
                        if !message.isDeleted {
                            Button { onReact() } label: { Label("回應", systemImage: "face.smiling") }
                            Button { onReply() } label: { Label("回覆", systemImage: "arrowshape.turn.up.left") }
                        }
                        if isFromMe, !message.isDeleted, let onUnsend {
                            Button(role: .destructive) { onUnsend() } label: {
                                Label("撤回", systemImage: "trash")
                            }
                        }
                    }
                    // v1.6.0 — anchor the reaction capsule to the bubble's
                    // bottom corner on the sender's side (right for own,
                    // left for partner) with a -10pt vertical offset so it
                    // visually overlaps the bottom edge. Previously it sat
                    // in the inter-bubble vertical gap because the capsule
                    // lived in the outer VStack and used row-level padding,
                    // which left it floating between the bubble and the
                    // next bubble's timestamp.
                    .overlay(alignment: isFromMe ? .bottomTrailing : .bottomLeading) {
                        if !message.reactions.isEmpty {
                            reactionsCapsule
                                .offset(x: isFromMe ? -8 : 8, y: 10)
                        }
                    }

                timestamp

                if !isFromMe { Spacer(minLength: 40) }
            }
            // KEY: without .frame(maxWidth: .infinity) the HStack collapses
            // to its content width (bubble + timestamp + 40pt min spacer ≈
            // 120pt) and the LazyVStack centers it, making own messages
            // float in the middle. Forcing full row width gives Spacer real
            // space to push the bubble flush against the correct edge.
            .frame(maxWidth: .infinity)
        }
        .padding(.top, isContinuation ? 0 : 8)
        // Extra bottom padding when reactions are present so the
        // capsule's +10pt overlap doesn't kiss the next bubble.
        .padding(.bottom, message.reactions.isEmpty ? 4 : 18)
    }

    // MARK: - Bubble content

    @ViewBuilder
    private var bubbleContent: some View {
        if message.isDeleted {
            deletedBubble
        } else {
            switch message.kind {
            case .text, .kaomoji:
                textBubble
            case .photo:
                photoBubble
            case .voice:
                voiceBubble
            case .video:
                videoBubble
            }
        }
    }

    // v1.6.0 — video bubble. Real backend videos go through EncryptedVideoPlayback
    // (download + decrypt + AVPlayer). For mocks / previews fall back to the
    // photo placeholder so the layout doesn't break.
    @ViewBuilder
    private var videoBubble: some View {
        Group {
            if let path = message.photoSrc, path.hasPrefix("couple-") {
                EncryptedVideoPlayback(
                    messageID: message.id,
                    mediaHandle: path,
                    durationSec: message.voiceDurationSec ?? 0,
                    isFromMe: isFromMe
                )
            } else {
                DSPhotoPlaceholder(id: message.photoSrc ?? message.id,
                                   height: 260,
                                   cornerRadius: 0)
                    .frame(width: 220)
            }
        }
        .clipShape(BubbleShape(isFromMe: isFromMe))
    }

    private var deletedBubble: some View {
        HStack(spacing: 6) {
            Image(systemName: "slash.circle")
                .font(.system(size: 12))
            Text("已撤回")
                .font(DSText.ui(theme, 14).italic())
        }
        .foregroundStyle(theme.inkMuted)
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .background(
            BubbleShape(isFromMe: isFromMe)
                .stroke(theme.line, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
        )
    }

    private var textBubble: some View {
        // Earlier this had `.frame(maxWidth: 270, alignment: .leading)` which
        // RESERVED 270pt of width regardless of text length, leaving a huge
        // empty area to the right of the bubble. In an HStack with Spacer-
        // based alignment that made own messages float around mid-screen
        // instead of hugging the right edge. Letting Text size to its own
        // content + applying maxWidth without alignment lets it wrap at 270
        // when long but stay tight when short.
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
        Group {
            // Real voice messages from the backend have photoSrc set to the
            // chat-media path (we reuse photoSrc for both kinds of media in
            // the ChatView adapter). Mock data uses no path.
            if let path = message.photoSrc, path.hasPrefix("couple-") {
                EncryptedAudioPlayback(
                    messageID: message.id,
                    mediaHandle: path,
                    durationSec: message.voiceDurationSec ?? 0,
                    isFromMe: isFromMe
                )
            } else {
                VoicePlayback(
                    messageID: message.id,
                    durationSec: message.voiceDurationSec ?? 0,
                    isFromMe: isFromMe
                )
            }
        }
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
            if message.isEdited && !message.isDeleted {
                Text("已編輯")
                    .font(DSText.mono(theme, 9))
                    .foregroundStyle(theme.inkMuted)
            }
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

    private var reactionsCapsule: some View {
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
