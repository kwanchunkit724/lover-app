import Foundation
import Combine
import Supabase

// Phase 4a/5 — fetch + send + decrypt messages.
// Realtime + 5s polling fallback. Messages now support: reply, reactions,
// soft-delete (unsend), vanish mode (24h TTL), read receipts.
//
// Backend schema in supabase/migrations/0013_chat_ig_features.sql.

@MainActor
final class ChatService: ObservableObject {

    struct Reaction: Hashable {
        let userId: UUID
        let emoji: String
    }

    struct DecryptedMessage: Identifiable, Equatable {
        let id: UUID
        let senderId: UUID
        let payload: ChatPayload
        let createdAt: Date
        let decryptionFailed: Bool
        var replyToId: UUID?
        var editedAt: Date?
        var deletedAt: Date?
        var expiresAt: Date?
        var readAt: Date?
        var reactions: [Reaction] = []

        var isDeleted: Bool { deletedAt != nil }
        var isEdited: Bool  { editedAt  != nil }

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
    @Published private(set) var vanishMode: Bool = false
    @Published var lastError: String?

    private let crypto: CryptoService
    private let media: MediaService
    private var pollTask: Task<Void, Never>?
    private var realtimeTask: Task<Void, Never>?
    private var reactionsTask: Task<Void, Never>?
    private var coupleId: UUID?

    init(crypto: CryptoService) {
        self.crypto = crypto
        self.media = MediaService(crypto: crypto)
    }

    var coupleIdValue: UUID? { coupleId }
    var mediaService: MediaService { media }

    // MARK: - Lifecycle

    func start(coupleId: UUID) {
        if self.coupleId == coupleId, realtimeTask != nil { return }
        self.coupleId = coupleId
        pollTask?.cancel()
        realtimeTask?.cancel()
        reactionsTask?.cancel()
        pollTask = Task { [weak self] in
            await self?.runPollLoop()
        }
        realtimeTask = Task { [weak self] in
            await self?.runRealtimeLoop(coupleId: coupleId)
        }
        Task { await self.refreshVanishMode() }
    }

    func stop() {
        pollTask?.cancel(); pollTask = nil
        realtimeTask?.cancel(); realtimeTask = nil
        reactionsTask?.cancel(); reactionsTask = nil
    }

    // MARK: - Send

