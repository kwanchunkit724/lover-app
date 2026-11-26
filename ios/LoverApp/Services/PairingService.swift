import Foundation
import os
import Supabase
import Combine

/// Parses PostgREST `timestamptz` strings. Postgres often emits 6 fractional
/// digits; Foundation's ISO-8601 parser accepts 0 or 3, so microseconds are
/// trimmed rather than failing the whole partner row (and hiding public_key).
enum PairingTimestamp {
    static func parse(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return nil }
        let withFrac = ISO8601DateFormatter()
        withFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = withFrac.date(from: trimmed) { return date }
        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]
        if let date = plain.date(from: trimmed) { return date }
        guard let regex = try? NSRegularExpression(pattern: #"(\.\d{3})\d+"#) else { return nil }
        let range = NSRange(trimmed.startIndex..<trimmed.endIndex, in: trimmed)
        let shortened = regex.stringByReplacingMatches(
            in: trimmed, options: [], range: range, withTemplate: "$1"
        )
        guard shortened != trimmed else { return nil }
        return withFrac.date(from: shortened)
    }
}

/// Postgres `raise exception` codes from `kk_set_public_key` / `kk_couple_state`.
/// The screen shows these sentences, never the raw code.
enum RPCUserFacing {
    enum Failure: Equatable {
        case invalidPublicKey
        case partnerProfileMissing
        case profileMissing
        case notAuthenticated
        case unavailable
    }

    static func rawText(from error: Error) -> String {
        let ns = error as NSError
        var parts = [ns.localizedDescription]
        if let message = ns.userInfo["message"] as? String {
            parts.append(message)
        }
        if let reason = ns.userInfo[NSLocalizedFailureReasonErrorKey] as? String {
            parts.append(reason)
        }
        return parts.joined(separator: "\n")
    }

    static func failure(for error: Error) -> Failure {
        failure(from: rawText(from: error))
    }

    static func failure(from raw: String) -> Failure {
        let lowered = raw.lowercased()
        if lowered.contains("invalid_public_key") { return .invalidPublicKey }
        if lowered.contains("partner_profile_missing") { return .partnerProfileMissing }
        if lowered.contains("profile_missing") { return .profileMissing }
        if lowered.contains("not_authenticated") || lowered.contains("not authenticated") {
            return .notAuthenticated
        }
        return .unavailable
    }

    static func cantonese(for failure: Failure) -> String {
        switch failure {
        case .invalidPublicKey:
            return "加密鎖匙唔啱，寫唔上伺服器。撳重試再試。"
        case .partnerProfileMissing:
            return "對方未完成註冊 — 等對方再開一次"
        case .profileMissing:
            return "未完成註冊 — 再試一次"
        case .notAuthenticated:
            return "未登入 — 重新登入"
        case .unavailable:
            return "暫時連唔到伺服器。檢查網絡再撳重試。"
        }
    }

    static func cantonese(for error: Error) -> String {
        cantonese(for: failure(for: error))
    }

    /// Nil when `raw` is not one of the key/profile/auth codes, so pairing
    /// errors (wrong code, anniversary mismatch) keep their own sentences.
    static func knownMessage(from raw: String) -> String? {
        let failure = failure(from: raw)
        switch failure {
        case .invalidPublicKey, .partnerProfileMissing, .profileMissing, .notAuthenticated:
            return cantonese(for: failure)
        case .unavailable:
            return nil
        }
    }
}

/// `kk_couple_state()` payload. A null or blank `partner_public_key` is not
/// a ready channel. Unpaired responses are `{"paired": false}` only.
struct CoupleSnapshot: Decodable, Equatable {
    var paired: Bool
    var coupleId: UUID?
    var myPublicKey: String?
    var partnerId: UUID?
    var partnerPublicKey: String?

    enum CodingKeys: String, CodingKey {
        case paired
        case coupleId = "couple_id"
        case myPublicKey = "my_public_key"
        case partnerId = "partner_id"
        case partnerPublicKey = "partner_public_key"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        paired = try c.decode(Bool.self, forKey: .paired)
        coupleId = try? c.decode(UUID.self, forKey: .coupleId)
        partnerId = try? c.decode(UUID.self, forKey: .partnerId)
        myPublicKey = Self.normalizedKey(try? c.decode(String.self, forKey: .myPublicKey))
        partnerPublicKey = Self.normalizedKey(try? c.decode(String.self, forKey: .partnerPublicKey))
    }

