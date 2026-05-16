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
    @EnvironmentObject private var crypto: CryptoService

    @State private var input: String = ""
    @State private var showKaomoji = false
    @State private var showVoice = false
    @State private var showActions = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    // v1.0.5 — buffer the picked photo so user can confirm before sending
    // (per user request — accidental sends were a problem). Same buffer is
    // used for both camera + album paths.
    @State private var pendingPhoto: Data? = nil
    @State private var replyTo: Message? = nil
    // v1.5 — IG features
    @State private var reactionTarget: Message? = nil   // long-press target for emoji picker

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
        // Build a lookup so reply previews can resolve to the original bubble.
        let byId = Dictionary(uniqueKeysWithValues:
            chat.messages.map { ($0.id, $0) })

        return chat.messages.map { dm in
            // Reply preview lookup
            var reply: Message.ReplyPreview? = nil
            if let rid = dm.replyToId, let orig = byId[rid] {
                let kind = messageKind(from: orig.payload.kind)
                let text: String = {
                    if orig.deletedAt != nil { return "已撤回嘅訊息" }
                    switch kind {
                    case .text, .kaomoji: return orig.payload.text ?? ""
                    case .photo: return orig.payload.text ?? "📷 相片"
                    case .voice: return "🎙 語音訊息"
                    }
                }()
                reply = Message.ReplyPreview(
                    messageID: orig.id.uuidString,
                    kind: kind,
                    preview: text
                )
            }

            // Aggregate reactions: dedup by emoji (couples app: ≤2 users so
            // the row reads "❤️ 😂" not "❤️❤️ 😂").
            let uniqueEmojis = Array(Set(dm.reactions.map(\.emoji))).sorted()
            let reactions = uniqueEmojis.map { e in
                Message.Reaction(from: dm.senderId.uuidString, kao: e)
            }

            return Message(
                id: dm.id.uuidString,
                from: dm.senderId.uuidString,
                kind: messageKind(from: dm.payload.kind),
                timestamp: HHmm.format(dm.createdAt),
                read: dm.readAt != nil,
                text: dm.payload.text,
                photoSrc: (dm.payload.kind == .photo || dm.payload.kind == .voice)
                    ? dm.payload.mediaHandle : nil,
                caption: dm.payload.kind == .photo ? dm.payload.text : nil,
                voiceDurationSec: dm.payload.kind == .voice
                    ? parseVoiceDuration(dm.payload.text) : nil,
                voiceTranscript: nil,
                replyTo: reply,
                reactions: reactions,
                isEdited: dm.isEdited,
                isDeleted: dm.isDeleted
            )
        }
    }

    /// "0:23" → 23
    private func parseVoiceDuration(_ s: String?) -> Int? {
        guard let s, let parts = s.split(separator: ":").last,
              let n = Int(parts) else { return nil }
        return n
    }

    private func messageKind(from k: ChatPayload.Kind) -> Message.Kind {
        switch k {
        case .text, .kaomoji: return .text
        case .photo:          return .photo
        case .voice:          return .voice
        }
    }

    var body: some View {
        // Phase 9 — chat is the one tab that genuinely cannot work solo
        // (no partner = no recipient). Show pair prompt when unpaired.
        if !pairing.isPaired {
            UnpairedPrompt(
                title: "仲未配對",
                subtitle: "配對先可以同對方傾偈、send 相、send 語音。",
                kaomoji: "(´｡• ω •｡`)"
            )
        } else {
            pairedBody
        }
    }

    private var pairedBody: some View {
        VStack(spacing: 0) {
            header
            // v1.3.2 — visible banner when chatKey isn't ready yet. Without
            // this the user typed and pressed send into a void: ChatService
            // .sendText threw at the seal step and the message just
            // disappeared (no bubble on either side, no toast, nothing).
            if !crypto.isReady {
                cryptoNotReadyBanner
            }
            if chat.vanishMode {
                vanishBanner
            }
            messageList
            if let replyTo {
                replyPreview(replyTo)
            }
            if showVoice {
                VoiceRecorder(
                    onCancel: { showVoice = false },
                    onSend: { data, duration in
                        showVoice = false
                        guard case .signedIn(let uuid) = auth.state else { return }
                        Task { await chat.sendVoice(data: data, durationSec: duration, senderId: uuid) }
                    }
                )
            } else {
                Composer(
                    input: $input,
                    onSend: send,
                    onTapKaomoji: { withAnimation(.easeInOut(duration: 0.18)) { showKaomoji.toggle() } },
                    onTapVoice: { showVoice = true },
                    onTapPlus: { withAnimation(.easeInOut(duration: 0.18)) { showActions.toggle() } },
                    // v1.0.4 — camera icon now opens the actual camera, not
                    // the photo library. Plus button still opens the action
                    // sheet where the user can pick album / camera / etc.
                    onTapCamera: { showCamera = true }
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
            if let target = reactionTarget {
                ReactionPickerSheet(
                    onPick: { emoji in
                        guard case .signedIn(let uuid) = auth.state,
                              let mid = UUID(uuidString: target.id) else { return }
                        Task { await chat.addReaction(messageId: mid, emoji: emoji, userId: uuid) }
                    },
                    onClose: { reactionTarget = nil }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if showActions {
                ChatActionSheet(
                    onClose: { withAnimation(.easeInOut(duration: 0.18)) { showActions = false } },
                    onCamera: {
                        showActions = false
                        showCamera = true
                    },
                    onAlbum: {
                        showActions = false
                        showPhotoPicker = true
                    }
                )
                .transition(.opacity)
            }
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerSheet(
                onPick: { data in
                    showPhotoPicker = false
                    pendingPhoto = data
                },
                onCancel: { showPhotoPicker = false }
            )
        }
        .fullScreenCover(isPresented: $showCamera) {
            // Camera needs full-screen so the viewfinder gets the whole window.
            // PHPicker uses a sheet because it's a list UI; UIImagePicker camera
            // looks broken inside a partial sheet.
            CameraSheet(
                onPick: { data in
                    showCamera = false
                    pendingPhoto = data
                },
                onCancel: { showCamera = false }
            )
            .ignoresSafeArea()
        }
        .sheet(item: Binding(
            get: { pendingPhoto.map { PhotoPreviewItem(data: $0) } },
            set: { pendingPhoto = $0?.data }
        )) { item in
            PhotoConfirmSheet(
                imageData: item.data,
                onSend: {
                    let toSend = item.data
                    pendingPhoto = nil
                    guard case .signedIn(let uuid) = auth.state else { return }
                    Task { await chat.sendPhoto(data: toSend, caption: nil, senderId: uuid) }
                },
                onCancel: { pendingPhoto = nil }
            )
            .theme(theme)
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

            // v1.5 — Vanish mode toggle. Pinkish heart-with-slash icon when on.
            Button {
                let next = !chat.vanishMode
                Task { await chat.setVanishMode(enabled: next) }
            } label: {
                Image(systemName: chat.vanishMode ? "timer" : "timer.circle")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(chat.vanishMode ? theme.rose : theme.inkMuted)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(chat.vanishMode ? "關閉閱後即焚" : "開啟閱後即焚")
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
        // v1.0.5 — same fix as ProfileView.anniversaryISO (bug 5.1): use the
        // earlier of the two anniversary dates so both phones agree.
        let mine   = profileStore.profile?.anniversaryISO
        let theirs = pairing.partner?.anniversaryISO
        let iso: String? = {
            if let mine, let theirs { return min(mine, theirs) }
            return mine ?? theirs
        }()
        guard let iso else { return "● 在線" }
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
                            onReact: { reactionTarget = m },
                            onReply: { replyTo = m },
                            onUnsend: {
                                guard let uuid = UUID(uuidString: m.id) else { return }
                                Task { await chat.unsend(messageId: uuid) }
                            }
                        )
                        .id(m.id)
                        .padding(.horizontal, 14)
                        .onAppear {
                            // Auto mark-read when an incoming bubble scrolls
                            // into view. Idempotent server-side.
                            guard m.from != me.id, !m.read,
                                  let uuid = UUID(uuidString: m.id) else { return }
                            Task { await chat.markRead(messageId: uuid) }
                        }
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
            // v1.4.4 — also scroll to the latest message when the chat
            // tab first appears. Earlier the view kept its previous scroll
            // position (or stayed at the top on a cold open) so users had
            // to manually swipe down to see new messages, which felt like
            // the chat tab was broken on entry.
            .onAppear {
                guard let last = messages.last?.id else { return }
                DispatchQueue.main.async {
                    proxy.scrollTo(last, anchor: .bottom)
                }
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
        // v1.3.2 — refuse to send until chatKey is ready. Earlier we'd hand
        // the text off to chat.sendText which would silently throw at the
        // seal step and lose the message + clear the input. Now: keep the
        // text in the field so the user can re-tap once the banner clears.
        guard crypto.isReady else { return }
        let toSend = trimmed
        let replyId: UUID? = replyTo.flatMap { UUID(uuidString: $0.id) }
        input = ""
        replyTo = nil
        Task { await chat.sendText(toSend, senderId: uuid, replyToId: replyId) }
    }

    // v1.3.2/.3 — pinned diagnostic banner shown while crypto.chatKey is
    // still nil. v1.3.3 adds the actual state values (partner pubkey
    // length, last error, my-key status) so when the banner sticks we can
    // see exactly which precondition is failing — earlier the banner just
    // said "preparing..." with no signal.
    private var cryptoNotReadyBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                ProgressView().tint(theme.rose)
                Text("加密通道準備緊…")
                    .font(DSText.ui(theme, 12, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Button {
                    if case .signedIn(let id) = auth.state {
                        Task { await pairing.refresh(meId: id) }
                    }
                } label: {
                    Text("重試")
                        .font(DSText.mono(theme, 10).weight(.semibold))
                        .foregroundStyle(theme.rose)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .overlay(
                            Capsule().stroke(theme.rose, lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("• partner.publicKey: \(pairing.partner?.publicKey.map { "✓ \($0.count) chars" } ?? "❌ NIL")")
                Text("• my key: \(myKeyDiagnostic)")
                Text("• couple: \(pairing.couple != nil ? "✓" : "❌ NIL")")
                if let err = crypto.lastPrepareError {
                    Text("• last error: \(err)")
                        .foregroundStyle(theme.rose)
                }
            }
            .font(.system(size: 10, weight: .regular, design: .monospaced))
            .foregroundStyle(theme.inkMuted)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.amberSoft)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
            alignment: .bottom
        )
    }

    private var vanishBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "timer")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(theme.rose)
            Text("閱後即焚 · 訊息 24 小時後自動消失")
                .font(DSText.mono(theme, 11).weight(.medium))
                .foregroundStyle(theme.ink)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(theme.roseSoft)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
            alignment: .bottom
        )
    }

    private var myKeyDiagnostic: String {
        do {
            let pk = try KeyManager.shared.myPublicKeyBase64()
            return "✓ \(pk.count) chars"
        } catch {
            return "❌ \(String(describing: error))"
        }
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
