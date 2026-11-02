import Foundation
import Supabase

// Thin adapters for the live us-app `kk_*` RPCs.
// Chat ciphertext is never a parameter. Memory, 想你知道, and AI text are server-readable.
//
// TODO(kk-backend): schedule `kk_purge_expired_messages` on a 48h Edge/cron.
// The client calls it opportunistically; that is not a substitute for the job.
// TODO(kk-backend): 想你知道 09:00 HKT push is not wired. `remind` is stored only.
// TODO(kk-backend): Gemini Edge is not deployed. `kk_ai_consume_and_run` returns status "stub".

enum KKRPCError: Error {
    /// Refusing to send a mood whose third scalar is not U+6530. Do not substitute.
    case moodScalarMismatch
}

enum KKRPC {
    struct SetMoodArgs: Encodable {
        let p_mood: String
        let p_hkt_date: String
    }

    struct SetMoodResult: Decodable {
        let mood: String
        let hkt_date: String
    }

    struct AIMemoryInput: Encodable {
        let id: String
        let title: String
        let original_text: String
    }

    private struct AIPayload: Encodable {
        let user_text: String
        let memory_ids: [String]
        let memory_items: [AIMemoryInput]
    }

    private struct AIArgs: Encodable {
        let p_payload: AIPayload
    }

    struct AIUsage: Decodable {
        let period_ym: String
        let used: Int
        let remaining: Int
        let cap: Int
    }

    struct AIConsumeResult: Decodable {
        let period_ym: String?
        let used: Int?
        let remaining: Int?
        let result: Stub?
        struct Stub: Decodable {
            let status: String?
            let note: String?
        }
    }

    struct KaomojiPrefs: Decodable {
        let quick_react: [String]
        let style_pack: String?
        let exists: Bool?
    }

    struct MoodRow: Decodable {
        let mood: String?
        let mood_updated_at: String?
    }

    struct MemoryRow: Decodable {
        let id: UUID
        let title: String
        let original_text: String
        let category: String
        let note_summary: String
        let source_message_refs: [String]
        let photo_thumbs: [String]
        let attachment_markers: [String]
        let reminder_at: String?
        let created_at: String
    }

    struct WantRow: Decodable {
        let id: UUID
        let author_id: UUID
        let title: String?
        let body: String
        let deadline_at: String?
        let remind: Bool
        let deleted_by_a: Bool
        let deleted_by_b: Bool
        let created_at: String
    }

    struct WantRead: Decodable {
        let item_id: UUID
        let user_id: UUID
    }

    struct CoupleEnds: Decodable {
        let user_a_id: UUID
        let user_b_id: UUID
    }

    /// Sends `mood.label` unchanged. The tired label is only the U+6530 form.
    static func setDailyMood(_ mood: DailyMood, hktDate: String) async throws -> SetMoodResult {
        let label = mood.label
        guard DailyMoodLock.isAllowed(label) else { throw KKRPCError.moodScalarMismatch }
        if label == DailyMoodLock.moodTired {
            let scalars = DailyMoodLock.codepoints(of: label)
            guard scalars == [0x6709, 0x5572, 0x6530] else { throw KKRPCError.moodScalarMismatch }
            let third = Data(String(UnicodeScalar(0x6530)!).utf8)
            guard Array(third) == [0xe6, 0x94, 0xb0] else { throw KKRPCError.moodScalarMismatch }
        }
        let result: SetMoodResult = try await SB.client
            .rpc("kk_set_daily_mood", params: SetMoodArgs(p_mood: label, p_hkt_date: hktDate))
            .execute()
            .value
        return result
    }

    static func myMood(userId: UUID) async throws -> MoodRow? {
        let rows: [MoodRow] = try await SB.client
            .from("users")
            .select("mood,mood_updated_at")
            .eq("id", value: userId)
            .execute()
            .value
        return rows.first
    }

    static func listMemories() async throws -> [MemoryRow] {
        let rows: [MemoryRow] = try await SB.client
            .from("memory_items")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }

    static func createMemory(
        title: String,
        original: String,
        category: String,
        note: String,
        sourceIds: [String],
        photos: [String],
        markers: [String],
        reminderISO: String?
    ) async throws -> UUID {
        struct Args: Encodable {
            let p_title: String
            let p_original_text: String
            let p_category: String
            let p_note_summary: String
            let p_source_message_refs: [String]
            let p_photo_thumbs: [String]
            let p_attachment_markers: [String]
            let p_reminder_at: String?
        }
        let id: UUID = try await SB.client
            .rpc("kk_memory_create", params: Args(
                p_title: title,
                p_original_text: original,
                p_category: category,
                p_note_summary: note,
                p_source_message_refs: sourceIds,
                p_photo_thumbs: photos,
                p_attachment_markers: markers,
                p_reminder_at: reminderISO
            ))
            .execute()
            .value
        return id
    }

