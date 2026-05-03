import SwiftUI

// The chat tab — translation of ChatDetail in design-import/chat.jsx.
// Phase 4a wires real E2EE chat: ChatService polls Supabase every 3s,
// decrypts via shared chat key, exposes [DecryptedMessage]. We adapt those
// to the existing Message struct so MessageBubble keeps rendering.
//
// Voice + photo bubble paths still rely on placeholder kinds in this build
// — Phase 4c (v0.4.2) wires real media upload/encryption.

struct ChatView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var pairing: PairingService
    @EnvironmentObject private var chat: ChatService

    @State private var input: String = ""
    @State private var showKaomoji = false
    @State private var showVoice = false
    @State private var showActions = false
    @State private var replyTo: Message? = nil

    // Derived identities — fall back to mock for previews / unsigned state.
    private var meId: String {
        if case .signedIn(let uuid) = auth.state { return uuid.uuidString }
        return MockData.me.id
    }
    private var me: Person {
        let name = profileStore.profile?.myName ?? MockData.me.name
        return Person(id: meId, name: name, initial: String(name.prefix(1)), tint: .rose)
    }
    private var partner: Person {
        let name = pairing.partner?.myName
                ?? profileStore.profile?.partnerName
                ?? MockData.partner.name
        let id   = pairing.partner?.id.uuidString ?? MockData.partner.id
        return Person(id: id, name: name, initial: String(name.prefix(1)), tint: .sage)
    }

    /// ChatService DecryptedMessage → Message adapter so MessageBubble code
    /// keeps working unchanged.
    private var messages: [Message] {
        chat.messages.map { dm in
            Message(
                id: dm.id.uuidString,
                from: dm.senderId.uuidString,
                kind: messageKind(from: dm.payload.kind),
                timestamp: HHmm.format(dm.createdAt),
                read: true,
                text: dm.payload.text,
                photoSrc: nil,
                caption: nil,
                voiceDurationSec: nil,
                voiceTranscript: nil,
                replyTo: nil,
                reactions: []
            )
        }
    }

    private func messageKind(from k: ChatPayload.Kind) -> Message.Kind {
        switch k {
        case .text, .kaomoji: return .text
        case .photo:          return .photo
        case .voice:          return .voice
        }
    }

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
                    onSend: { _ in
                        // Phase 4c will wire real voice — for now no-op.
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
                    onTapCamera: { /* Phase 4c */ }
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
                    onCamera: { /* Phase 4c */ }
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
                Text(headerStatus)
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

    private var headerStatus: String {
        let isoDate = pairing.partner?.anniversaryISO ?? profileStore.profile?.anniversaryISO
        guard let iso = isoDate else { return "● 在線" }
        let today = LocalDate.string(from: Date())
        let days = TimeFormatting.daysBetween(iso, today)
        return "● 在線 · 一齊 \(days) 日"
    }

    // MARK: - Message stream

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(messages.indices, id: \.self) { i in
                        let m = messages[i]
                        let prev = i > 0 ? messages[i - 1] : nil
                        MessageBubble(
                            message: m,
                            isFromMe: m.from == me.id,
                            isContinuation: prev?.from == m.from,
                            onReact: { },
                            onReply: { replyTo = m }
                        )
                        .id(m.id)
                        .padding(.horizontal, 14)
                    }

                    if messages.isEmpty {
                        Text("仲未有訊息 — 講句嘢試下 (´｡• ω •｡`)")
                            .font(DSText.mono(theme, 12))
                            .foregroundStyle(theme.inkMuted)
                            .padding(.top, 80)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.top, 12)
                .padding(.bottom, 6)
            }
            .onChange(of: messages.count) { _, _ in
                withAnimation { proxy.scrollTo(messages.last?.id, anchor: .bottom) }
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

    // MARK: - Send

    private func send() {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard case .signedIn(let uuid) = auth.state else { return }
        let toSend = trimmed
        input = ""
        replyTo = nil
        Task { await chat.sendText(toSend, senderId: uuid) }
    }
}

// MARK: - Helpers

private enum HHmm {
    static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()
    static func format(_ date: Date) -> String { formatter.string(from: date) }
}

#Preview {
    ChatView()
        .environmentObject(UserProfileStore())
        .environmentObject(AuthService())
        .environmentObject(PairingService())
        .environmentObject(ChatService(crypto: CryptoService()))
        .theme(.jbeam)
}
