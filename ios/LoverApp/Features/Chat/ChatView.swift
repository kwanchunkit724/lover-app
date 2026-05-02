import SwiftUI

// The chat tab — translation of ChatDetail in design-import/chat.jsx.
// Header with partner avatar / message stream / reply preview / composer +
// modally-presented kaomoji picker / voice recorder / action sheet.
//
// Network + crypto are stubbed: messages come from MockData and a fake "Michel"
// auto-reply runs after each send. Real backend wiring lives in Core/Networking
// and gets injected via a ChatViewModel in v0.1.5.

struct ChatView: View {
    @Environment(\.theme) private var theme

    @State private var messages: [Message] = MockData.messages
    @State private var input: String = ""
    @State private var showKaomoji = false
    @State private var showVoice = false
    @State private var showActions = false
    @State private var replyTo: Message? = nil
    @State private var typing = false

    private let me = MockData.me
    private let partner = MockData.partner

    var body: some View {
        VStack(spacing: 0) {
            header
            messageList
            if let replyTo {
                replyPreview(replyTo)
            }
            if showVoice {
                VoiceRecorder(
                    onCancel: { showVoice = false },
                    onSend: { duration in
                        appendVoice(duration)
                        showVoice = false
                    }
                )
            } else {
                Composer(
                    input: $input,
                    onSend: send,
                    onTapKaomoji: { withAnimation(.easeInOut(duration: 0.18)) { showKaomoji.toggle() } },
                    onTapVoice: { showVoice = true },
                    onTapPlus: { withAnimation(.easeInOut(duration: 0.18)) { showActions.toggle() } },
                    onTapCamera: { /* TODO v0.2: open Camera */ }
                )
            }
            if showKaomoji {
                KaomojiPicker(
                    onPick: { kao in input.append(kao) },
                    onClose: { withAnimation(.easeInOut(duration: 0.18)) { showKaomoji = false } }
                )
                .transition(.move(edge: .bottom))
            }
        }
        .background(theme.paper.ignoresSafeArea())
        .overlay {
            if showActions {
                ChatActionSheet(
                    onClose: { withAnimation(.easeInOut(duration: 0.18)) { showActions = false } },
                    onCamera: { /* TODO v0.2 */ }
                )
                .transition(.opacity)
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 12) {
            DSAvatar(person: partner, size: 36)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 6) {
                    Text(partner.name)
                        .font(DSText.ui(theme, 16, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text("♡")
                        .font(DSText.mono(theme, 11))
                        .foregroundStyle(theme.rose)
                }
                Text("● 在線 · 一齊 711 日")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.sage)
            }

            Spacer()

            Button { } label: { DSIcon(name: .camera, size: 20, color: theme.rose) }
                .buttonStyle(.plain)
            Button { } label: { DSIcon(name: .more, size: 22, color: theme.inkSoft) }
                .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.top, 4)
        .padding(.bottom, 12)
        .background(theme.nav)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
            alignment: .bottom
        )
    }

    // MARK: - Message stream

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    Text(MockData.todayDateString)
                        .font(DSText.mono(theme, 10))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.top, 4)
                        .padding(.bottom, 14)
                        .frame(maxWidth: .infinity)

                    ForEach(messages.indices, id: \.self) { i in
                        let m = messages[i]
                        let prev = i > 0 ? messages[i - 1] : nil
                        MessageBubble(
                            message: m,
                            isFromMe: m.from == me.id,
                            isContinuation: prev?.from == m.from,
                            onReact: { reactQuick(to: m) },
                            onReply: { replyTo = m }
                        )
                        .id(m.id)
                        .padding(.horizontal, 14)
                    }

                    if typing {
                        TypingIndicator(partnerName: partner.name)
                            .padding(.horizontal, 14)
                            .id("__typing")
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 6)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
            }
            .onChange(of: typing) { _, newValue in
                if newValue { withAnimation { proxy.scrollTo("__typing", anchor: .bottom) } }
            }
        }
    }

    // MARK: - Reply preview

    private func replyPreview(_ msg: Message) -> some View {
        HStack(spacing: 10) {
            Rectangle()
                .fill(theme.rose)
                .frame(width: 3, height: 28)
                .clipShape(Capsule())

            VStack(alignment: .leading, spacing: 0) {
                Text("回覆 \(msg.from == me.id ? me.name : partner.name)")
                    .font(DSText.mono(theme, 11).weight(.semibold))
                    .foregroundStyle(theme.rose)
                Text(msg.previewText)
                    .font(DSText.ui(theme, 12))
                    .foregroundStyle(theme.inkSoft)
                    .lineLimit(1)
            }

            Spacer()

            Button { replyTo = nil } label: {
                DSIcon(name: .close, size: 16, color: theme.inkMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(theme.paperAlt)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
            alignment: .top
        )
    }

    // MARK: - Actions (mock send + auto-reply for design fidelity)

    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        var newMsg = Message(
            id: UUID().uuidString,
            from: me.id,
            kind: .text,
            timestamp: nowHHmm(),
            read: false,
            text: trimmed
        )
        if let reply = replyTo {
            newMsg.replyTo = .init(messageID: reply.id, kind: reply.kind, preview: reply.previewText)
        }
        messages.append(newMsg)
        input = ""
        replyTo = nil

        // Demo-only: simulate Michel typing then replying.
        Task {
            try? await Task.sleep(for: .milliseconds(1200))
            await MainActor.run { typing = true }
            try? await Task.sleep(for: .milliseconds(2300))
            await MainActor.run {
                typing = false
                messages.append(.init(
                    id: UUID().uuidString,
                    from: partner.id,
                    kind: .text,
                    timestamp: nowHHmm(),
                    read: true,
                    text: "收到 (♡˙︶˙♡)"
                ))
            }
        }
    }

    private func appendVoice(_ duration: Int) {
        messages.append(.init(
            id: UUID().uuidString,
            from: me.id,
            kind: .voice,
            timestamp: nowHHmm(),
            read: false,
            voiceDurationSec: duration
        ))
    }

    private func reactQuick(to message: Message) {
        guard let idx = messages.firstIndex(where: { $0.id == message.id }) else { return }
        let kao = MockData.quickReact.first ?? "(♡˙︶˙♡)"
        messages[idx].reactions.append(.init(from: me.id, kao: kao))
    }

    private func nowHHmm() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: Date())
    }
}

#Preview {
    ChatView().theme(.jbeam)
}
