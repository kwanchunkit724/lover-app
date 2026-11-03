import Foundation

// KK stores. Lists are read through RLS. Writes go through `kk_*` RPCs in KKRPC.
// A local cache remains so the UI can paint before the network returns.

@MainActor
final class DailyMoodStore: ObservableObject {
    @Published private(set) var isReady = false
    @Published private(set) var record: DailyMoodRecord?
    @Published private(set) var pendingRPC: PendingDailyMoodRPC?
    @Published var lastError: String?

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
        lastError = nil
    }

    func needsGate(now: Date = Date()) -> Bool {
        guard isReady else { return false }
        guard KKTime.isMoodGateOpen(now: now) else { return false }
        let day = KKTime.calendarDayKey(now: now)
        guard let record, record.hktDate == day, DailyMoodLock.isAllowed(record.mood) else {
            return true
        }
        return false
    }

    func today(now: Date = Date()) -> DailyMood? {
        guard let record, DailyMoodLock.isAllowed(record.mood) else { return nil }
        if KKTime.isMoodGateOpen(now: now) {
            guard record.hktDate == KKTime.calendarDayKey(now: now) else { return nil }
        }
        return DailyMood.from(label: record.mood)
    }

    func refreshFromServer() async {
        if UITesting.blocksNetwork { return }
        guard let userId else { return }
        do {
            guard let row = try await KKRPC.myMood(userId: userId),
                  let label = row.mood,
                  DailyMoodLock.isAllowed(label),
                  let updated = KKTimestamps.parse(row.mood_updated_at) else { return }
            let day = KKTime.calendarDayKey(now: updated)
            guard day == KKTime.calendarDayKey(now: Date()) else { return }
            let next = DailyMoodRecord(hktDate: day, mood: label)
            record = next
            persist(next)
            lastError = nil
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Writes `kk_set_daily_mood` with the locked label. Does not retry with another character.
    func set(_ mood: DailyMood, now: Date = Date()) async {
        if UITesting.blocksNetwork {
            lastError = "UI test fixture does not write mood."
            return
        }
        guard DailyMoodLock.isAllowed(mood.label) else { return }
        guard KKTime.isMoodGateOpen(now: now) else {
            lastError = "香港時間 06:00 之前伺服器唔收心情。"
            return
        }
        let day = KKTime.calendarDayKey(now: now)
        pendingRPC = PendingDailyMoodRPC(mood: mood.label, hktDate: day)
        do {
            let result = try await KKRPC.setDailyMood(mood, hktDate: day)
            guard DailyMoodLock.isAllowed(result.mood) else {
                lastError = "伺服器回覆唔喺心情白名單，冇採用。"
                return
            }
            let next = DailyMoodRecord(hktDate: result.hkt_date, mood: result.mood)
            record = next
            pendingRPC = nil
            lastError = nil
            persist(next)
        } catch KKRPCError.moodScalarMismatch {
            lastError = "心情字元唔係 U+6530，冇送出。"
        } catch {
            lastError = error.localizedDescription
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

    private func persist(_ next: DailyMoodRecord) {
        if let data = try? JSONEncoder().encode(next) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}

@MainActor
final class MemorySpaceStore: ObservableObject {
    @Published private(set) var items: [MemoryItem] = []
    @Published var draft: MemoryDraft?
    /// Set when a save should have called `kk_memory_*` and did not.
    @Published private(set) var pendingSync = false
    @Published var lastError: String?

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
        lastError = nil
    }

    func refreshFromServer() async {
        if UITesting.blocksNetwork { return }
        do {
            let rows = try await KKRPC.listMemories()
            items = rows.compactMap(Self.item(from:))
            pendingSync = false
            lastError = nil
            persist()
        } catch {
            lastError = error.localizedDescription
        }
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

    func saveDraft() async -> Bool {
        guard let draft else { return false }
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let original = draft.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty || !original.isEmpty else { return false }
        let reminderISO = draft.reminderAt.map(KKTimestamps.iso)
        do {
            if let editing = draft.editingId {
                try await KKRPC.updateMemory(
                    id: editing,
                    title: title,
                    original: original,
                    category: draft.category.label,
                    note: draft.noteSummary,
                    sourceIds: draft.sourceMessageIds,
                    photos: draft.photoThumbMarkers,
                    markers: draft.attachmentMarkers,
                    reminderISO: reminderISO,
                    clearReminder: draft.reminderAt == nil
                )
            } else if !draft.sourceMessageIds.isEmpty && draft.noteSummary.isEmpty && draft.reminderAt == nil {
                _ = try await KKRPC.memoryFromChat(
                    title: title,
                    original: original,
                    category: draft.category.label,
                    sourceIds: draft.sourceMessageIds,
                    photos: draft.photoThumbMarkers,
                    markers: draft.attachmentMarkers
                )
            } else {
                _ = try await KKRPC.createMemory(
                    title: title,
                    original: original,
                    category: draft.category.label,
                    note: draft.noteSummary,
                    sourceIds: draft.sourceMessageIds,
                    photos: draft.photoThumbMarkers,
                    markers: draft.attachmentMarkers,
                    reminderISO: reminderISO
                )
            }
            self.draft = nil
            pendingSync = false
            lastError = nil
            await refreshFromServer()
            return true
        } catch {
            lastError = error.localizedDescription
            pendingSync = true
            return false
        }
    }

    func delete(_ id: UUID) async {
        do {
            try await KKRPC.deleteMemory(id: id)
            items.removeAll { $0.id == id }
            pendingSync = false
            lastError = nil
            persist()
        } catch {
            lastError = error.localizedDescription
            pendingSync = true
        }
    }

    private static func item(from row: KKRPC.MemoryRow) -> MemoryItem? {
        guard let category = MemoryCategory.allCases.first(where: { $0.label == row.category }) else { return nil }
        return MemoryItem(
            id: row.id,
            title: row.title,
            originalText: row.original_text,
            category: category,
            noteSummary: row.note_summary,
            sourceMessageIds: row.source_message_refs,
            photoThumbMarkers: row.photo_thumbs,
            attachmentMarkers: row.attachment_markers,
            reminderAt: KKTimestamps.parse(row.reminder_at),
            createdAt: KKTimestamps.parse(row.created_at) ?? Date()
        )
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
    @Published var lastError: String?

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
        lastError = nil
    }

    func refreshFromServer() async {
        if UITesting.blocksNetwork { return }
        guard let userId else { return }
        do {
            let rows = try await KKRPC.listWants()
            let reads = try await KKRPC.listWantReads()
            let ends = try await KKRPC.myCoupleEnds()
            let meIsA = ends?.user_a_id == userId
            notes = rows.map { row in
                let readers = reads.filter { $0.item_id == row.id }.map(\.user_id)
                let deletedMe = meIsA ? row.deleted_by_a : row.deleted_by_b
                let deletedThem = meIsA ? row.deleted_by_b : row.deleted_by_a
                return WantYouKnowNote(
                    id: row.id,
                    title: row.title ?? "",
                    content: row.body,
                    deadline: KKTimestamps.parse(row.deadline_at),
                    remindAtNineHKT: row.remind,
                    readByMe: readers.contains(userId),
                    readByPartner: readers.contains { $0 != userId },
                    deletedByMe: deletedMe,
                    deletedByPartner: deletedThem,
                    createdAt: KKTimestamps.parse(row.created_at) ?? Date()
                )
            }
            pendingSync = false
            lastError = nil
            persist()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func add(title: String, content: String, deadline: Date?, remind: Bool) async -> Bool {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        do {
            _ = try await KKRPC.createWant(
                body: trimmed,
                title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                deadline: deadline.map { KKTime.calendarDayKey(now: $0) },
                remind: remind && deadline != nil
            )
            pendingSync = false
            lastError = nil
            await refreshFromServer()
            return true
        } catch {
            lastError = error.localizedDescription
            pendingSync = true
            return false
        }
    }

    func markRead(_ id: UUID) async {
        if let idx = notes.firstIndex(where: { $0.id == id }) {
            notes[idx].readByMe = true
        }
        do {
            try await KKRPC.markWantRead(id: id)
            pendingSync = false
            lastError = nil
        } catch {
            lastError = error.localizedDescription
            pendingSync = true
        }
    }

    func markDeletedByMe(_ id: UUID) async {
        do {
            try await KKRPC.softDeleteWant(id: id)
            if let idx = notes.firstIndex(where: { $0.id == id }) {
                notes[idx].deletedByMe = true
            }
            pendingSync = false
            lastError = nil
            await refreshFromServer()
        } catch {
            lastError = error.localizedDescription
            pendingSync = true
        }
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
    struct Snapshot: Codable, Equatable {
        var period: String
        var used: Int
        var remaining: Int { max(0, KKAIQuota.monthlyCap - used) }
        var isLocked: Bool { used >= KKAIQuota.monthlyCap }
    }

    @Published private(set) var snapshot = Snapshot(period: "", used: 0)
    @Published private(set) var pendingConsume = false
    @Published var lastNote: String?

    struct ConsumeOutcome {
        var ok: Bool
        var message: String
    }

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
            lastNote = "今個月 \(KKAIQuota.monthlyCap) 次用完。"
            return false
        }
        snapshot.used += 1
        pendingConsume = true
        lastNote = nil
        persist()
        return true
    }

    func refreshFromServer() async {
        if UITesting.blocksNetwork { return }
        do {
            let usage = try await KKRPC.aiUsage()
            snapshot = Snapshot(period: usage.period_ym, used: usage.used)
            pendingConsume = false
            lastNote = nil
            persist()
        } catch {
            lastNote = error.localizedDescription
        }
    }

    /// Server is the quota source. Gemini Edge may still return status stub.
    func consumeOnServer(userText: String, memories: [KKRPC.AIMemoryInput]) async -> ConsumeOutcome {
        let text = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !memories.isEmpty else {
            lastNote = "AI 只處理你打嘅字同記憶空間項目。"
            return ConsumeOutcome(ok: false, message: lastNote ?? "")
        }
        do {
            let result = try await KKRPC.consumeAI(userText: text, memories: memories)
            if let used = result.used {
                snapshot = Snapshot(period: result.period_ym ?? snapshot.period, used: used)
                persist()
            }
            pendingConsume = false
            lastNote = nil
            let stub = result.result?.status == "stub"
            let note = result.result?.note ?? ""
            let message = stub
                ? "次數已扣。Gemini Edge 未接上。\(note)"
                : (note.isEmpty ? "已提交。" : note)
            return ConsumeOutcome(ok: true, message: message)
        } catch {
            let raw = error.localizedDescription
            if raw.contains("ai_quota_exhausted") {
                snapshot = Snapshot(period: snapshot.period, used: KKAIQuota.monthlyCap)
                persist()
                lastNote = "今個月 \(KKAIQuota.monthlyCap) 次用完。"
            } else {
                lastNote = raw
            }
            return ConsumeOutcome(ok: false, message: lastNote ?? raw)
        }
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
    @Published private(set) var stylePack: String = "經典"
    @Published var capMessage: String?
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

    func refreshFromServer() async {
        if UITesting.blocksNetwork { return }
        do {
            let prefs = try await KKRPC.kaomojiPrefs()
            if prefs.exists == true {
                quick = Array(prefs.quick_react.prefix(Self.quickCap))
                if let pack = prefs.style_pack, !pack.isEmpty {
                    stylePack = pack
                }
                pendingCloudSync = false
                persist()
            }
            capMessage = nil
        } catch {
            capMessage = error.localizedDescription
        }
    }

    func toggleQuick(_ kao: String) async {
        if UITesting.blocksNetwork {
            capMessage = "UI test fixture does not save kaomoji prefs."
            return
        }
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
        do {
            let saved = try await KKRPC.setKaomojiPrefs(quick: quick, stylePack: stylePack)
            quick = Array(saved.quick_react.prefix(Self.quickCap))
            if let pack = saved.style_pack, !pack.isEmpty { stylePack = pack }
            pendingCloudSync = false
            capMessage = nil
            persist()
        } catch {
            pendingCloudSync = true
            capMessage = error.localizedDescription
        }
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
