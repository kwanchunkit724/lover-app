import Foundation
import Combine
import Supabase

// Phase 4a — fetch + send + decrypt messages.
// Polling instead of realtime for now (Phase 4b adds Supabase Realtime).
//
// Messages are insert-only. We keep a local @Published [DecryptedMessage]
// sorted oldest→newest that ChatView consumes 1:1.

@MainActor
final class ChatService: ObservableObject {

    struct DecryptedMessage: Identifiable, Equatable {
        let id: UUID
        let senderId: UUID
        let payload: ChatPayload
        let createdAt: Date
        let decryptionFailed: Bool

        static func failed(id: UUID, senderId: UUID, createdAt: Date) -> Self {
            DecryptedMessage(id: id, senderId: senderId,
                             payload: ChatPayload(kind: .text,
                                                  text: "(無法解密 — 可能對方換咗 device)",
                                                  mediaHandle: nil,
                                                  sentAt: createdAt),
                             createdAt: createdAt,
                             decryptionFailed: true)
        }
    }

    @Published private(set) var messages: [DecryptedMessage] = []
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

    var coupleIdValue: UUID? { coupleId }
    var mediaService: MediaService { media }

    // MARK: - Lifecycle

    /// Called when MainTabView appears AND the couple key is ready. Starts:
    /// - one-shot fetch of all existing messages
    /// - Supabase Realtime subscription for INSERTs (Phase 4b — instant push
    ///   to the UI without waiting for a poll tick)
    /// - 30-second fallback poll (in case the realtime channel disconnects)
    func start(coupleId: UUID) {
        if self.coupleId == coupleId, realtimeTask != nil { return }
        self.coupleId = coupleId
        pollTask?.cancel()
        realtimeTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.runPollLoop()
        }
        realtimeTask = Task { [weak self] in
            await self?.runRealtimeLoop(coupleId: coupleId)
        }
    }

    func stop() {
        pollTask?.cancel(); pollTask = nil
        realtimeTask?.cancel(); realtimeTask = nil
    }

    // MARK: - Send

    func sendText(_ text: String, senderId: UUID) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let coupleId else { return }
        do {
            let payload = ChatPayload.text(trimmed)
            let cipher = try crypto.seal(payload)
            let row = OutgoingRow(couple_id: coupleId,
                                  sender_id: senderId,
                                  ciphertext_b64: cipher)
            try await SB.client.from("messages").insert(row).execute()
            await fetchOnce()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Phase 4c — encrypt + upload photo bytes to Storage, then insert a
    /// chat message whose payload references the storage path.
    func sendPhoto(data: Data, caption: String?, senderId: UUID) async {
        guard let coupleId else { return }
        do {
            let path = try await media.encryptAndUpload(data: data, coupleId: coupleId)
            let payload = ChatPayload(
                kind: .photo,
                text: caption,
                mediaHandle: path,
                sentAt: Date()
            )
            let cipher = try crypto.seal(payload)
            let row = OutgoingRow(couple_id: coupleId,
                                  sender_id: senderId,
                                  ciphertext_b64: cipher)
            try await SB.client.from("messages").insert(row).execute()
            await fetchOnce()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Polling (fallback when realtime drops)

    private func runPollLoop() async {
        await fetchOnce()
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 30_000_000_000)   // 30s — slow fallback
            if Task.isCancelled { break }
            await fetchOnce()
        }
    }

    // MARK: - Realtime (Phase 4b)

    private func runRealtimeLoop(coupleId: UUID) async {
        let channel = SB.client.channel("messages-\(coupleId.uuidString)")
        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "couple_id=eq.\(coupleId.uuidString.lowercased())"
        )
        do {
            try await channel.subscribeWithError()
        } catch {
            // Subscription failed — poll loop is still running so chat stays
            // alive, just with 30s lag.
            lastError = "realtime: \(error.localizedDescription)"
            return
        }
        for await action in inserts {
            if Task.isCancelled { break }
            // The new row landed via realtime; refetch to pick it up so we
            // share the same decrypt path. Cheap because messages list is
            // small per couple.
            await fetchOnce()
            _ = action   // unused — refetch is simpler than decoding the change
        }
    }

    private func fetchOnce() async {
        guard let coupleId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            let rows: [IncomingRow] = try await SB.client
                .from("messages")
                .select()
                .eq("couple_id", value: coupleId)
                .order("created_at", ascending: true)
                .limit(500)
                .execute()
                .value
            self.messages = rows.map { row in
                if let payload = try? crypto.open(row.ciphertext_b64) {
                    return DecryptedMessage(id: row.id,
                                            senderId: row.sender_id,
                                            payload: payload,
                                            createdAt: row.created_at,
                                            decryptionFailed: false)
                } else {
                    return DecryptedMessage.failed(id: row.id,
                                                   senderId: row.sender_id,
                                                   createdAt: row.created_at)
                }
            }
        } catch {
            lastError = error.localizedDescription
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
