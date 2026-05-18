import Foundation
import Supabase
import Combine

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
    @Published private(set) var activeCode: ActiveCode?
    @Published private(set) var isLoading: Bool = false
    @Published var lastError: String?

    var isPaired: Bool { couple != nil }

    // MARK: - Bootstrap

    /// Called after sign-in. Fetches the existing couple row (if any) and
    /// the partner's user row.
    func refresh(meId: UUID) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let couples: [Couple] = try await SB.client
                .from("couples")
                .select()
                .execute()
                .value
            self.couple = couples.first
            self.partner = nil
            if let couple, let partnerId = couple.partnerId(forMe: meId) {
                let rows: [PartnerRow] = try await SB.client
                    .from("users")
                    .select()
                    .eq("id", value: partnerId)
                    .execute()
                    .value
                self.partner = rows.first
            }
        } catch {
            // RLS or network — leave couple/partner nil; UI shows pairing options.
            lastError = error.localizedDescription
        }
    }

    // MARK: - Generate code (phone A)

    private struct CreateArgs: Encodable {
        let p_anniversary_iso: String
    }

    /// Phase 3c v0.3.3 — generator picks the anniversary at code-creation
    /// time so it's an explicit confirmation rather than silently inheriting
    /// a casual onboarding placeholder.
    func createCode(anniversary: Date) async {
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
    }

    // MARK: - Unpair (Phase 3c)

    /// Atomic unpair — calls public.unpair() RPC which deletes the couple row
    /// for whichever side made the call. Both sides fall back to PairingView
    /// on their next refresh.
    func unpair() async {
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
        if lowered.contains("anniversary_mismatch") { return "紀念日對唔上 — 兩個人輸入嘅日子要一樣" }
        if lowered.contains("invalid_code")          { return "配對碼錯咗 — 再對下" }
        if lowered.contains("code_expired")          { return "配對碼過期 — 重新生成一個" }
        if lowered.contains("already_paired")        { return "已經配對咗 — 唔可以再 pair" }
        if lowered.contains("cannot_pair_with_self") { return "唔可以同自己 pair 喎 ｡°(°.◜ᯅ◝°)°｡" }
        if lowered.contains("profile_missing")       { return "未完成註冊 — 重新登入再試" }
        if lowered.contains("not_authenticated")     { return "未登入 — 重新登入" }
        return raw
    }
}