    func sendText(_ text: String, senderId: UUID, replyToId: UUID? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let coupleId else { return }
        do {
            let payload = ChatPayload.text(trimmed)
            let cipher = try crypto.seal(payload)
            let row = OutgoingRow(couple_id: coupleId,
                                  sender_id: senderId,
                                  ciphertext_b64: cipher,
                                  reply_to_id: replyToId)
            try await SB.client.from("messages").insert(row).execute()
            await fetchOnce()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func sendPhoto(data: Data, caption: String?, senderId: UUID, replyToId: UUID? = nil) async {
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
                                  ciphertext_b64: cipher,
                                  reply_to_id: replyToId)
            try await SB.client.from("messages").insert(row).execute()
            await fetchOnce()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func sendVoice(data: Data, durationSec: Int, senderId: UUID, replyToId: UUID? = nil) async {
        guard let coupleId else { return }
        do {
            let path = try await media.encryptAndUpload(data: data, coupleId: coupleId)
            let durationStr = String(format: "0:%02d", durationSec)
            let payload = ChatPayload(
                kind: .voice,
                text: durationStr,
                mediaHandle: path,
                sentAt: Date()
            )
            let cipher = try crypto.seal(payload)
            let row = OutgoingRow(couple_id: coupleId,
                                  sender_id: senderId,
                                  ciphertext_b64: cipher,
                                  reply_to_id: replyToId)
            try await SB.client.from("messages").insert(row).execute()
            await fetchOnce()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Edit / Unsend / Read

    /// Replace ciphertext of an existing message. Sender-only (RLS enforced).
    func editText(messageId: UUID, newText: String) async {
        let trimmed = newText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let payload = ChatPayload.text(trimmed)
            let cipher = try crypto.seal(payload)
            try await SB.client.from("messages")
                .update(EditPayload(ciphertext_b64: cipher, edited_at: Date()))
                .eq("id", value: messageId)
                .execute()
            await fetchOnce()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Soft-delete a message (sender-only). Bubble shows "已撤回" placeholder.
    func unsend(messageId: UUID) async {
        do {
            try await SB.client.from("messages")
                .update(UnsendPayload(deleted_at: Date()))
                .eq("id", value: messageId)
                .execute()
            await fetchOnce()
        } catch {
            lastError = error.localizedDescription
        }
    }

    /// Recipient calls when bubble appears. Idempotent server-side via RPC.
    func markRead(messageId: UUID) async {
        struct Args: Encodable { let p_message_id: UUID }
        do {
            _ = try await SB.client.rpc("mark_message_read",
                                        params: Args(p_message_id: messageId))
                .execute()
        } catch {
            // Silent — read receipts are best-effort.
        }
    }

    // MARK: - Reactions

    func addReaction(messageId: UUID, emoji: String, userId: UUID) async {
        do {
            try await SB.client.from("message_reactions")
                .insert(ReactionRow(message_id: messageId,
                                    user_id: userId,
                                    emoji: emoji))
                .execute()
            await fetchReactions()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func removeReaction(messageId: UUID, emoji: String, userId: UUID) async {
        do {
            try await SB.client.from("message_reactions")
                .delete()
                .eq("message_id", value: messageId)
                .eq("user_id", value: userId)
                .eq("emoji", value: emoji)
                .execute()
            await fetchReactions()
        } catch {
            lastError = error.localizedDescription
        }
    }

    // MARK: - Vanish mode

    func setVanishMode(enabled: Bool) async {
        struct Args: Encodable { let p_enabled: Bool }
        do {
            _ = try await SB.client.rpc("set_vanish_mode",
                                        params: Args(p_enabled: enabled))
                .execute()
            self.vanishMode = enabled
        } catch {
            lastError = error.localizedDescription
        }
    }

    private func refreshVanishMode() async {
        guard let coupleId else { return }
        do {
            let row: VanishRow = try await SB.client.from("couples")
                .select("vanish_mode")
                .eq("id", value: coupleId)
                .single()
                .execute()
                .value
            self.vanishMode = row.vanish_mode
        } catch {
            // Silent
        }
    }

    // MARK: - Polling

    private func runPollLoop() async {
        await fetchOnce()
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            if Task.isCancelled { break }
            await fetchOnce()
        }
    }

    // MARK: - Realtime

    private func runRealtimeLoop(coupleId: UUID) async {
        let channel = SB.client.channel("messages-\(coupleId.uuidString)")
        let inserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "couple_id=eq.\(coupleId.uuidString.lowercased())"
        )
        let updates = channel.postgresChange(
            UpdateAction.self,
            schema: "public",
            table: "messages",
            filter: "couple_id=eq.\(coupleId.uuidString.lowercased())"
        )
        let reactionInserts = channel.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "message_reactions"
        )
        let reactionDeletes = channel.postgresChange(
            DeleteAction.self,
            schema: "public",
            table: "message_reactions"
        )
        do {
            try await channel.subscribeWithError()
        } catch {
            lastError = "realtime: \(error.localizedDescription)"
            return
        }

        // Fan out into three concurrent listeners.
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                for await _ in inserts {
                    if Task.isCancelled { break }
                    await self?.fetchOnce()
                }
            }
            group.addTask { [weak self] in
                for await _ in updates {
                    if Task.isCancelled { break }
                    await self?.fetchOnce()
                }
            }
            group.addTask { [weak self] in
                for await _ in reactionInserts {
                    if Task.isCancelled { break }
                    await self?.fetchReactions()
                }
            }
            group.addTask { [weak self] in
                for await _ in reactionDeletes {
                    if Task.isCancelled { break }
                    await self?.fetchReactions()
                }
            }
        }
    }

    private func fetchOnce() async {
        guard let coupleId else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            // Order DESC + limit 500 = newest 500. Reverse below for UI
            // (ascending). Old code used ascending + limit 500 which silently
            // dropped newest messages once couple exceeded 500 total.
            let rowsDesc: [IncomingRow] = try await SB.client
                .from("messages")
                .select()
                .eq("couple_id", value: coupleId)
                .order("created_at", ascending: false)
                .limit(500)
                .execute()
                .value
            let rows = Array(rowsDesc.reversed())

            let now = Date()
            var decoded: [DecryptedMessage] = rows.compactMap { row in
                // Filter expired vanish-mode messages client-side. Server still
                // holds them until pg_cron sweep (separate concern).
                if let exp = row.expires_at, exp < now { return nil }

                if row.deleted_at != nil {
                    // Soft-deleted: keep placeholder so reply chains stay intact.
                    return DecryptedMessage(
                        id: row.id,
                        senderId: row.sender_id,
                        payload: ChatPayload(kind: .text,
                                             text: nil,
                                             mediaHandle: nil,
                                             sentAt: row.created_at),
                        createdAt: row.created_at,
                        decryptionFailed: false,
                        replyToId: row.reply_to_id,
                        editedAt: row.edited_at,
                        deletedAt: row.deleted_at,
                        expiresAt: row.expires_at,
                        readAt: row.read_at
                    )
                }

                if let payload = try? crypto.open(row.ciphertext_b64) {
                    return DecryptedMessage(
                        id: row.id,
                        senderId: row.sender_id,
                        payload: payload,
                        createdAt: row.created_at,
                        decryptionFailed: false,
                        replyToId: row.reply_to_id,
                        editedAt: row.edited_at,
                        deletedAt: row.deleted_at,
                        expiresAt: row.expires_at,
                        readAt: row.read_at
                    )
                } else {
                    var failed = DecryptedMessage.failed(id: row.id,
                                                         senderId: row.sender_id,
                                                         createdAt: row.created_at)
                    failed.replyToId = row.reply_to_id
                    failed.editedAt  = row.edited_at
                    failed.deletedAt = row.deleted_at
                    failed.expiresAt = row.expires_at
                    failed.readAt    = row.read_at
                    return failed
                }
            }

            // Merge cached reactions into the new list (in case the message
            // refresh races ahead of the reaction refresh).
            let cached = Dictionary(uniqueKeysWithValues:
                self.messages.map { ($0.id, $0.reactions) })
            for i in decoded.indices {
                if let existing = cached[decoded[i].id] {
                    decoded[i].reactions = existing
                }
            }

            self.messages = decoded
        } catch {
            lastError = error.localizedDescription
        }

        await fetchReactions()
    }

    private func fetchReactions() async {
        guard let coupleId else { return }
        do {
            let ids = self.messages.map { $0.id }
            guard !ids.isEmpty else { return }
            let rows: [ReactionRow] = try await SB.client
                .from("message_reactions")
                .select("message_id,user_id,emoji,created_at")
                .in("message_id", value: ids)
                .execute()
                .value
            let grouped = Dictionary(grouping: rows, by: \.message_id)
            for i in self.messages.indices {
                let mId = self.messages[i].id
                self.messages[i].reactions = grouped[mId]?.map {
                    Reaction(userId: $0.user_id, emoji: $0.emoji)
                } ?? []
            }
            _ = coupleId
        } catch {
            // Silent — reactions are non-critical.
        }
    }

    // MARK: - Wire types

    private struct OutgoingRow: Encodable {
        let couple_id: UUID
        let sender_id: UUID
        let ciphertext_b64: String
        let reply_to_id: UUID?
    }

    private struct EditPayload: Encodable {
        let ciphertext_b64: String
        let edited_at: Date
    }

    private struct UnsendPayload: Encodable {
        let deleted_at: Date
    }

    private struct ReactionRow: Codable {
        let message_id: UUID
        let user_id: UUID
        let emoji: String
        var created_at: Date? = nil
    }

    private struct VanishRow: Decodable {
        let vanish_mode: Bool
    }

    private struct IncomingRow: Decodable {
        let id: UUID
        let couple_id: UUID
        let sender_id: UUID
        let ciphertext_b64: String
        let created_at: Date
        let reply_to_id: UUID?
        let edited_at:   Date?
        let deleted_at:  Date?
        let expires_at:  Date?
        let read_at:     Date?

        enum CodingKeys: String, CodingKey {
            case id, couple_id, sender_id, ciphertext_b64, created_at,
                 reply_to_id, edited_at, deleted_at, expires_at, read_at
        }
    }
}
