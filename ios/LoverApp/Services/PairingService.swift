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
    @Published var lastError: String?

    private var pairWatchTask: Task<Void, Never>?
    private var prepareGeneration = 0
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

    /// Called after sign-in. Fetches the existing couple row (if any) and
    /// the partner's user row, including `public_key` by name.
    ///
    /// `quiet` is the generator's wait-loop: it must not flip `isLoading`
    /// (that flashes the generate button) or replace a pairing-screen error
    /// with a raw transport string.
    func refresh(meId: UUID, quiet: Bool = false) async {
        if UITesting.blocksNetwork { return }
        if !quiet { isLoading = true }
        defer { if !quiet { isLoading = false } }
        do {
            let couples: [Couple] = try await SB.client
                .from("couples")
                .select()
                .execute()
                .value
            let nextCouple = couples.first
            guard let nextCouple, let partnerId = nextCouple.partnerId(forMe: meId) else {
                couple = nil
                partner = nil
                partnerKeyState = .unknown
                if !quiet { lastError = nil }
                return
            }
            do {
                let rows = try await fetchPartner(id: partnerId)
                couple = nextCouple
                partner = rows.first
                partnerKeyState = Self.classifyPartnerKey(rows.first)
                if !quiet { lastError = nil }
            } catch {
                // Couple exists, but the partner row (and its public_key)
                // could not be read. Do not pretend the key is merely nil
                // without recording that the read failed.
                couple = nextCouple
                partner = nil
                partnerKeyState = .unreadable
                pairingLog.error("partner public_key fetch failed: \(error.localizedDescription, privacy: .public)")
                if !quiet {
                    lastError = "暫時讀唔到對方資料。檢查網絡再試。"
                }
            }
        } catch {
            pairingLog.error("couple fetch failed: \(error.localizedDescription, privacy: .public)")
            if !quiet {
                lastError = "暫時讀唔到配對資料。檢查網絡再試。"
            }
        }
    }

    /// Ask for `public_key` by name. If `last_seen_at` is the column the
    /// server rejects, retry without it so a header field cannot hide the key.
    private func fetchPartner(id: UUID) async throws -> [PartnerRow] {
        let withPresence = "id,my_name,partner_name,anniversary_iso,theme_id,public_key,last_seen_at"
        let keyOnly = "id,my_name,partner_name,anniversary_iso,theme_id,public_key"
        do {
            return try await selectPartner(id: id, columns: withPresence)
        } catch {
            pairingLog.error("partner select failed, retrying without last_seen_at: \(error.localizedDescription, privacy: .public)")
            return try await selectPartner(id: id, columns: keyOnly)
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

    /// `.nullKey` is an empty column on a row we did read. `.unreadable`
    /// is reserved for the fetch/decode error path.
    nonisolated static func classifyPartnerKey(_ partner: PartnerRow?) -> PartnerKeyState {
        guard let partner else { return .missingRow }
        if let key = partner.publicKey, !key.isEmpty { return .present }
        return .nullKey
    }

    // MARK: - Generator wait

    /// `couples` is not in the realtime publication, and the code generator
    /// never called refresh after `createCode`. The redeemer enters chat
    /// immediately; this side stayed on the code screen until the next cold
    /// start. Poll while a code is on screen.
    func startWaitingForPartner(meId: UUID) {
        if UITesting.blocksNetwork { return }
        if isPaired || activeCode == nil { return }
        pairWatchTask?.cancel()
        pairWatchTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                if self.isPaired || self.activeCode == nil { return }
                await self.refresh(meId: meId, quiet: true)
                if Task.isCancelled || self.isPaired || self.activeCode == nil { return }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
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
    /// user-facing Cantonese messages. Surfaces unknown errors verbatim.
    private func friendlyMessage(for error: Error) -> String {
        let raw = (error as NSError).userInfo["message"] as? String
                ?? error.localizedDescription
        let lowered = raw.lowercased()
        if lowered.contains("anniversary_mismatch") { return "日子對唔上 — 兩個人輸入嘅日子要一樣" }
        if lowered.contains("invalid_code")          { return "配對碼錯咗 — 再對下" }
        if lowered.contains("code_expired")          { return "配對碼過期 — 重新生成一個" }
        if lowered.contains("already_paired")        { return "已經配對咗 — 唔可以再 pair" }
        if lowered.contains("cannot_pair_with_self") { return "唔可以同自己 pair 喎 ｡°(°.◜ᯅ◝°)°｡" }
        if lowered.contains("profile_missing")       { return "未完成註冊 — 重新登入再試" }
        if lowered.contains("not_authenticated")     { return "未登入 — 重新登入" }
        return raw
    }
}
