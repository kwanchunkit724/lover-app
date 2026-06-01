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
    @EnvironmentObject private var presence: PresenceService
    @EnvironmentObject private var mood: MoodService
    @EnvironmentObject private var meetups: MeetupService

    // v1.6.1 (problem 5) — the 4-tab bar is back at the BOTTOM (pinned in
    // MainTabView). Chat just reports its keyboard state up so the bar can
    // slide away while typing. nil when rendered standalone (previews).
    var keyboardActive: Binding<Bool>? = nil

    @State private var input: String = ""
    @State private var showKaomoji = false
    @State private var showActions = false
    @State private var showPhotoPicker = false
    @State private var showCamera = false
    // v1.6.0 — video picker. Mirrors photo path but does its own compress
    // step before handing bytes to ChatService.sendVideo.
    @State private var showVideoPicker = false
    // v1.0.5 — buffer the picked photo so user can confirm before sending
    // (per user request — accidental sends were a problem). Same buffer is
    // used for both camera + album paths.
    @State private var pendingPhoto: Data? = nil
    @State private var replyTo: Message? = nil
    // v1.5 — IG features
    @State private var reactionTarget: Message? = nil   // long-press target for emoji picker
    // v1.6.1 — track whether we've done the first scroll-to-bottom so the
    // entry scroll is instant (no animation) but later scrolls animate.
    @State private var didInitialScroll = false
    // v1.6.1 Feature 7 (mood/cheer) + Feature 6 (meet-up) state.
    @State private var showMoodPicker = false
    @State private var cheerTarget: Mood? = nil          // I'm cheering partner
    @State private var received: MoodService.IncomingCheer? = nil
    @State private var showSetMeetup = false
    @State private var selfieMeetup: Meetup? = nil       // meet-up awaiting my selfie
    @State private var handledDueId: UUID? = nil         // dismissed selfie prompts

    // v1.6.0 — drive keyboard focus from code. Tapping the kaomoji button
    // resigns first responder before expanding the picker, so the picker
    // can claim the full ~300pt instead of getting squeezed above the
    // keyboard. Re-focusing the text field hides the picker.
    @FocusState private var inputFocused: Bool

    // v1.5.1 — Mock fallbacks stripped. When real data isn't loaded yet,
    // show neutral placeholders ("…") rather than fake identities like
    // 米雪 / Kit which mislead the user about who they are talking to.
    private var meId: String {
        if case .signedIn(let uuid) = auth.state { return uuid.uuidString }
        return ""
    }
    private var me: Person {
        let name = profileStore.profile?.myName ?? "…"
        return Person(id: meId, name: name, initial: String(name.prefix(1)), tint: .rose)
    }
    private var partner: Person {
        let name = pairing.partner?.myName
                ?? profileStore.profile?.partnerName
                ?? "…"
        let id   = pairing.partner?.id.uuidString ?? ""
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
                    case .video: return "📹 短片"
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
                photoSrc: (dm.payload.kind == .photo
                            || dm.payload.kind == .voice
                            || dm.payload.kind == .video)
                    ? dm.payload.mediaHandle : nil,
                caption: dm.payload.kind == .photo ? dm.payload.text : nil,
                // v1.6.0 — videos reuse the voice-duration field on the
                // wire (string "0:NN") so we don't need a schema change.
                voiceDurationSec: (dm.payload.kind == .voice
                                    || dm.payload.kind == .video)
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
        case .video:          return .video
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
            // v1.6.1 Feature 6 — next meet-up countdown.
            MeetupBanner(upcoming: meetups.upcoming) { showSetMeetup = true }
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
            Composer(
                input: $input,
                inputFocused: $inputFocused,
                onSend: send,
                onTapKaomoji: {
                    // v1.6.0 — kaomoji picker dismisses the keyboard first
                    // so it can claim the full 300pt expanded sheet height,
                    // instead of getting squeezed above the keyboard like
                    // the old version. Re-focusing the text field hides it.
                    if !showKaomoji {
                        inputFocused = false
                    }
                    withAnimation(.easeInOut(duration: 0.18)) {
                        showKaomoji.toggle()
                    }
                },
                onTapVideo: { showVideoPicker = true },
                onTapPlus: { withAnimation(.easeInOut(duration: 0.18)) { showActions.toggle() } },
                // v1.0.4 — camera icon now opens the actual camera, not
                // the photo library. Plus button still opens the action
                // sheet where the user can pick album / camera / etc.
                onTapCamera: { showCamera = true }
            )
            if showKaomoji {
                KaomojiPicker(
                    onPick: { kao in input.append(kao) },
                    onClose: { withAnimation(.easeInOut(duration: 0.18)) { showKaomoji = false } }
                )
                .frame(minHeight: 300)
                .transition(.move(edge: .bottom))
            }
        }
        // v1.6.0 — re-focus the text field => hide picker.
        // v1.6.1 — also tell MainTabView to hide the bottom bar while typing.
        .onChange(of: inputFocused) { _, focused in
            if focused, showKaomoji {
                withAnimation(.easeInOut(duration: 0.18)) { showKaomoji = false }
            }
            keyboardActive?.wrappedValue = focused
        }
        // Kaomoji picker also occupies the bottom; treat it like the keyboard
        // so the tab bar gets out of the way.
        .onChange(of: showKaomoji) { _, shown in
            keyboardActive?.wrappedValue = shown || inputFocused
        }
        .onDisappear { keyboardActive?.wrappedValue = false }
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
        .sheet(isPresented: $showVideoPicker) {
            // v1.6.0 — VideoPickerSheet handles PHPicker + 720p H.264
            // compress + 30s trim. Returns ready-to-encrypt bytes; we hand
            // them straight to ChatService.sendVideo (mirror of sendPhoto).
            VideoPickerSheet(
                onPick: { data, duration in
                    showVideoPicker = false
                    guard case .signedIn(let uuid) = auth.state else { return }
                    Task {
                        await chat.sendVideo(data: data,
                                             durationSec: duration,
                                             senderId: uuid)
                    }
                },
                onCancel: { showVideoPicker = false }
            )
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
        // ── Feature 7: mood + cheer ──────────────────────────────────────
        .overlay {
            if showMoodPicker {
                MoodPickerSheet(
                    current: mood.myMood,
                    onPick: { m in Task { await mood.setMood(m) } },
                    onClose: { showMoodPicker = false }
                )
                .transition(.opacity)
            }
        }
        .overlay {
            if let target = cheerTarget {
                CheerOverlay(
                    partnerName: partner.name,
                    mood: target,
                    onComplete: { Task { await mood.sendCheerComplete(targetMood: target) } },
                    onClose: { cheerTarget = nil }
                )
            }
        }
        .overlay {
            if let rc = received {
                CheerReceivedOverlay(
                    partnerName: partner.name,
                    mood: rc.mood,
                    onClose: { received = nil }
                )
            }
        }
        .onChange(of: mood.incomingCheer?.id) { _, _ in
            if let inc = mood.incomingCheer {
                received = inc
                mood.incomingCheer = nil
            }
        }
        // ── Feature 6: meet-up + forced selfie ───────────────────────────
        .overlay {
            if showSetMeetup {
                SetMeetupSheet(
                    existing: meetups.upcoming,
                    onCreate: { iso, title in Task { await meetups.createMeetup(meetDate: iso, title: title) } },
                    onCancel: { id in if let id { Task { await meetups.cancelMeetup(id) } } },
                    onClose: { showSetMeetup = false }
                )
                .transition(.opacity)
            }
        }
        .fullScreenCover(item: $selfieMeetup) { m in
            SelfiePromptView(
                meetup: m,
                onCapture: { data in
                    selfieMeetup = nil
                    Task { await meetups.submitSelfie(meetupId: m.id, data: data) }
                },
                onLater: { handledDueId = m.id; selfieMeetup = nil }
            )
            .theme(theme)
        }
        .onChange(of: meetups.dueMeetup?.id) { _, id in
            if let id, id != handledDueId, selfieMeetup == nil {
                selfieMeetup = meetups.dueMeetup
            }
        }
        .onAppear {
            if let due = meetups.dueMeetup, due.id != handledDueId, selfieMeetup == nil {
                selfieMeetup = due
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
                HStack(spacing: 4) {
                    if presence.partnerOnline {
                        Text("●")
                            .font(DSText.mono(theme, 10))
                            .foregroundStyle(.green)
                    }
                    Text(headerStatus)
                        .font(DSText.mono(theme, 10))
                        .foregroundStyle(theme.sage)
                }
            }

            Spacer()

            // v1.6.1 Feature 7 — partner's mood (tap to cheer) + my mood chip.
            if let pm = mood.partnerMood {
                Button {
                    if pm.needsCheer || pm == .happy || pm == .love { cheerTarget = pm }
                } label: {
                    Text(pm.emoji).font(.system(size: 20))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("伴侶心情 \(pm.label)，撳一下\(pm.cheerVerb)")
            }
            Button { showMoodPicker = true } label: {
                Text(mood.myMood?.emoji ?? "🙂")
                    .font(.system(size: 18))
                    .opacity(mood.myMood == nil ? 0.4 : 1)
                    .padding(6)
                    .background(theme.paperAlt, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("設定我嘅心情")

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
        // Phase C — real presence:
        //   * partner online via realtime presence channel → "在線"
        //   * offline but we know last_seen_at → "上次在線 X 分鐘前"
        //   * neither → relationship length ("一齊 N 日"), or "" if unknown.
        if presence.partnerOnline {
            return "在線"
        }
        if let last = pairing.partner?.lastSeenAt {
            return "上次在線 \(relativeMinutes(from: last))"
        }
        // v1.0.5 — same fix as ProfileView.anniversaryISO (bug 5.1): use the
        // earlier of the two anniversary dates so both phones agree.
        let mine   = profileStore.profile?.anniversaryISO
        let theirs = pairing.partner?.anniversaryISO
        let iso: String? = {
            if let mine, let theirs { return min(mine, theirs) }
            return mine ?? theirs
        }()
        guard let iso else { return "" }
        let today = LocalDate.string(from: Date())
        let days = TimeFormatting.daysBetween(iso, today)
        return "一齊 \(days) 日"
    }

    /// "上次在線 X 分鐘前 / X 小時前 / X 日前" — coarse buckets, Cantonese.
    private func relativeMinutes(from date: Date) -> String {
        let secs = max(0, Int(Date().timeIntervalSince(date)))
        if secs < 60 { return "啱啱" }
        let mins = secs / 60
        if mins < 60 { return "\(mins) 分鐘前" }
        let hours = mins / 60
        if hours < 24 { return "\(hours) 小時前" }
        return "\(hours / 24) 日前"
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

                    // v1.6.1 — stable bottom anchor. Scrolling to a fixed id
                    // (instead of messages.last, which changes identity and may
                    // not exist yet on cold open) makes "land on newest" robust
                    // against async decrypt + LazyVStack incremental layout.
                    Color.clear
                        .frame(height: 1)
                        .id("BOTTOM")
                }
                .padding(.top, 12)
                .padding(.bottom, 6)
            }
            // v1.6.1 (problem 2) — drag the history to dismiss the keyboard.
            .scrollDismissesKeyboard(.interactively)
            // Newest message arrived (or count changed) → re-anchor to bottom.
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy, animated: didInitialScroll)
            }
            // v1.6.1 (problem 4) — drive the FIRST scroll off the data
            // arriving, not off onAppear. On cold open messages is empty at
            // onAppear; this fires when decrypt completes and the list fills.
            .onChange(of: chat.messages.isEmpty) { _, isEmpty in
                guard !isEmpty else { return }
                scrollToBottom(proxy, animated: false)
                didInitialScroll = true
            }
            // v1.6.1 (problem 2) — when the keyboard rises (text field focus)
            // keep the newest bubble visible above it.
            .onChange(of: inputFocused) { _, focused in
                guard focused else { return }
                scrollToBottom(proxy, animated: true)
            }
            // v1.6.1 (problem 2) — when a reply/quote preview appears it pushes
            // the composer up; re-anchor so the quoted target stays visible.
            .onChange(of: replyTo?.id) { _, _ in
                scrollToBottom(proxy, animated: true)
            }
            // Warm re-entry (tab switch): messages already loaded, count won't
            // change, so scroll unconditionally on appear.
            .onAppear {
                guard !messages.isEmpty else { return }
                scrollToBottom(proxy, animated: false)
                didInitialScroll = true
            }
        }
    }

    /// Scroll to the stable BOTTOM anchor, with a second corrective pass after
    /// the LazyVStack finishes laying out tall photo/video bubbles (a single
    /// pass lands short while images are still sizing).
    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool) {
        let jump = { proxy.scrollTo("BOTTOM", anchor: .bottom) }
        if animated {
            withAnimation(.easeOut(duration: 0.25)) { jump() }
        } else {
            jump()
        }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 60_000_000)
            proxy.scrollTo("BOTTOM", anchor: .bottom)
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
        .environmentObject(PresenceService(myUserId: { nil }))
        .environmentObject(MoodService())
        .environmentObject(MeetupService(crypto: CryptoService()))
        .theme(.jbeam)
}