    static func normalizedKey(_ raw: String?) -> String? {
        guard let trimmed = raw?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }

    /// Authority for the chat lock. Ignores a key on an unpaired payload.
    var partnerKeyState: PairingService.PartnerKeyState {
        guard paired else { return .unknown }
        if coupleId == nil || partnerId == nil { return .unreadable }
        return partnerPublicKey == nil ? .nullKey : .present
    }
}

// Wraps the two pairing RPCs and the couples table query.
//
//   create_pairing_code()                 → server-issued 6-digit code (10-min TTL)
//   redeem_pairing_code(code, anniv_iso)  → atomic pair, returns couple id
//
// Tracks `couple` state so RootView can route signedIn-but-unpaired users to
// PairingView and signedIn-and-paired users to MainTabView.

@MainActor
final class PairingService: ObservableObject {

    // MARK: - Models

    struct Couple: Decodable, Equatable {
        let id: UUID
        let userAID: UUID
        let userBID: UUID
        let pairedAt: Date

        enum CodingKeys: String, CodingKey {
            case id
            case userAID    = "user_a_id"
            case userBID    = "user_b_id"
            case pairedAt   = "paired_at"
        }

        init(id: UUID, userAID: UUID, userBID: UUID, pairedAt: Date) {
            self.id = id
            self.userAID = userAID
            self.userBID = userBID
            self.pairedAt = pairedAt
        }

        /// The OTHER user's id, given mine.
        func partnerId(forMe me: UUID) -> UUID? {
            if userAID == me { return userBID }
            if userBID == me { return userAID }
            return nil
        }
    }

    /// Mirrors the public.users row of the partner once paired.
    struct PartnerRow: Decodable {
        let id: UUID
        let myName: String          // partner's myName
        let partnerName: String     // partner's partnerName (echo of yours)
        let anniversaryISO: String
        let themeId: String
        let publicKey: String?      // base64 X25519 raw — Phase 4a
        let lastSeenAt: Date?       // Phase C — heartbeat timestamp, used by ChatView header

        enum CodingKeys: String, CodingKey {
            case id
            case myName        = "my_name"
            case partnerName   = "partner_name"
            case anniversaryISO = "anniversary_iso"
            case themeId       = "theme_id"
            case publicKey     = "public_key"
            case lastSeenAt    = "last_seen_at"
        }

        init(id: UUID, myName: String, partnerName: String, anniversaryISO: String,
             themeId: String, publicKey: String?, lastSeenAt: Date?) {
            self.id = id
            self.myName = myName
            self.partnerName = partnerName
            self.anniversaryISO = anniversaryISO
            self.themeId = themeId
            self.publicKey = publicKey
            self.lastSeenAt = lastSeenAt
        }

