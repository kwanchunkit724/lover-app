import Foundation
import Combine
import CryptoKit
import Supabase

// Phase 5 v0.5.0 — E2EE shared anniversaries.
//
// Shape mirrors ChatService: fetch all rows for the couple, decrypt each
// via the chat key (same X25519 ECDH-derived AES-GCM key), expose a
// @Published [DecryptedAnniversary]. Add + delete go through standard
// Supabase insert/delete with RLS gating membership.

// JSON-encoded plaintext stored in anniversaries.ciphertext_b64.
struct AnniversaryPayload: Codable, Equatable {
    var v: Int = 1
    var title: String
    var baseDateISO: String       // "yyyy-MM-dd" (LocalDate)
    var recur: Recur
    var kaomoji: String?
    var emoji: String?
    var subtitle: String?

    enum Recur: String, Codable, Equatable { case yearly, monthly }
}

@MainActor
final class AnniversaryService: ObservableObject {

    struct DecryptedAnniversary: Identifiable, Equatable {
        let id: UUID
        let senderId: UUID
        let payload: AnniversaryPayload
        let createdAt: Date
    }

    @Published private(set) var items: [DecryptedAnniversary] = []
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
        pollTask = Task { [weak self] in
            await self?.fetchOnce()
            // No periodic poll — anniversaries change rarely. Realtime
            // subscribe handles the rare add/delete from partner.
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

    func add(payload: AnniversaryPayload, senderId: UUID) async {
        guard let coupleId else { return }
        do {
            let cipher = try crypto.seal(payload)
            let row = OutgoingRow(couple_id: coupleId,
                                  sender_id: senderId,
                                  ciphertext_b64: cipher)
            try await SB.client.from("anniversaries").insert(row).execute()
            await fetchOnce()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Delete

    func delete(_ item: DecryptedAnniversary) async {
        do {
            try await SB.client
                .from("anniversaries")
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
                .from("anniversaries")
                .select()
                .eq("couple_id", value: coupleId)
                .order("created_at", ascending: true)
                .execute()
                .value
            self.items = rows.compactMap { row in
                guard let payload: AnniversaryPayload = try? crypto.openTyped(row.ciphertext_b64) else {
                    return nil
                }
                return DecryptedAnniversary(id: row.id,
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
        let channel = SB.client.channel("anniversaries-\(coupleId.uuidString)")
        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "anniversaries",
            filter: "couple_id=eq.\(coupleId.uuidString.lowercased())"
        )
        let deletes = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "anniversaries",
            filter: "couple_id=eq.\(coupleId.uuidString.lowercased())"
        )
        do {
            try await channel.subscribeWithError()
        } catch {
            lastError = "anniversaries realtime: \(error.localizedDescription)"
            return
        }
        // Two AsyncSequences — fan-in via concurrent tasks.
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

// MARK: - CryptoService generic seal/open helpers

extension CryptoService {
    /// Generic seal — JSON-encode any Codable + AES-GCM. Mirrors `seal(ChatPayload)`
    /// but for arbitrary E2EE payload types in Phase 5.
    func seal<T: Encodable>(_ value: T) throws -> String {
        guard let key = chatKey else { throw CryptoError.notReady }
        let plaintext = try JSONEncoder.iso.encode(value)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw CryptoError.sealFailed }
        return combined.base64EncodedString()
    }

    func openTyped<T: Decodable>(_ ciphertextB64: String) throws -> T {
        guard let key = chatKey else { throw CryptoError.notReady }
        guard let combined = Data(base64Encoded: ciphertextB64) else {
            throw CryptoError.invalidBase64
        }
        let box = try AES.GCM.SealedBox(combined: combined)
        let plain = try AES.GCM.open(box, using: key)
        return try JSONDecoder.iso.decode(T.self, from: plain)
    }
}