    static func memoryFromChat(
        title: String,
        original: String,
        category: String,
        sourceIds: [String],
        photos: [String],
        markers: [String]
    ) async throws -> UUID {
        struct Args: Encodable {
            let p_title: String
            let p_original_text: String
            let p_category: String
            let p_source_message_refs: [String]
            let p_photo_thumbs: [String]
            let p_attachment_markers: [String]
        }
        let id: UUID = try await SB.client
            .rpc("kk_memory_from_chat", params: Args(
                p_title: title,
                p_original_text: original,
                p_category: category,
                p_source_message_refs: sourceIds,
                p_photo_thumbs: photos,
                p_attachment_markers: markers
            ))
            .execute()
            .value
        return id
    }

    static func updateMemory(
        id: UUID,
        title: String,
        original: String,
        category: String,
        note: String,
        sourceIds: [String],
        photos: [String],
        markers: [String],
        reminderISO: String?,
        clearReminder: Bool
    ) async throws {
        struct Args: Encodable {
            let p_id: UUID
            let p_title: String
            let p_original_text: String
            let p_category: String
            let p_note_summary: String
            let p_source_message_refs: [String]
            let p_photo_thumbs: [String]
            let p_attachment_markers: [String]
            let p_reminder_at: String?
            let p_clear_reminder: Bool
        }
        _ = try await SB.client
            .rpc("kk_memory_update", params: Args(
                p_id: id,
                p_title: title,
                p_original_text: original,
                p_category: category,
                p_note_summary: note,
                p_source_message_refs: sourceIds,
                p_photo_thumbs: photos,
                p_attachment_markers: markers,
                p_reminder_at: reminderISO,
                p_clear_reminder: clearReminder
            ))
            .execute()
    }

    static func deleteMemory(id: UUID) async throws {
        struct Args: Encodable { let p_id: UUID }
        _ = try await SB.client.rpc("kk_memory_delete", params: Args(p_id: id)).execute()
    }

    static func listWants() async throws -> [WantRow] {
        let rows: [WantRow] = try await SB.client
            .from("want_you_know")
            .select()
            .order("created_at", ascending: false)
            .execute()
            .value
        return rows
    }

    static func listWantReads() async throws -> [WantRead] {
        let rows: [WantRead] = try await SB.client
            .from("want_you_know_reads")
            .select("item_id,user_id")
            .execute()
            .value
        return rows
    }

    static func myCoupleEnds() async throws -> CoupleEnds? {
        let rows: [CoupleEnds] = try await SB.client
            .from("couples")
            .select("user_a_id,user_b_id")
            .execute()
            .value
        return rows.first
    }

    static func createWant(body: String, title: String?, deadline: String?, remind: Bool) async throws -> UUID {
        struct Args: Encodable {
            let p_body: String
            let p_title: String?
            let p_deadline_at: String?
            let p_remind: Bool
        }
        let id: UUID = try await SB.client
            .rpc("kk_want_create", params: Args(
                p_body: body,
                p_title: title,
                p_deadline_at: deadline,
                p_remind: remind
            ))
            .execute()
            .value
        return id
    }

    static func markWantRead(id: UUID) async throws {
        struct Args: Encodable { let p_id: UUID }
        _ = try await SB.client.rpc("kk_want_mark_read", params: Args(p_id: id)).execute()
    }

    static func softDeleteWant(id: UUID) async throws {
        struct Args: Encodable { let p_id: UUID }
        _ = try await SB.client.rpc("kk_want_soft_delete", params: Args(p_id: id)).execute()
    }

    static func aiUsage() async throws -> AIUsage {
        let usage: AIUsage = try await SB.client.rpc("kk_ai_usage_get").execute().value
        return usage
    }

    /// Payload keys are only `user_text`, `memory_ids`, and `memory_items`.
    static func consumeAI(userText: String, memories: [AIMemoryInput]) async throws -> AIConsumeResult {
        let args = AIArgs(p_payload: AIPayload(
            user_text: userText,
            memory_ids: memories.map(\.id),
            memory_items: memories
        ))
        let result: AIConsumeResult = try await SB.client
            .rpc("kk_ai_consume_and_run", params: args)
            .execute()
            .value
        return result
    }

    static func kaomojiPrefs() async throws -> KaomojiPrefs {
        let prefs: KaomojiPrefs = try await SB.client.rpc("kk_kaomoji_prefs_get").execute().value
        return prefs
    }

    static func setKaomojiPrefs(quick: [String], stylePack: String) async throws -> KaomojiPrefs {
        struct Args: Encodable {
            let p_quick_react: [String]
            let p_style_pack: String
        }
        let prefs: KaomojiPrefs = try await SB.client
            .rpc("kk_kaomoji_prefs_set", params: Args(p_quick_react: quick, p_style_pack: stylePack))
            .execute()
            .value
        return prefs
    }

    /// Opportunistic purge. Cron/Edge is still TODO.
    static func purgeExpiredMessages() async throws {
        _ = try await SB.client.rpc("kk_purge_expired_messages").execute()
    }
}

enum KKTimestamps {
    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: raw) { return date }
        let day = DateFormatter()
        day.calendar = Calendar(identifier: .gregorian)
        day.timeZone = KKTime.zone
        day.locale = Locale(identifier: "en_US_POSIX")
        day.dateFormat = "yyyy-MM-dd"
        return day.date(from: raw)
    }

    static func iso(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }
}
