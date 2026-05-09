import Foundation
import Combine
import CryptoKit
import Supabase

// Phase 6 v0.6.x — single E2EE store backing date-card history (v0.6.0),
// gratitude journal (v0.6.1), and quiz answers (v0.6.2).
//
// All three live in one table, distinguished by the encrypted payload's
// `kind` field. Adding new kinds doesn't need a migration.

struct PlayHistoryPayload: Codable, Equatable {
    var v: Int = 1
    var kind: Kind
    /// For .dateCard: the static catalog id we recorded as done.
    var cardId: Int?
    /// For .dateCard / quiz / journal / district: free-text reflection.
    var text: String?
    /// For .journal: which day this entry belongs to ("yyyy-MM-dd").
    var dayISO: String?
    /// For .quizAnswer: which question.
    var questionId: Int?
    /// v1.1.0 (.district) — which Hong Kong district this entry is for.
    /// Stable 2-char code, e.g. "CW" for 中西區. Null on non-district kinds.
    var districtCode: String?
    /// v1.3.0 (.mtrStation) — official 3-letter MTR station code, e.g.
    /// "ADM" for 金鐘. Null on non-MTR kinds.
    var mtrStationCode: String?
    /// Timestamp the user picked / answered / journaled.
    var atISO: String

    enum Kind: String, Codable, Equatable {
        case dateCard = "date_card"
        case journal
        case quizAnswer = "quiz_answer"
        /// v1.1.0 — 18 區日記. One row per district visit.
        case district
        /// v1.3.0 — MTR 站日記. One row per station visit.
        case mtrStation = "mtr_station"
    }
}

@MainActor
final class PlayHistoryService: ObservableObject {

    struct DecryptedItem: Identifiable, Equatable {
        let id: UUID
        let senderId: UUID
        let payload: PlayHistoryPayload
        let createdAt: Date
    }

    @Published private(set) var items: [DecryptedItem] = []
    @Published private(set) var isLoading = false
    @Published var lastError: String?

    private let crypto: CryptoService
    private var pollTask: Task<Void, Never>?
    private var realtimeTask: Task<Void, Never>?
    private var coupleId: UUID?

    init(crypto: CryptoService) { self.crypto = crypto }

    // MARK: - Lifecycle

    func start(coupleId: UUID) {
        if self.coupleId == coupleId, realtimeTask != nil { return }
        self.coupleId = coupleId
        pollTask?.cancel(); realtimeTask?.cancel()
        pollTask = Task { [weak self] in await self?.fetchOnce() }
        realtimeTask = Task { [weak self] in
            await self?.runRealtimeLoop(coupleId: coupleId)
        }
    }

    func stop() {
        pollTask?.cancel(); pollTask = nil
        realtimeTask?.cancel(); realtimeTask = nil
    }

    // MARK: - Add

    func add(payload: PlayHistoryPayload, senderId: UUID) async {
        guard let coupleId else { return }
        do {
            let cipher = try crypto.seal(payload)
            let row = OutgoingRow(couple_id: coupleId,
                                  sender_id: senderId,
                                  ciphertext_b64: cipher)
            try await SB.client.from("play_history").insert(row).execute()
            await fetchOnce()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Delete

    func delete(_ item: DecryptedItem) async {
        do {
            try await SB.client
                .from("play_history")
                .delete()
                .eq("id", value: item.id)
                .execute()
            items.removeAll { $0.id == item.id }
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Convenience accessors

    /// Records a date-card as done. v0.6.0 entry point from CardDeckView.
    func recordDateCard(cardId: Int, reflection: String?, senderId: UUID) async {
        let payload = PlayHistoryPayload(
            kind: .dateCard,
            cardId: cardId,
            text: reflection,
            dayISO: nil,
            questionId: nil,
            atISO: ISO8601DateFormatter().string(from: Date())
        )
        await add(payload: payload, senderId: senderId)
    }

    /// All recorded date-card history. Most recent first.
    var dateCardHistory: [DecryptedItem] {
        items
            .filter { $0.payload.kind == .dateCard }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Number of times a particular card has been recorded as done.
    func dateCardDoneCount(_ cardId: Int) -> Int {
        items.filter { $0.payload.kind == .dateCard && $0.payload.cardId == cardId }.count
    }

    /// All journal entries, newest first.
    var journalEntries: [DecryptedItem] {
        items
            .filter { $0.payload.kind == .journal }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Returns true if the user (sender) has already journaled today.
    /// Used to gate the "1 entry per day" rule on the client.
    func hasJournaledToday(senderId: UUID) -> Bool {
        let todayISO = LocalDate.string(from: Date())
        return items.contains { item in
            item.payload.kind == .journal
            && item.senderId == senderId
            && item.payload.dayISO == todayISO
        }
    }

    // MARK: - Districts (v1.1.0)

    /// Records a district visit. One row per visit; districts can be visited
    /// multiple times — the UI just cares whether ANY entry exists for the
    /// code.
    func recordDistrict(code: String, reflection: String?, senderId: UUID) async {
        let payload = PlayHistoryPayload(
            kind: .district,
            text: reflection,
            districtCode: code,
            atISO: ISO8601DateFormatter().string(from: Date())
        )
        await add(payload: payload, senderId: senderId)
    }

    /// All recorded district entries, newest first.
    var districtHistory: [DecryptedItem] {
        items
            .filter { $0.payload.kind == .district }
            .sorted { $0.createdAt > $1.createdAt }
    }

    /// Set of district codes the couple has visited at least once.
    var visitedDistrictCodes: Set<String> {
        Set(districtHistory.compactMap(\.payload.districtCode))
    }

    /// Most recent entry for a given district, if any.
    func latestEntry(forDistrict code: String) -> DecryptedItem? {
        districtHistory.first { $0.payload.districtCode == code }
    }

    // MARK: - MTR stations (v1.3.0)

    func recordMtrStation(code: String, reflection: String?, senderId: UUID) async {
        let payload = PlayHistoryPayload(
            kind: .mtrStation,
            text: reflection,
            mtrStationCode: code,
            atISO: ISO8601DateFormatter().string(from: Date())
        )
        await add(payload: payload, senderId: senderId)
    }

    var mtrHistory: [DecryptedItem] {
        items
            .filter { $0.payload.kind == .mtrStation }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var visitedMtrCodes: Set<String> {
        Set(mtrHistory.compactMap(\.payload.mtrStationCode))
    }

    func latestEntry(forMtr code: String) -> DecryptedItem? {
        mtrHistory.first { $0.payload.mtrStationCode == code }
    }

    // MARK: - Fetch

    private func fetchOnce() async {
        guard let coupleId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [IncomingRow] = try await SB.client
                .from("play_history")
                .select()
                .eq("couple_id", value: coupleId)
                .order("created_at", ascending: false)
                .limit(500)
                .execute()
                .value
            self.items = rows.compactMap { row in
                guard let payload: PlayHistoryPayload = try? crypto.openTyped(row.ciphertext_b64) else {
                    return nil
                }
                return DecryptedItem(id: row.id,
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
        let channel = SB.client.channel("play_history-\(coupleId.uuidString)")
        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public", table: "play_history",
            filter: "couple_id=eq.\(coupleId.uuidString.lowercased())"
        )
        let deletes = channel.postgresChange(
            DeleteAction.self,
            schema: "public", table: "play_history",
            filter: "couple_id=eq.\(coupleId.uuidString.lowercased())"
        )
        do {
            try await channel.subscribeWithError()
        } catch {
            lastError = "play_history realtime: \(error.localizedDescription)"
            return
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
}
