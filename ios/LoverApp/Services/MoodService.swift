import Foundation
import Combine
import Supabase

// v1.6.1 Feature 7 — mood + cheer service.
//
// Durable mood lives on users.mood (set via set_mood RPC, read on start +
// polled every 15s — mood changes are rare so this avoids putting the users
// table on the realtime publication). The cheer COMPLETION is a row in the
// `cheers` table, delivered to the cheered partner via the proven
// postgres_changes realtime path (same as messages/play_history). Live
// per-tap progress is shown on the cheerer's own screen locally; the partner
// gets the completion celebration.
@MainActor
final class MoodService: ObservableObject {

    @Published private(set) var myMood: Mood?
    @Published private(set) var partnerMood: Mood?
    /// Set when the partner just finished cheering ME — drives a celebration
    /// overlay in ChatView. Cleared by the view once shown.
    @Published var incomingCheer: IncomingCheer?

    struct IncomingCheer: Identifiable, Equatable {
        let id = UUID()
        let mood: Mood
    }

    private var coupleId: UUID?
    private var meId: UUID?
    private var partnerId: UUID?
    private var channel: RealtimeChannelV2?
    private var realtimeTask: Task<Void, Never>?
    private var pollTask: Task<Void, Never>?
    private var startedAt = Date()

    // MARK: - Lifecycle

    func start(coupleId: UUID) {
        if self.coupleId == coupleId, channel != nil { return }
        stop()
        self.coupleId = coupleId
        startedAt = Date()
        realtimeTask = Task { [weak self] in await self?.bootstrap(coupleId: coupleId) }
    }

    func stop() {
        realtimeTask?.cancel(); realtimeTask = nil
        pollTask?.cancel(); pollTask = nil
        if let ch = channel { channel = nil; Task { await ch.unsubscribe() } }
        coupleId = nil; meId = nil; partnerId = nil
        partnerMood = nil; incomingCheer = nil
    }

    func pause() { stop() }
    func resume(coupleId: UUID) { start(coupleId: coupleId) }

    // MARK: - Mutations

    func setMood(_ mood: Mood?) async {
        struct Args: Encodable { let p_mood: String? }
        do {
            _ = try await SB.client.rpc("set_mood", params: Args(p_mood: mood?.rawValue)).execute()
            self.myMood = mood
        } catch { }
    }

    /// Optimistically reflect that I just cheered my partner up, so the mood
    /// shown in the header flips to happy immediately instead of waiting for
    /// the 15s poll. (The partner's device sets their own mood happy too.)
    func markPartnerCheered() { partnerMood = .happy }

    /// The cheerer finished the tap target → record the completed cheer.
    func sendCheerComplete(targetMood: Mood) async {
        guard let coupleId, let me = meId, let partner = partnerId else { return }
        struct Row: Encodable {
            let couple_id: UUID; let from_user_id: UUID; let to_user_id: UUID; let mood: String
        }
        do {
            try await SB.client.from("cheers")
                .insert(Row(couple_id: coupleId, from_user_id: me,
                            to_user_id: partner, mood: targetMood.rawValue))
                .execute()
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
            self.partnerId = (c.user_a_id == me) ? c.user_b_id : c.user_a_id
        } catch { return }

        await refreshMoods()

        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 15_000_000_000)
                if Task.isCancelled { break }
                await self?.refreshMoods()
            }
        }

        await subscribeCheers(coupleId: coupleId)
    }

    private func refreshMoods() async {
        guard let me = meId, let partner = partnerId else { return }
        do {
            let rows: [UserMoodRow] = try await SB.client.from("users")
                .select("id,mood").in("id", value: [me, partner])
                .execute().value
            for r in rows {
                let m = r.mood.flatMap(Mood.init(rawValue:))
                if r.id == me { self.myMood = m }
                else if r.id == partner { self.partnerMood = m }
            }
        } catch { }
    }

    private func subscribeCheers(coupleId: UUID) async {
        let ch = SB.client.channel("cheers-\(coupleId.uuidString)")
        self.channel = ch
        let inserts = ch.postgresChange(
            InsertAction.self,
            schema: "public",
            table: "cheers",
            filter: "couple_id=eq.\(coupleId.uuidString.lowercased())"
        )
        do { try await ch.subscribeWithError() } catch { return }
        for await _ in inserts {
            if Task.isCancelled { break }
            await handleCheerEvent()
        }
    }

    private func handleCheerEvent() async {
        guard let coupleId, let me = meId else { return }
        do {
            let rows: [CheerRow] = try await SB.client.from("cheers")
                .select("to_user_id,mood,created_at")
                .eq("couple_id", value: coupleId)
                .order("created_at", ascending: false)
                .limit(1).execute().value
            guard let latest = rows.first, latest.to_user_id == me else { return }
            // Ignore cheers older than this session (history backfill).
            if latest.created_at < startedAt.addingTimeInterval(-5) { return }
            let mood = Mood(rawValue: latest.mood) ?? .happy
            self.incomingCheer = IncomingCheer(mood: mood)
            // I've been cheered — my mood is happy now.
            await setMood(.happy)
        } catch { }
    }

    // MARK: - Wire rows

    private struct CoupleRow: Decodable { let user_a_id: UUID; let user_b_id: UUID }
    private struct UserMoodRow: Decodable { let id: UUID; let mood: String? }
    private struct CheerRow: Decodable { let to_user_id: UUID; let mood: String; let created_at: Date }
}
