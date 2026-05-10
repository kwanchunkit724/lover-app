import Foundation
import Combine
import CryptoKit
import Supabase

// Phase 5 v0.5.1 — E2EE shared timetable entries.
//
// Mirrors AnniversaryService. Entries are individual moments / plans on the
// shared calendar (past + upcoming). Either partner can add or delete; both
// see the same list via Realtime.
//
// Plaintext shape = Entry struct minus the runtime-computed media counts
// (those are placeholders for future Phase 6 media wiring).

struct EntryPayload: Codable, Equatable {
    var v: Int = 1
    var title: String
    var dateISO: String          // "yyyy-MM-dd"
    var time: String?            // "HH:mm"
    var location: String?
    var proposedBy: String       // sender's user id, "kit"-style mock id, or partner's id
    var who: String              // "both" / "mine" / "theirs"
    var tag: String              // matches Entry.Tag.rawValue
    var isSpecial: Bool
    var notes: String?
    var kaomoji: String?
    var photoCount: Int = 0      // future Phase 6 — count of attached photos
    var voiceCount: Int = 0
    var messageCount: Int = 0
    var reflection: ReflectionPayload?
    /// v1.2.0 — encrypted-storage path for the entry's cover photo, if the
    /// user attached one when creating the event. Format mirrors chat
    /// media: "couple-{coupleId}/{uuid}.bin". Past entries with a cover
    /// render as a real photo cell on the calendar grid; without one they
    /// fall back to the deterministic-hash gradient placeholder.
    var coverHandle: String?

    struct ReflectionPayload: Codable, Equatable {
        var from: String
        var text: String
        var kaomoji: String?
    }
}

@MainActor
final class EntryService: ObservableObject {

    struct DecryptedEntry: Identifiable, Equatable {
        let id: UUID
        let senderId: UUID
        let payload: EntryPayload
        let createdAt: Date
    }

    @Published private(set) var items: [DecryptedEntry] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private let crypto: CryptoService
    private let media: MediaService
    private var pollTask: Task<Void, Never>?
    private var realtimeTask: Task<Void, Never>?
    private var coupleId: UUID?

    init(crypto: CryptoService) {
        self.crypto = crypto
        self.media = MediaService(crypto: crypto)
    }

    // MARK: - Lifecycle

