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
    @EnvironmentObject private var checklist: ChecklistService
    @EnvironmentObject private var kk: KKAppModel

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
    @State private var reactionTarget: Message? = nil   // emoji reaction picker
    // v1.6.1 — track whether we've done the first scroll-to-bottom so the
    // entry scroll is instant (no animation) but later scrolls animate.
    @State private var didInitialScroll = false
    @State private var showChecklist = false             // shared to-buy/to-do list
    @State private var selecting = false
    @State private var selectedMessageIDs: Set<String> = []
    @State private var showFileNote = false
    @State private var showAITextNote = false
    @State private var showCheer = false
    @StateObject private var voiceRecorder = VoiceRecorder()  // v1.6.5 voice

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
            ChatPolicyBanner()
            // v1.3.2 — visible banner when chatKey isn't ready yet. Without
            // this the user typed and pressed send into a void: ChatService
            // .sendText threw at the seal step and the message just
            // disappeared (no bubble on either side, no toast, nothing).
            if !crypto.isReady {
                cryptoNotReadyBanner
            }
            messageList
            composerArea
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
                    onFile: {
                        showActions = false
                        showFileNote = true
                    },
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
        // v1.6.5 — checklist as a compact top-right panel (~1/4 screen), not
        // a full sheet. Dim backdrop taps to close.
        .overlay {
            if showChecklist {
                ZStack(alignment: .topTrailing) {
                    Color.black.opacity(0.12).ignoresSafeArea()
                        .onTapGesture { showChecklist = false }
                    ChecklistSheet(onClose: { showChecklist = false })
                        .environmentObject(checklist)
                        .theme(theme)
                        .padding(.top, 52)
                        .padding(.trailing, 8)
                }
                .transition(.opacity)
            }
        }
        .alert("檔案", isPresented: $showFileNote) {
            Button("知道", role: .cancel) {}
        } message: {
            Text("檔案同圖、片一樣 48 小時後刪除，而且會端對端加密。檔案選擇器未接上。")
        }
        .alert("AI", isPresented: $showAITextNote) {
            Button("知道", role: .cancel) {}
        } message: {
            Text("AI 只處理你打嘅字同記憶空間項目，唔讀附件。")
        }
        .sheet(isPresented: $showCheer) {
            CheerSheet(mood: kk.dailyMood.today(), onClose: { showCheer = false })
                .theme(theme)
        }
    }

    /// Split out of `pairedBody` so the type checker does not give up on one
    /// expression. The previous chat body needed the same split.
    private var composerArea: some View {
        VStack(spacing: 0) {
            if let replyTo, !selecting {
                replyPreview(replyTo)
            }
            if !selecting, !kk.kaomoji.quick.isEmpty {
                ChatQuickKaomojiBar(items: kk.kaomoji.quick) { kao in
                    input.append(kao)
                    kk.kaomoji.pushRecent(kao)
                }
            }
            if selecting {
                ChatMultiSelectBar(
                    count: selectedMessageIDs.count,
                    onMemory: sendSelectionToMemory,
                    onAI: sendSelectionToAI,
                    onCancel: clearSelection
                )
            } else if voiceRecorder.isRecording {
                recordingBar
            } else {
                Composer(
                    input: $input,
                    inputFocused: $inputFocused,
                    onSend: send,
                    onTapKaomoji: toggleKaomoji,
                    onTapVideo: { showVideoPicker = true },
                    onTapPlus: { withAnimation(.easeInOut(duration: 0.18)) { showActions.toggle() } },
                    onTapCamera: { showCamera = true },
                    onTapMic: { voiceRecorder.start() }
                )
            }
            if showKaomoji {
                KaomojiPicker(
                    onPick: insertKaomoji,
                    onClose: { withAnimation(.easeInOut(duration: 0.18)) { showKaomoji = false } }
                )
                .frame(minHeight: 300)
            }
        }
    }

    private func toggleKaomoji() {
        if !showKaomoji {
            inputFocused = false
        }
        withAnimation(.easeInOut(duration: 0.18)) {
            showKaomoji.toggle()
        }
    }

    private func insertKaomoji(_ kao: String) {
        input.append(kao)
        kk.kaomoji.pushRecent(kao)
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

            Button { showCheer = true } label: {
                Text(kk.dailyMood.today()?.kao ?? "(･_･)")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(theme.inkSoft)
                    .lineLimit(1)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(theme.paperAlt, in: Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("今日心情 \(kk.dailyMood.today()?.label ?? "未揀")，打氣可選")

            // v1.6.5 Feature — shared quick checklist (short-term memory:
            // what to buy / do). Placed right behind the mood, replacing the
            // removed 閱後即焚 toggle.
            Button { showChecklist = true } label: {
                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(theme.inkMuted)
                    .overlay(alignment: .topTrailing) {
                        if checklist.openCount > 0 {
                            Text("\(checklist.openCount)")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(3)
                                .background(theme.rose, in: Circle())
                                .offset(x: 7, y: -7)
                        }
                    }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("購物 / 待辦清單")
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

    private func beginSelection(_ message: Message) {
        showKaomoji = false
        selecting = true
        selectedMessageIDs = [message.id]
    }

    private func toggleSelection(_ message: Message) {
        if selectedMessageIDs.contains(message.id) {
            selectedMessageIDs.remove(message.id)
        } else {
            selectedMessageIDs.insert(message.id)
        }
    }

    private func clearSelection() {
        selecting = false
        selectedMessageIDs = []
    }

    private var selectedMessages: [Message] {
        messages.filter { selectedMessageIDs.contains($0.id) }
    }

    private func sendSelectionToMemory() {
        let picked = selectedMessages
        guard !picked.isEmpty else { return }
        kk.memory.stageFromChat(picked)
        clearSelection()
        kk.requestedTab = .memory
    }

    /// AI sees typed text only. Photo captions count as typed. Attachments do not.
    private func sendSelectionToAI() {
        let lines: [String] = selectedMessages.compactMap { message in
            switch message.kind {
            case .text, .kaomoji:
                return message.text
            case .photo:
                return message.caption
            case .voice, .video:
                return nil
            }
        }.filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !lines.isEmpty else {
            showAITextNote = true
            return
        }
        kk.aiRequest = AIExpandRequest(userText: lines.joined(separator: "\n"), memoryItemIds: [])
        clearSelection()
    }

    // MARK: - Message stream

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    // v1.6.1 — load older history when scrolled to the top.
                    // Only present once there IS more (a full first page) and
                    // after the initial bottom-scroll, so it never fires on open.
                    if chat.hasMore && didInitialScroll {
                        ProgressView()
                            .tint(theme.inkMuted)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .onAppear { Task { await chat.loadOlder() } }
                    }
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
                            },
                            isSelecting: selecting,
                            isSelected: selectedMessageIDs.contains(m.id),
                            onBeginMultiSelect: { beginSelection(m) },
                            onToggleSelect: { toggleSelection(m) }
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
            // A NEW message arrived (newest id changed) → re-anchor to bottom.
            // Watching the last id (not count) means loading OLDER history on
            // scroll-up doesn't yank the view back down.
            .onChange(of: messages.last?.id) { _, _ in
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

    // MARK: - Voice recording (v1.6.5)

    private var recordingBar: some View {
        HStack(spacing: 14) {
            Button { voiceRecorder.cancel() } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(theme.inkMuted)
            }
            .buttonStyle(.plain)

            Circle().fill(.red).frame(width: 9, height: 9)
            Text(String(format: "錄緊音 0:%02d", voiceRecorder.elapsed))
                .font(DSText.mono(theme, 13).weight(.semibold))
                .foregroundStyle(theme.ink)
            Spacer()
            Button(action: sendVoice) {
                DSIcon(name: .arrow, size: 18, color: .white, strokeWidth: 2.4)
                    .frame(width: 40, height: 40)
                    .background(theme.rose)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(theme.paper)
        .overlay(Rectangle().frame(height: 0.5).foregroundStyle(theme.line), alignment: .top)
    }

    private func sendVoice() {
        guard let (data, dur) = voiceRecorder.finish() else { return }
        guard case .signedIn(let uuid) = auth.state, crypto.isReady else { return }
        Task { await chat.sendVoice(data: data, durationSec: dur, senderId: uuid) }
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
        .environmentObject(ChecklistService(crypto: CryptoService()))
        .environmentObject(KKAppModel())
        .theme(.jbeam)
}
