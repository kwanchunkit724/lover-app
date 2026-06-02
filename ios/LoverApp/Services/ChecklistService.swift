import Foundation
import Combine
import Supabase

// v1.6.5 — shared quick checklist (short-term memory). Item text is E2EE
// (sealed as a ChatPayload.text with the couple chat key, reusing the same
// crypto as messages); `done` is a plaintext column toggled without decrypt.
// Realtime via the proven postgres_changes path.
struct ChecklistItem: Identifiable, Equatable {
    let id: UUID
    let text: String
    let done: Bool
    let senderId: UUID
    let createdAt: Date
}

@MainActor
final class ChecklistService: ObservableObject {

    @Published private(set) var items: [ChecklistItem] = []
    /// Surfaced so the panel can show why an add/toggle failed instead of the
    /// "+ does nothing" symptom.
    @Published var lastError: String?

    /// Count of not-yet-done items — drives the header badge.
    var openCount: Int { items.filter { !$0.done }.count }

    private let crypto: CryptoService
    private var coupleId: UUID?
    private var meId: UUID?
    private var channel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?

    init(crypto: CryptoService) { self.crypto = crypto }

    // MARK: - Lifecycle

    func start(coupleId: UUID) {
        if self.coupleId == coupleId, channel != nil { return }
        stop()
        self.coupleId = coupleId
        self.meId = SB.client.auth.currentUser?.id
        realtimeTask = Task { [weak self] in await self?.bootstrap(coupleId: coupleId) }
    }

    func stop() {
        realtimeTask?.cancel(); realtimeTask = nil
        if let ch = channel { channel = nil; Task { await ch.unsubscribe() } }
        coupleId = nil; meId = nil; items = []
    }

    func pause() { stop() }
    func resume(coupleId: UUID) { start(coupleId: coupleId) }

    // MARK: - Mutations

    func add(_ text: String) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard let coupleId, let me = meId else {
            lastError = "未準備好（請重開 app 再試）"
            return
        }
        struct Row: Encodable { let couple_id: UUID; let sender_id: UUID; let ciphertext_b64: String }
        do {
            let cipher = try crypto.seal(ChatPayload.text(trimmed))
            try await SB.client.from("checklist_items")
                .insert(Row(couple_id: coupleId, sender_id: me, ciphertext_b64: cipher))
                .execute()
            await fetchOnce()
        } catch {
            lastError = "加入失敗：\(error.localizedDescription)"
        }
    }

    func toggle(_ item: ChecklistItem) async {
        struct Patch: Encodable { let done: Bool }
        do {
            try await SB.client.from("checklist_items")
                .update(Patch(done: !item.done)).eq("id", value: item.id).execute()
            await fetchOnce()
        } catch { }
    }

    func remove(_ item: ChecklistItem) async {
        do {
            try await SB.client.from("checklist_items").delete().eq("id", value: item.id).execute()
            await fetchOnce()
        } catch { }
    }

    /// Clear all completed items.
    func clearDone() async {
        guard let coupleId else { return }
        do {
            try await SB.client.from("checklist_items").delete()
                .eq("couple_id", value: coupleId).eq("done", value: true).execute()
            await fetchOnce()
        } catch { }
    }

    // MARK: - Internals

    private func bootstrap(coupleId: UUID) async {
        await fetchOnce()
        let ch = SB.client.channel("checklist-\(coupleId.uuidString)")
        self.channel = ch
        let filter = "couple_id=eq.\(coupleId.uuidString.lowercased())"
        let inserts = ch.postgresChange(InsertAction.self, schema: "public",
                                        table: "checklist_items", filter: filter)
        let updates = ch.postgresChange(UpdateAction.self, schema: "public",
                                        table: "checklist_items", filter: filter)
        let deletes = ch.postgresChange(DeleteAction.self, schema: "public",
                                        table: "checklist_items")
        do { try await ch.subscribeWithError() } catch { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                for await _ in inserts { if Task.isCancelled { break }; await self?.fetchOnce() }
            }
            group.addTask { [weak self] in
                for await _ in updates { if Task.isCancelled { break }; await self?.fetchOnce() }
            }
            group.addTask { [weak self] in
                for await _ in deletes { if Task.isCancelled { break }; await self?.fetchOnce() }
            }
        }
    }

    private func fetchOnce() async {
        guard let coupleId else { return }
        do {
            let rows: [Row] = try await SB.client.from("checklist_items")
                .select("id,sender_id,ciphertext_b64,done,created_at")
                .eq("couple_id", value: coupleId)
                .order("created_at", ascending: true)
                .execute().value
            self.items = rows.map { r in
                let text = (try? crypto.open(r.ciphertext_b64))?.text ?? "(無法解密)"
                return ChecklistItem(id: r.id, text: text, done: r.done,
                                     senderId: r.sender_id, createdAt: r.created_at)
            }
        } catch { }
    }

    private struct Row: Decodable {
        let id: UUID
        let sender_id: UUID
        let ciphertext_b64: String
        let done: Bool
        let created_at: Date
    }
}