    func start(coupleId: UUID) {
        if self.coupleId == coupleId, realtimeTask != nil { return }
        self.coupleId = coupleId
        pollTask?.cancel(); realtimeTask?.cancel()
        // v1.4.2 — was a one-shot fetch; now a 10-second poll loop so
        // entries stay fresh even if Realtime is between reconnects.
        pollTask = Task { [weak self] in
            await self?.fetchOnce()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if Task.isCancelled { break }
                await self?.fetchOnce()
            }
        }
        realtimeTask = Task { [weak self] in
            await self?.runRealtimeLoop(coupleId: coupleId)
        }
    }

    func stop() {
        pollTask?.cancel(); pollTask = nil
        realtimeTask?.cancel(); realtimeTask = nil
    }

    // MARK: - Add

    func add(payload: EntryPayload, senderId: UUID) async {
        await add(payload: payload, coverData: nil, senderId: senderId)
    }

    /// v1.2.0 — overload that uploads an attached cover photo before
    /// inserting. v1.3.1 fix: if the photo upload fails (e.g. chat key
    /// not yet ready), still insert the entry without a cover instead of
    /// losing the whole record. Earlier the photo error short-circuited
    /// the whole do-block so the entry never made it into the DB and the
    /// user saw "saved" UI but nothing showed up on the calendar.
    func add(payload: EntryPayload, coverData: Data?, senderId: UUID) async {
        guard let coupleId else { return }
        var p = payload
        if let coverData {
            do {
                p.coverHandle = try await media.encryptAndUpload(
                    data: coverData, coupleId: coupleId)
                p.photoCount = 1
            } catch {
                lastError = "封面相片 upload 失敗（entry 仍會儲存）：\(error.localizedDescription)"
                p.coverHandle = nil
                p.photoCount = 0
            }
        }
        do {
            let cipher = try crypto.seal(p)
            let row = OutgoingRow(couple_id: coupleId,
                                  sender_id: senderId,
                                  ciphertext_b64: cipher)
            try await SB.client.from("entries").insert(row).execute()
            await fetchOnce()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Expose decrypted media download for the calendar grid / detail view.
    func loadCoverImage(handle: String) async throws -> Data {
        try await media.downloadAndDecrypt(path: handle)
    }

    // MARK: - Delete

    func delete(_ item: DecryptedEntry) async {
        do {
            try await SB.client
                .from("entries")
                .delete()
                .eq("id", value: item.id)
                .execute()
            items.removeAll { $0.id == item.id }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Fetch

    private func fetchOnce() async {
        guard let coupleId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [IncomingRow] = try await SB.client
                .from("entries")
                .select()
                .eq("couple_id", value: coupleId)
                .order("created_at", ascending: true)
                .execute()
                .value
            self.items = rows.compactMap { row in
                guard let payload: EntryPayload = try? crypto.openTyped(row.ciphertext_b64) else {
                    return nil
                }
                return DecryptedEntry(id: row.id,
                                       senderId: row.sender_id,
                                       payload: payload,
                                       createdAt: row.created_at)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Realtime

    private func runRealtimeLoop(coupleId: UUID) async {
        // v1.4.2 — auto-reconnect outer loop. Earlier this returned on
        // first failure ("Maximum retry attempts reached"), leaving the
        // realtime channel dead until app restart. Now we keep retrying
        // with exponential backoff (capped at 60 s). Polling every 5 s
        // is the immediate fallback so the user sees fresh data even
        // while we're between reconnect attempts.
        var delay: UInt64 = 2_000_000_000   // 2 s, doubles up to 60 s
        while !Task.isCancelled {
        let channel = SB.client.channel("entries-\(coupleId.uuidString)")
        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public", table: "entries",
            filter: "couple_id=eq.\(coupleId.uuidString.lowercased())"
        )
        let deletes = channel.postgresChange(
            DeleteAction.self,
            schema: "public", table: "entries",
            filter: "couple_id=eq.\(coupleId.uuidString.lowercased())"
        )
        do {
            try await channel.subscribeWithError()
            // Subscribe succeeded → reset backoff for the next failure.
            delay = 2_000_000_000
        } catch {
            // v1.4.2 — don't surface every transient realtime hiccup;
            // polling already covers the data path. Sleep + retry.
            try? await Task.sleep(nanoseconds: delay)
            if delay < 60_000_000_000 { delay *= 2 }
            continue
        }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                for await _ in inserts {
                    if Task.isCancelled { break }
                    await self?.fetchOnce()
                }
            }
            group.addTask { [weak self] in
                for await _ in deletes {
                    if Task.isCancelled { break }
                    await self?.fetchOnce()
                }
            }
        }
        // Channel ended (cancelled or dropped) — outer while loop
        // re-subscribes after a short pause.
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    // MARK: - Wire types

    private struct OutgoingRow: Encodable {
        let couple_id: UUID
        let sender_id: UUID
        let ciphertext_b64: String
    }

    private struct IncomingRow: Decodable {
        let id: UUID
        let couple_id: UUID
        let sender_id: UUID
        let ciphertext_b64: String
        let created_at: Date

        enum CodingKeys: String, CodingKey {
            case id, couple_id, sender_id, ciphertext_b64, created_at
        }
    }

    // MARK: - View-model bridge

    /// Maps DecryptedEntry → the legacy Entry struct so existing TimeView /
    /// MonthGrid / EntryDetailView code keeps rendering without rewrite.
    var asEntries: [Entry] {
        items.map { d in
            Entry(
                id: d.id.uuidString,
                date: d.payload.dateISO,
                time: d.payload.time,
                title: d.payload.title,
                location: d.payload.location,
                proposedBy: d.payload.proposedBy,
                who: Entry.Who(rawValue: d.payload.who) ?? .both,
                tag: Entry.Tag(rawValue: d.payload.tag) ?? .outing,
                isSpecial: d.payload.isSpecial,
                notes: d.payload.notes,
                cover: d.payload.coverHandle,
                photos: d.payload.photoCount,
                voiceClips: d.payload.voiceCount,
                messages: d.payload.messageCount,
                kaomoji: d.payload.kaomoji,
                reflection: d.payload.reflection.map {
                    Reflection(from: $0.from, text: $0.text, kaomoji: $0.kaomoji)
                },
                onThisDay: false
            )
        }
    }
}
