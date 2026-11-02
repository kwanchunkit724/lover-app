import Foundation

// On-device stand-ins for KK tables. Nothing here talks to Supabase.
// TODO(kk-backend): swap each `pending*` flag for the RPC named in
// ios/KK_IOS_BACKEND_CONTRACT.md after the lover wipe migration. Do not
// point these calls at production lover tables.

@MainActor
final class DailyMoodStore: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var record: DailyMoodRecord?
    @Published private(set) var pendingRPC: PendingDailyMoodRPC?

    struct DailyMoodRecord: Codable, Equatable {
        var hktDate: String
        var mood: String
    }

    private var userId: UUID?

    func bind(userId: UUID) {
        guard self.userId != userId || !isReady else { return }
        self.userId = userId
        record = load()
        isReady = true
    }

    func clearSession() {
        userId = nil
        isReady = false
        record = nil
        pendingRPC = nil
    }

    func needsGate(now: Date = Date()) -> Bool {
        guard isReady else { return false }
        let day = KKTime.moodDayKey(now: now)
        guard let record, record.hktDate == day, DailyMoodLock.isAllowed(record.mood) else {
            return true
        }
        return false
    }

    func today(now: Date = Date()) -> DailyMood? {
        let day = KKTime.moodDayKey(now: now)
        guard let record, record.hktDate == day else { return nil }
        return DailyMood.from(label: record.mood)
    }

    func set(_ mood: DailyMood, now: Date = Date()) {
        guard DailyMoodLock.isAllowed(mood.label) else { return }
        let day = KKTime.moodDayKey(now: now)
        let next = DailyMoodRecord(hktDate: day, mood: mood.label)
        record = next
        pendingRPC = PendingDailyMoodRPC(mood: mood.label, hktDate: day)
        if let data = try? JSONEncoder().encode(next) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private var storageKey: String {
        "kk.dailyMood.v1.\(userId?.uuidString ?? "anon")"
    }

    private func load() -> DailyMoodRecord? {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(DailyMoodRecord.self, from: data),
              DailyMoodLock.isAllowed(decoded.mood) else { return nil }
        return decoded
    }
}

@MainActor
final class MemorySpaceStore: ObservableObject {
    @Published private(set) var items: [MemoryItem] = []
    @Published var draft: MemoryDraft?
    /// Set when a save should have called `kk_memory_*` and did not.
    @Published private(set) var pendingSync = false

    private var userId: UUID?

    func bind(userId: UUID) {
        guard self.userId != userId else { return }
        self.userId = userId
        items = load()
    }

    func clearSession() {
        userId = nil
        items = []
        draft = nil
    }

    func stageFromChat(_ messages: [Message]) {
        var lines: [String] = []
        var photos: [String] = []
        var markers: [String] = []
        for message in messages {
            switch message.kind {
            case .text, .kaomoji:
                if let text = message.text, !text.isEmpty { lines.append(text) }
            case .photo:
                photos.append("相片縮圖")
                if let caption = message.caption, !caption.isEmpty { lines.append(caption) }
            case .video:
                markers.append("影片")
            case .voice:
                markers.append("語音")
            }
        }
        draft = MemoryDraft(
            originalText: lines.joined(separator: "\n"),
            sourceMessageIds: messages.map(\.id),
            photoThumbMarkers: photos,
            attachmentMarkers: markers
        )
    }

    func saveDraft() {
        guard var draft else { return }
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = draft.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !original.isEmpty else { return }
        if let editing = draft.editingId, let idx = items.firstIndex(where: { $0.id == editing }) {
            items[idx].title = title
            items[idx].originalText = original
            items[idx].category = draft.category
            items[idx].noteSummary = draft.noteSummary
            items[idx].reminderAt = draft.reminderAt
            items[idx].photoThumbMarkers = draft.photoThumbMarkers
            items[idx].attachmentMarkers = draft.attachmentMarkers
            items[idx].sourceMessageIds = draft.sourceMessageIds
        } else {
            items.insert(MemoryItem(
                id: UUID(),
                title: title,
                originalText: original,
                category: draft.category,
                noteSummary: draft.noteSummary,
                sourceMessageIds: draft.sourceMessageIds,
                photoThumbMarkers: draft.photoThumbMarkers,
                attachmentMarkers: draft.attachmentMarkers,
                reminderAt: draft.reminderAt,
                createdAt: Date()
            ), at: 0)
        }
        self.draft = nil
        pendingSync = true
        persist()
    }

    func delete(_ id: UUID) {
        items.removeAll { $0.id == id }
        pendingSync = true
        persist()
    }

    func beginEdit(_ item: MemoryItem) {
        draft = MemoryDraft(
            title: item.title,
            originalText: item.originalText,
            category: item.category,
            noteSummary: item.noteSummary,
            sourceMessageIds: item.sourceMessageIds,
            photoThumbMarkers: item.photoThumbMarkers,
            attachmentMarkers: item.attachmentMarkers,
            reminderAt: item.reminderAt,
            editingId: item.id
        )
    }

    private var storageKey: String { "kk.memory.v1.\(userId?.uuidString ?? "anon")" }

    private func load() -> [MemoryItem] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([MemoryItem].self, from: data) else { return [] }
        return decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

@MainActor
final class WantYouKnowStore: ObservableObject {
    @Published private(set) var notes: [WantYouKnowNote] = []
    @Published private(set) var pendingSync = false

    private var userId: UUID?

    var visible: [WantYouKnowNote] { notes.filter(\.isVisible) }