        /// Optional fields never fail the row. A bad `last_seen_at` used to
        /// throw away a perfectly good `public_key`, and the chat banner
        /// reported that as a nil partner key.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            id = try c.decode(UUID.self, forKey: .id)
            myName = try c.decode(String.self, forKey: .myName)
            partnerName = (try? c.decode(String.self, forKey: .partnerName)) ?? ""
            anniversaryISO = (try? c.decode(String.self, forKey: .anniversaryISO)) ?? ""
            themeId = (try? c.decode(String.self, forKey: .themeId)) ?? "jbeam"
            let key = (try? c.decode(String.self, forKey: .publicKey))?
                .trimmingCharacters(in: .whitespacesAndNewlines)
            publicKey = (key?.isEmpty == false) ? key : nil
            if let raw = try? c.decode(String.self, forKey: .lastSeenAt) {
                lastSeenAt = PairingTimestamp.parse(raw)
            } else {
                lastSeenAt = nil
            }
        }
    }

    /// What the last partner-row read told us about `users.public_key`.
    /// `.nullKey` means the row arrived and the column was empty. That is
    /// not a ready channel — the key was never written, or the server did
    /// not return it.
    enum PartnerKeyState: Equatable {
        case unknown
        case missingRow
        case nullKey
        case present
        case unreadable
    }

    /// Active pairing code issued by THIS device. Carries the anniversary
    /// the generator picked so the Generate screen can echo it back as
    /// "對方要輸入: yyyy.MM.dd".
    struct ActiveCode: Equatable {
        let code: String                // "123456"
        let anniversaryISO: String      // "yyyy-MM-dd" the partner must enter
        let expiresAt: Date
    }

    // MARK: - State

    @Published private(set) var couple: Couple?
    @Published private(set) var partner: PartnerRow?
    @Published private(set) var partnerKeyState: PartnerKeyState = .unknown
    @Published private(set) var activeCode: ActiveCode?
    @Published private(set) var isLoading: Bool = false
    @Published private(set) var channelRetryNonce: Int = 0
    /// Our key as `kk_couple_state` reported it. Nil when unpaired, or when
    /// the paired payload's `my_public_key` was null/blank.
    @Published private(set) var myServerPublicKey: String?
    /// True after a `kk_couple_state` read succeeds. Distinguishes "not loaded"
    /// from "paired and the server returned a null key".
    @Published private(set) var coupleStateLoaded = false
    /// Last `kk_couple_state` failure. Cleared on the next successful read.
    @Published private(set) var refreshFailure: RPCUserFacing.Failure?
    @Published var lastError: String?

    private var pairWatchTask: Task<Void, Never>?
    private var prepareGeneration = 0
    private var pairChannel: RealtimeChannelV2?
    private var pairRealtimeTask: Task<Void, Never>?
    private var pairingEventRefresh: Task<Void, Never>?
    private var eventCoalesced = false
    private var watchToken = 0
    private var watchUserId: UUID?
    private enum WatchState { case stopped, connecting, live, failed }
    private var watchState: WatchState = .stopped
    private let pairingLog = Logger(subsystem: "michel.kit.us", category: "pairing")

    var isPaired: Bool { couple != nil }

    init() {
        if UITesting.mode == .shell {
            installUITestFixture(meId: UITesting.fixtureUserId)
        }
    }

    /// In-memory couple so the chat composer can render in Simulator smoke.
    /// Does not call create/redeem and does not write a couples row.
    func installUITestFixture(meId: UUID) {
        guard UITesting.mode == .shell else { return }
        couple = Couple(
            id: UITesting.fixtureCoupleId,
            userAID: meId,
            userBID: UITesting.fixturePartnerId,
            pairedAt: Date(timeIntervalSince1970: 0)
        )
        partner = PartnerRow(
            id: UITesting.fixturePartnerId,
            myName: "UI Partner",
            partnerName: "UI Preview",
            anniversaryISO: "2020-01-01",
            themeId: "jbeam",
            publicKey: nil,
            lastSeenAt: nil
        )
        partnerKeyState = .nullKey
    }

    /// v1.6.1 — explicitly clear all pairing state. MUST be called on
    /// sign-out / account-deletion: otherwise the in-memory couple/partner
    /// survive and a different account signing in on the same device briefly
    /// sees the previous couple (wrong-couple data exposure) until refresh
    /// returns. (review: high-severity stale-state bug.)
    func resetState() {
        stopWaitingForPartner()
        prepareGeneration += 1
        couple = nil
        partner = nil
        partnerKeyState = .unknown
        myServerPublicKey = nil
        coupleStateLoaded = false
        refreshFailure = nil
        activeCode = nil
        lastError = nil
    }

    /// RootView's prepare loop holds the returned token. Sign-out, unpair,
    /// and a new attempt all bump the counter so the old loop exits.
    func beginPrepareAttempt() -> Int {
        prepareGeneration += 1
        return prepareGeneration
    }

    func prepareAttemptIsCurrent(_ generation: Int) -> Bool {
        generation == prepareGeneration
    }

    // MARK: - Bootstrap

    /// Called after sign-in and whenever pairing or a public key may have
    /// changed. `kk_couple_state` is the authority for "are we paired?" and
    /// for both public keys. A null `partner_public_key` stays not-ready.
    ///
    /// `quiet` is the generator's wait-loop and the realtime handler: it must
    /// not flip `isLoading` or replace a pairing-screen error with a raw
    /// transport string.
    func refresh(meId: UUID, quiet: Bool = false) async {
        if UITesting.blocksNetwork { return }
        if !quiet { isLoading = true }
        defer { if !quiet { isLoading = false } }
        do {
            let snapshot: CoupleSnapshot = try await SB.client
                .rpc("kk_couple_state")
                .execute()
                .value
            try await apply(snapshot, meId: meId)
            refreshFailure = nil
            if !quiet { lastError = nil }
        } catch {
            let failure = RPCUserFacing.failure(for: error)
            refreshFailure = failure
            if partner?.publicKey == nil {
                partnerKeyState = .unreadable
            }
            pairingLog.error("kk_couple_state failed: \(error.localizedDescription, privacy: .public)")
            if !quiet {
                lastError = RPCUserFacing.cantonese(for: failure)
            }
        }
    }

    private enum CoupleStateError: Error {
        /// `paired: true` without the ids the client needs to open chat.
        case incomplete
    }

    /// Names and last-seen still come from the partner row. The public key
    /// on that row is replaced with the RPC value so a select that omits
    /// `public_key` cannot hide a key, and a stale column cannot paper over
    /// a null RPC field.
    private func apply(_ snapshot: CoupleSnapshot, meId: UUID) async throws {
        coupleStateLoaded = true
        guard snapshot.paired else {
            couple = nil
            partner = nil
            partnerKeyState = .unknown
            myServerPublicKey = nil
            return
        }
        guard let coupleId = snapshot.coupleId, let partnerId = snapshot.partnerId else {
            throw CoupleStateError.incomplete
        }
        let loaded = await fetchCoupleRow(id: coupleId)
        couple = loaded ?? Couple(
            id: coupleId,
            userAID: meId,
            userBID: partnerId,
            pairedAt: Date(timeIntervalSince1970: 0)
        )
        let display = await fetchPartnerDisplay(id: partnerId)
        partner = PartnerRow(
            id: display?.id ?? partnerId,
            myName: display?.myName ?? "",
            partnerName: display?.partnerName ?? "",
            anniversaryISO: display?.anniversaryISO ?? "",
            themeId: display?.themeId ?? "jbeam",
            publicKey: snapshot.partnerPublicKey,
            lastSeenAt: display?.lastSeenAt
        )
        partnerKeyState = snapshot.partnerKeyState
        myServerPublicKey = snapshot.myPublicKey
    }

    private func fetchCoupleRow(id: UUID) async -> Couple? {
        do {
            let rows: [Couple] = try await SB.client
                .from("couples")
                .select("id,user_a_id,user_b_id,paired_at")
                .eq("id", value: id)
                .execute()
                .value
            return rows.first
        } catch {
            pairingLog.error("couple row fetch failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func fetchPartnerDisplay(id: UUID) async -> PartnerRow? {
        (try? await fetchPartner(id: id))?.first
    }

    /// Display fields only. The chat key is not taken from this select.
    private func fetchPartner(id: UUID) async throws -> [PartnerRow] {
        let withPresence = "id,my_name,partner_name,anniversary_iso,theme_id,last_seen_at"
        let namesOnly = "id,my_name,partner_name,anniversary_iso,theme_id"
        do {
            return try await selectPartner(id: id, columns: withPresence)
        } catch {
            pairingLog.error("partner profile select failed, retrying without last_seen_at: \(error.localizedDescription, privacy: .public)")
            return try await selectPartner(id: id, columns: namesOnly)
        }
    }

    private func selectPartner(id: UUID, columns: String) async throws -> [PartnerRow] {
        try await SB.client
            .from("users")
            .select(columns)
            .eq("id", value: id)
            .execute()
            .value
    }

    /// `.nullKey` is an empty key on a row we did read. `.unreadable`
    /// is reserved for the fetch/decode error path.
    nonisolated static func classifyPartnerKey(_ partner: PartnerRow?) -> PartnerKeyState {
        guard let partner else { return .missingRow }
        if let key = partner.publicKey, !key.isEmpty { return .present }
        return .nullKey
    }

    // MARK: - Realtime + generator wait

    /// Subscribe to `couples`, `users`, and `pairing_codes`. A couple insert
    /// or a partner `public_key` update calls `kk_couple_state` immediately.
    /// Safe to call again; a live or in-flight subscription is left alone.
    func startSessionWatch(meId: UUID) {
        if UITesting.blocksNetwork { return }
        if watchUserId == meId, watchState == .live || watchState == .connecting { return }
        stopSessionWatch()
        watchUserId = meId
        watchToken += 1
        let token = watchToken
        watchState = .connecting
        pairRealtimeTask = Task { [weak self] in
            await self?.runPairingRealtime(meId: meId, token: token)
        }
    }

    func stopSessionWatch() {
        watchToken += 1
        watchState = .stopped
        watchUserId = nil
        pairingEventRefresh?.cancel()
        pairingEventRefresh = nil
        pairRealtimeTask?.cancel()
        pairRealtimeTask = nil
        if let channel = pairChannel {
            pairChannel = nil
            Task { await channel.unsubscribe() }
        }
    }

    private func runPairingRealtime(meId: UUID, token: Int) async {
        guard watchToken == token else { return }
        let me = meId.uuidString.lowercased()
        let channel = SB.client.channel("pairing-\(me)")
        pairChannel = channel
        guard watchToken == token else {
            await channel.unsubscribe()
            return
        }
        let coupleInsertA = channel.postgresChange(
            InsertAction.self, schema: "public", table: "couples",
            filter: "user_a_id=eq.\(me)"
        )
        let coupleInsertB = channel.postgresChange(
            InsertAction.self, schema: "public", table: "couples",
            filter: "user_b_id=eq.\(me)"
        )
        let coupleDeleteA = channel.postgresChange(
            DeleteAction.self, schema: "public", table: "couples",
            filter: "user_a_id=eq.\(me)"
        )
        let coupleDeleteB = channel.postgresChange(
            DeleteAction.self, schema: "public", table: "couples",
            filter: "user_b_id=eq.\(me)"
        )
        let userUpdates = channel.postgresChange(
            UpdateAction.self, schema: "public", table: "users"
        )
        let codeDeletes = channel.postgresChange(
            DeleteAction.self, schema: "public", table: "pairing_codes",
            filter: "user_id=eq.\(me)"
        )
        do {
            try await channel.subscribeWithError()
        } catch {
            if watchToken == token { watchState = .failed }
            pairingLog.error("pairing realtime subscribe failed: \(error.localizedDescription, privacy: .public)")
            return
        }
        guard watchToken == token else {
            await channel.unsubscribe()
            return
        }
        watchState = .live
        await refresh(meId: meId, quiet: true)

        await withTaskGroup(of: Void.self) { group in
            group.addTask { [weak self] in
                for await _ in coupleInsertA {
                    if Task.isCancelled { break }
                    await self?.handlePairingEvent()
                }
            }
            group.addTask { [weak self] in
                for await _ in coupleInsertB {
                    if Task.isCancelled { break }
                    await self?.handlePairingEvent()
                }
            }
            group.addTask { [weak self] in
                for await _ in coupleDeleteA {
                    if Task.isCancelled { break }
                    await self?.handlePairingEvent()
                }
            }
            group.addTask { [weak self] in
                for await _ in coupleDeleteB {
                    if Task.isCancelled { break }
                    await self?.handlePairingEvent()
                }
            }
            group.addTask { [weak self] in
                for await _ in userUpdates {
                    if Task.isCancelled { break }
                    await self?.handlePairingEvent()
                }
            }
            group.addTask { [weak self] in
                for await _ in codeDeletes {
                    if Task.isCancelled { break }
                    await self?.handlePairingEvent()
                }
            }
        }
        if watchToken == token, watchState == .live {
            watchState = .stopped
        }
    }

    private func handlePairingEvent() async {
        if pairingEventRefresh != nil {
            eventCoalesced = true
            return
        }
        pairingEventRefresh = Task { [weak self] in
            guard let self else { return }
            repeat {
                self.eventCoalesced = false
                guard let me = self.watchUserId else { break }
                await self.refresh(meId: me, quiet: true)
            } while self.eventCoalesced && !Task.isCancelled
            self.pairingEventRefresh = nil
        }
    }

    /// Fallback while a code is on screen. Realtime is the fast path; this
    /// poll catches a missed event. Slower once the channel is live.
    func startWaitingForPartner(meId: UUID) {
        if UITesting.blocksNetwork { return }
        startSessionWatch(meId: meId)
        if isPaired || activeCode == nil { return }
        pairWatchTask?.cancel()
        pairWatchTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.isPaired || self.activeCode == nil { return }
                await self.refresh(meId: meId, quiet: true)
                if Task.isCancelled || self.isPaired || self.activeCode == nil { return }
                let wait: UInt64 = self.watchState == .live ? 8_000_000_000 : 2_000_000_000
                try? await Task.sleep(nanoseconds: wait)
            }
        }
    }

    func stopWaitingForPartner() {
        pairWatchTask?.cancel()
        pairWatchTask = nil
    }

    /// Chat's 重試 button. RootView observes this and runs prepare again,
    /// including when the previous prepare loop already exited.
    func requestChannelRetry() {
        channelRetryNonce += 1
    }

    // MARK: - Generate code (phone A)

    private struct CreateArgs: Encodable {
        let p_anniversary_iso: String
    }

    /// Phase 3c v0.3.3 — generator picks the anniversary at code-creation
    /// time so it's an explicit confirmation rather than silently inheriting
    /// a casual onboarding placeholder.
    func createCode(anniversary: Date) async {
        if UITesting.blocksNetwork {
            lastError = "UI test fixture does not create pairing codes."
            return
        }
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        do {
            let annivISO = LocalDate.string(from: anniversary)
            let code: String = try await SB.client
                .rpc("create_pairing_code",
                     params: CreateArgs(p_anniversary_iso: annivISO))
                .execute()
                .value
            activeCode = ActiveCode(code: code,
                                    anniversaryISO: annivISO,
                                    expiresAt: Date().addingTimeInterval(10 * 60))
        } catch {
            lastError = friendlyMessage(for: error)
        }
    }

    func clearActiveCode() {
        activeCode = nil
        stopWaitingForPartner()
    }

    // MARK: - Unpair (Phase 3c)

    /// Atomic unpair — calls public.unpair() RPC which deletes the couple row
    /// for whichever side made the call. Both sides fall back to PairingView
    /// on their next refresh.
    func unpair() async {
        if UITesting.blocksNetwork {
            lastError = "UI test fixture does not unpair."
            return
        }
        isLoading = true
        defer { isLoading = false }
        lastError = nil
        do {
            _ = try await SB.client.rpc("unpair").execute()
            self.couple = nil
            self.partner = nil
            self.activeCode = nil
        } catch {
            lastError = friendlyMessage(for: error)
        }
    }

    // MARK: - Redeem code (phone B)

    private struct RedeemArgs: Encodable {
        let p_code: String
        let p_anniversary_iso: String
    }

    /// Returns true on success, false on failure (with `lastError` populated).
    func redeem(code: String, anniversary: Date, meId: UUID) async -> Bool {
        if UITesting.blocksNetwork {
            lastError = "UI test fixture does not redeem pairing codes."
            return false
        }
        isLoading = true
        defer { isLoading = false }
        lastError = nil

        let annivISO = LocalDate.string(from: anniversary)

        do {
            _ = try await SB.client
                .rpc("redeem_pairing_code",
                     params: RedeemArgs(p_code: code, p_anniversary_iso: annivISO))
                .execute()
            await refresh(meId: meId)
            return true
        } catch {
            lastError = friendlyMessage(for: error)
            return false
        }
    }

    // MARK: - Error mapping

    /// Maps the Postgres `raise exception '...'` strings from our RPCs into
    /// user-facing Cantonese messages. Key / profile / auth codes go through
    /// `RPCUserFacing` so the raw code never reaches the screen.
    private func friendlyMessage(for error: Error) -> String {
        let raw = RPCUserFacing.rawText(from: error)
        if let known = RPCUserFacing.knownMessage(from: raw) { return known }
        let lowered = raw.lowercased()
        if lowered.contains("anniversary_mismatch") { return "日子對唔上 — 兩個人輸入嘅日子要一樣" }
        if lowered.contains("invalid_code")          { return "配對碼錯咗 — 再對下" }
        if lowered.contains("code_expired")          { return "配對碼過期 — 重新生成一個" }
        if lowered.contains("already_paired")        { return "已經配對咗 — 唔可以再 pair" }
        if lowered.contains("cannot_pair_with_self") { return "唔可以同自己 pair 喎 ｡°(°.◜ᯅ◝°)°｡" }
        return raw
    }
}
