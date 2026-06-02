import Foundation
import Combine
import Supabase

// v1.6.1 Feature 6 — "next meet-up" stickiness loop.
//
// The couple sets the next day they'll meet → a countdown shows in chat + the
// Time tab. On the day, both are prompted to take a selfie (E2EE upload via
// MediaService, same as chat photos); when both selfies are in, the meet-up
// completes. Realtime via the proven postgres_changes path.
struct Meetup: Identifiable, Decodable, Equatable, Sendable {
    let id: UUID
    let couple_id: UUID
    let created_by: UUID
    let meet_date: String        // "yyyy-MM-dd" (plaintext — needed for countdown)
    let title: String
    let status: String           // upcoming | completed | cancelled
    let selfie_a_handle: String?
    let selfie_b_handle: String?
    let created_at: Date
    let completed_at: Date?

    /// Days from today to meet_date (negative = past). Uses the app's HK-local
    /// day helper so late-night entries don't shift a day.
    var daysUntil: Int {
        TimeFormatting.daysBetween(LocalDate.string(from: Date()), meet_date)
    }
    var isUpcoming: Bool { status == "upcoming" }
}

@MainActor
final class MeetupService: ObservableObject {

    /// Nearest not-yet-completed meet-up (drives the chat countdown banner).
    @Published private(set) var upcoming: Meetup?
    /// A meet-up whose day has arrived and for which I still owe a selfie.
    @Published private(set) var dueMeetup: Meetup?
    /// Full list for the Time tab.
    @Published private(set) var all: [Meetup] = []
    /// Surfaced so the chat can toast a failure instead of silently doing
    /// nothing (the original "set date → nothing happens" symptom).
    @Published var lastError: String?

    private let crypto: CryptoService
    private let media: MediaService
    private var coupleId: UUID?
    private var meId: UUID?
    private var isUserA = false
    private var channel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?

    init(crypto: CryptoService) {
        self.crypto = crypto
        self.media = MediaService(crypto: crypto)
    }

    var mediaService: MediaService { media }

    // MARK: - Lifecycle

    func start(coupleId: UUID) {
        if self.coupleId == coupleId, channel != nil { return }
        stop()
        self.coupleId = coupleId
        // Resolve meId synchronously so createMeetup never silently no-ops just
        // because the async bootstrap hasn't set it yet.
        self.meId = SB.client.auth.currentUser?.id
        realtimeTask = Task { [weak self] in await self?.bootstrap(coupleId: coupleId) }
    }

    func stop() {
        realtimeTask?.cancel(); realtimeTask = nil
        pollTask?.cancel(); pollTask = nil
        if let ch = channel { channel = nil; Task { await ch.unsubscribe() } }
        coupleId = nil; meId = nil
        upcoming = nil; dueMeetup = nil; all = []
    }

    func pause() { stop() }
    func resume(coupleId: UUID) { start(coupleId: coupleId) }

    // MARK: - Mutations

    func createMeetup(meetDate: String, title: String) async {
        guard let coupleId, let me = meId else {
            lastError = "未準備好（請稍後再試或重開 app）"
            return
        }
        struct Row: Encodable {
            let couple_id: UUID; let created_by: UUID; let meet_date: String; let title: String
        }
        do {
            try await SB.client.from("meetups")
                .insert(Row(couple_id: coupleId, created_by: me,
                            meet_date: meetDate,
                            title: title.isEmpty ? "下次見面" : title))
                .execute()
            await fetchOnce()
        } catch {
            lastError = "建立見面失敗：\(error.localizedDescription)"
        }
    }

    /// Encrypt + upload the selfie, then attach it to the meet-up (server
    /// decides which side + auto-completes when both are in).
    func submitSelfie(meetupId: UUID, data: Data) async {
        guard let coupleId else { return }
        struct Args: Encodable { let p_meetup_id: UUID; let p_handle: String }
        do {
            let path = try await media.encryptAndUpload(data: data, coupleId: coupleId)
            _ = try await SB.client.rpc("set_meetup_selfie",
                                        params: Args(p_meetup_id: meetupId, p_handle: path))
                .execute()
            await fetchOnce()
        } catch {
            lastError = "上載自拍失敗：\(error.localizedDescription)"
        }
    }

    func cancelMeetup(_ id: UUID) async {
        struct Patch: Encodable { let status: String }
        do {
            try await SB.client.from("meetups")
                .update(Patch(status: "cancelled")).eq("id", value: id).execute()
            await fetchOnce()
        } catch { }
    }

    // MARK: - Internals

    private func bootstrap(coupleId: UUID) async {
        guard let me = SB.client.auth.currentUser?.id else { return }
        self.meId = me
        do {
            let c: CoupleRow = try await SB.client.from("couples")
                .select("user_a_id,user_b_id").eq("id", value: coupleId)
                .single().execute().value
            self.isUserA = (c.user_a_id == me)
        } catch { return }

        await fetchOnce()

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                if Task.isCancelled { break }
                await self?.fetchOnce()
            }
        }

        let ch = SB.client.channel("meetups-\(coupleId.uuidString)")
        self.channel = ch
        let filter = "couple_id=eq.\(coupleId.uuidString.lowercased())"
        let inserts = ch.postgresChange(InsertAction.self, schema: "public",
                                        table: "meetups", filter: filter)
        let updates = ch.postgresChange(UpdateAction.self, schema: "public",
                                        table: "meetups", filter: filter)
        do { try await ch.subscribeWithError() } catch { return }
        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                for await _ in inserts { if Task.isCancelled { break }; await self?.fetchOnce() }
            }
            group.addTask { [weak self] in
                for await _ in updates { if Task.isCancelled { break }; await self?.fetchOnce() }
            }
        }
    }

    private func fetchOnce() async {
        guard let coupleId else { return }
        do {
            let rows: [Meetup] = try await SB.client.from("meetups")
                .select()
                .eq("couple_id", value: coupleId)
                .order("meet_date", ascending: true)
                .execute().value
            self.all = rows

            // Nearest upcoming (today or future, not completed/cancelled).
            self.upcoming = rows.first { $0.isUpcoming && $0.daysUntil >= 0 }

            // Due = upcoming, day has arrived, my selfie still missing.
            self.dueMeetup = rows.first { m in
                guard m.isUpcoming, m.daysUntil <= 0 else { return false }
                let mine = isUserA ? m.selfie_a_handle : m.selfie_b_handle
                return mine == nil
            }
        } catch {
            lastError = "載入見面失敗：\(error.localizedDescription)"
        }
    }

    private struct CoupleRow: Decodable { let user_a_id: UUID; let user_b_id: UUID }
}