    func bind(userId: UUID) {
        guard self.userId != userId else { return }
        self.userId = userId
        notes = load()
    }

    func clearSession() {
        userId = nil
        notes = []
    }

    func add(title: String, content: String, deadline: Date?, remind: Bool) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        notes.insert(WantYouKnowNote(
            id: UUID(),
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            content: trimmed,
            deadline: deadline,
            remindAtNineHKT: remind && deadline != nil,
            readByMe: true,
            readByPartner: false,
            deletedByMe: false,
            deletedByPartner: false,
            createdAt: Date()
        ), at: 0)
        pendingSync = true
        persist()
    }

    func markRead(_ id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].readByMe = true
        pendingSync = true
        persist()
    }

    func markDeletedByMe(_ id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].deletedByMe = true
        pendingSync = true
        persist()
    }

    /// Local stand-in for the partner's delete. The row stays until both sides delete.
    func markDeletedByPartner(_ id: UUID) {
        guard let idx = notes.firstIndex(where: { $0.id == id }) else { return }
        notes[idx].deletedByPartner = true
        pendingSync = true
        persist()
    }

    private var storageKey: String { "kk.want.v1.\(userId?.uuidString ?? "anon")" }

    private func load() -> [WantYouKnowNote] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WantYouKnowNote].self, from: data) else { return [] }
        return decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(notes) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

@MainActor
final class AIUsageStore: ObservableObject {
    static let cap = 10

    struct Snapshot: Codable, Equatable {
        var period: String
        var used: Int
        var remaining: Int { max(0, AIUsageStore.cap - used) }
        var isLocked: Bool { used >= AIUsageStore.cap }
    }

    @Published private(set) var snapshot = Snapshot(period: "", used: 0)
    @Published private(set) var pendingConsume = false
    @Published var lastNote: String?

    private var userId: UUID?

    func bind(userId: UUID, now: Date = Date()) {
        let period = KKTime.yearMonthKey(now: now)
        if self.userId != userId {
            self.userId = userId
            snapshot = load(period: period)
        } else if snapshot.period != period {
            snapshot = Snapshot(period: period, used: 0)
            persist()
        }
    }

    func clearSession() {
        userId = nil
        snapshot = Snapshot(period: "", used: 0)
        pendingConsume = false
    }

    /// Counts one couple-month use. Accepts typed text and memory ids only.
    /// Chat ciphertext is not a parameter and must not be added.
    func consume(userText: String, memoryItemIds: [UUID], now: Date = Date()) -> Bool {
        bindPeriod(now: now)
        let text = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !memoryItemIds.isEmpty else {
            lastNote = "AI 只處理你打嘅字同記憶空間項目。"
            return false
        }
        guard !snapshot.isLocked else {
            lastNote = "今個月 10 次用完。"
            return false
        }
        snapshot.used += 1
        pendingConsume = true
        lastNote = nil
        persist()
        return true
    }

    private func bindPeriod(now: Date) {
        let period = KKTime.yearMonthKey(now: now)
        if snapshot.period != period {
            snapshot = Snapshot(period: period, used: 0)
        }
    }

    private var storageKey: String { "kk.aiUsage.v1.\(userId?.uuidString ?? "anon")" }

    private func load(period: String) -> Snapshot {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(Snapshot.self, from: data) else {
            return Snapshot(period: period, used: 0)
        }
        if decoded.period != period { return Snapshot(period: period, used: 0) }
        return decoded
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(snapshot) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

@MainActor
final class KaomojiPrefsStore: ObservableObject {
    static let quickCap = 6

    @Published private(set) var quick: [String] = []
    @Published private(set) var recent: [String] = []
    @Published var capMessage: String?
    /// `kk_kaomoji_prefs_set` has not run. Quick reactions are local until then.
    @Published private(set) var pendingCloudSync = false

    private var userId: UUID?

    func bind(userId: UUID) {
        guard self.userId != userId else { return }
        self.userId = userId
        let stored = load()
        quick = stored.quick
        recent = stored.recent
        if quick.isEmpty {
            quick = Array(KaomojiCatalogue.bundled.quick_react.prefix(Self.quickCap))
            persist()
        }
    }

    func clearSession() {
        userId = nil
        quick = []
        recent = []
        capMessage = nil
    }

    func pushRecent(_ kao: String) {
        recent.removeAll { $0 == kao }
        recent.insert(kao, at: 0)
        if recent.count > 24 { recent = Array(recent.prefix(24)) }
        persist()
    }

    func clearRecent() {
        recent = []
        persist()
    }

    func toggleQuick(_ kao: String) {
        if let idx = quick.firstIndex(of: kao) {
            quick.remove(at: idx)
            capMessage = nil
        } else if quick.count >= Self.quickCap {
            capMessage = "快捷最多 6 個。"
            return
        } else {
            quick.append(kao)
            capMessage = nil
        }
        pendingCloudSync = true
        persist()
    }

    private struct Box: Codable {
        var quick: [String]
        var recent: [String]
    }

    private var storageKey: String { "kk.kaomojiPrefs.v1.\(userId?.uuidString ?? "anon")" }

    private func load() -> Box {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode(Box.self, from: data) else {
            return Box(quick: [], recent: [])
        }
        return Box(quick: Array(decoded.quick.prefix(Self.quickCap)), recent: decoded.recent)
    }

    private func persist() {
        let box = Box(quick: quick, recent: recent)
        if let data = try? JSONEncoder().encode(box) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
