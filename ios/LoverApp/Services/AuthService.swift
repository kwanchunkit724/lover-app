import Foundation
import os
import AuthenticationServices
import CryptoKit
import Supabase

// KK auth is Sign in with Apple or email OTP only.
// Do not add signInAnonymously or a guest path.
//
// Native Sign in with Apple → Supabase. Apple gives us an identityToken (a
// signed JWT containing the user's stable Apple ID). We pass it to Supabase
// Auth's signInWithIdToken, which validates the JWT against Apple's public
// keys and returns a Supabase session.
//
// Phase 3a scope: just sign in. The first time a user signs in, we also
// upsert a row into public.users using the local UserProfile (collected during
// onboarding). Phase 3b layers on the pairing flow.

/// Result of `kk_set_public_key`. The RPC either writes the key or throws,
/// so there is no separate "wrote but the select omitted it" state.
enum PublicKeyPublish: Equatable {
    case published
    case writeFailed
    case skipped
}

@MainActor
final class AuthService: NSObject, ObservableObject {

    enum State: Equatable {
        case unknown                    // checking session on launch
        case signedOut
        case signedIn(userId: UUID)
        case error(String)
    }

    /// Phase 8 v0.8.0 — separate published surface for the email/OTP flow
    /// so the SignInView can show an "已寄個 link 去你 email" confirmation
    /// without entangling with the main `state` machine.
    @Published var emailLinkSent: String? = nil

    /// Nil until `kk_set_public_key` has been attempted. `true` means the RPC
    /// returned success (it writes the key or throws). A paired
    /// `kk_couple_state` can still report a null `my_public_key`; the chat
    /// banner treats that null as not ready.
    @Published private(set) var ownPublicKeyOnServer: Bool?
    /// Set when `kk_set_public_key` fails. The chat banner maps this to
    /// Cantonese. Nil after a successful publish.
    @Published private(set) var publicKeyFailure: RPCUserFacing.Failure?

    @Published private(set) var state: State = .unknown

    private let authLog = Logger(subsystem: "michel.kit.us", category: "auth")

    /// Random nonce used for the current Sign-in-with-Apple request. Apple
    /// echoes it in the identityToken so we can detect replay attacks.
    private var currentNonce: String?

    // MARK: - Session bootstrap

    /// Called on app launch. If a previous session exists in the keychain,
    /// transition to .signedIn; otherwise .signedOut.
    func bootstrap() async {
        switch UITesting.mode {
        case .auth:
            state = .signedOut
            return
        case .shell:
            state = .signedIn(userId: UITesting.fixtureUserId)
            return
        case .off:
            break
        }
        do {
            let session = try await SB.client.auth.session
            state = .signedIn(userId: session.user.id)
        } catch {
            // No session, or session expired and refresh failed. Either way
            // the user needs to sign in again.
            state = .signedOut
        }
    }

    // MARK: - Sign in with Apple

    /// Configures an ASAuthorizationAppleIDRequest with a fresh nonce. Pass
    /// the result to SignInWithAppleButton's `onRequest` closure.
    func configureAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        let nonce = Self.randomNonceString()
        currentNonce = nonce
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    /// Handles the result returned by SignInWithAppleButton's `onCompletion`.
    /// On success: extracts identityToken, calls Supabase signInWithIdToken,
    /// and writes `users.my_name` from the local profile (or the Apple given
    /// name when the local name is still the 「我」 placeholder).
    /// Returns the profile that should be saved on device. Nil on cancel or
    /// when sign-in itself failed.
    @discardableResult
    func handleAppleResult(_ result: Result<ASAuthorization, Error>,
                           profile: UserProfile) async -> UserProfile? {
        if UITesting.blocksNetwork {
            state = .error("UI test mode does not sign in.")
            return nil
        }
        switch result {
        case .failure(let error):
            // User cancelled is harmless; everything else surfaces.
            if (error as? ASAuthorizationError)?.code == .canceled { return nil }
            state = .error(error.localizedDescription)
            return nil

        case .success(let auth):
            guard let nonce = currentNonce else {
                state = .error("missing nonce")
                return nil
            }
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                state = .error("missing identity token")
                return nil
            }

            let named = CoupleNames.profile(
                profile,
                givenName: credential.fullName?.givenName,
                familyName: credential.fullName?.familyName,
                nickname: credential.fullName?.nickname
            )
            do {
                let session = try await SB.client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: token, nonce: nonce)
                )
                await persistSignedInProfile(userId: session.user.id, profile: named)
                state = .signedIn(userId: session.user.id)
                return named
            } catch {
                state = .error(error.localizedDescription)
                return nil
            }
        }
    }

    /// Signs out, clears local Supabase session.
    func signOut() async {
        if UITesting.blocksNetwork {
            state = .signedOut
            emailLinkSent = nil
            return
        }
        try? await SB.client.auth.signOut()
        state = .signedOut
        emailLinkSent = nil
    }

    /// v1.4.5 — permanent account deletion. Required by Apple App Review
    /// guideline 5.1.1(v): apps that allow account creation must allow
    /// in-app account deletion (emailing support is NOT enough).
    ///
    /// Calls the Postgres RPC `delete_my_account()` which deletes:
    ///   - public.users row + the auth.users row (cascades to identities)
    ///   - couple row I'm in (partner is dropped back to unpaired)
    ///   - all my messages / entries / anniversaries / play_history rows
    /// The RPC runs as security definer using auth.uid().
    /// On success: signs out locally, returns true. Caller routes to
    /// onboarding/sign-in.
    func deleteAccount() async -> Bool {
        if UITesting.blocksNetwork {
            state = .error("UI test mode does not delete accounts.")
            return false
        }
        do {
            try await SB.client.rpc("delete_my_account").execute()
            // Even though the RPC nuked the auth row, our session is now
            // invalid; explicit signOut clears the local session token.
            try? await SB.client.auth.signOut()
            state = .signedOut
            emailLinkSent = nil
            return true
        } catch {
            state = .error("刪除帳戶失敗：\(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Email magic link (Phase 8 v0.8.0)
    //
    // Apple's App Review rule: any app that offers a third-party social
    // login MUST also offer Sign in with Apple. We have Sign in with Apple
    // already; adding email magic link satisfies users who want a non-Apple
    // option (e.g. Joan's account uses Gmail). Supabase Email auth provider
    // handles delivery of the OTP email; the user clicks the link in their
    // inbox which redirects back to the app via Universal Links (Phase 8b)
    // or by entering the 6-digit OTP shown in the email.

    /// Sends a one-time password email to the address. Returns true if the
    /// OTP was dispatched, false on error.
    func sendEmailOTP(to email: String) async -> Bool {
        if UITesting.blocksNetwork {
            state = .error("UI test mode does not send email codes.")
            return false
        }
        let trimmed = email.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty, trimmed.contains("@") else {
            state = .error("唔似一個 email 地址喎")
            return false
        }
        do {
            try await SB.client.auth.signInWithOTP(
                email: trimmed,
                shouldCreateUser: true
            )
            emailLinkSent = trimmed
            return true
        } catch {
            state = .error(error.localizedDescription)
            return false
        }
    }

    /// Verifies the 6-digit OTP code the user typed in (or that arrived via
    /// magic link). On success: same user-row upsert as the Apple flow.
    func verifyEmailOTP(email: String, code: String, profile: UserProfile) async {
        if UITesting.blocksNetwork {
            state = .error("UI test mode does not verify email codes.")
            return
        }
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedCode  = code.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let session = try await SB.client.auth.verifyOTP(
                email: trimmedEmail,
                token: trimmedCode,
                type: .email
            )
            await persistSignedInProfile(userId: session.user.id, profile: profile)
            emailLinkSent = nil
            state = .signedIn(userId: session.user.id)
        } catch {
            state = .error(error.localizedDescription)
        }
    }

    /// Cancel a pending email-link flow (user wants to try a different
    /// email or switch back to Apple sign-in).
    func cancelEmailFlow() {
        emailLinkSent = nil
    }

    // MARK: - Profile upsert

    /// Writes the signed-in user's own `my_name`. A failed full-row upsert
    /// (empty anniversary used to be sent as `""`, which a `date` column
    /// rejects) must not drop the name: the column update still runs.
    /// Session restore never re-enters sign-in, so launch and foreground
    /// call `publishMyName` again with the name already stored on device.
    private func persistSignedInProfile(userId: UUID, profile: UserProfile) async {
        do {
            try await upsertProfile(userId: userId, profile: profile)
        } catch {
            authLog.error("profile upsert failed: \(error.localizedDescription, privacy: .public)")
        }
        _ = await publishMyName(profile.myName)
    }

    /// UPDATE `users.my_name` for the signed-in row only. RLS `users_update_self`
    /// is `id = auth.uid()`. Placeholders 「我」 / 「對方」 are not written.
    /// `kk_ensure_profile()` inserts those defaults when the row is missing
    /// and does not change an existing name, so the UPDATE has to follow it.
    @discardableResult
    func publishMyName(_ raw: String) async -> Bool {
        guard let name = CoupleNames.persistable(raw) else { return false }
        if UITesting.blocksNetwork { return true }
        guard let userId = SB.client.auth.currentUser?.id else { return false }
        return await writeMyName(name, userId: userId)
    }

    private func writeMyName(_ name: String, userId: UUID) async -> Bool {
        guard CoupleNames.persistable(name) != nil else { return false }
        guard SB.client.auth.currentUser?.id == userId else { return false }
        do {
            _ = try await SB.client.rpc("kk_ensure_profile").execute()
            struct Patch: Encodable {
                let myName: String
                enum CodingKeys: String, CodingKey { case myName = "my_name" }
            }
            try await SB.client
                .from("users")
                .update(Patch(myName: name))
                .eq("id", value: userId)
                .execute()
            return true
        } catch {
            authLog.error("my_name update failed: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }

    /// Publishes this device's X25519 public key via `kk_set_public_key`.
    /// That RPC calls `kk_ensure_profile()` before the update, so a restored
    /// session (which never re-ran the sign-in upsert) still gets a row.
    /// A thrown `invalid_public_key` / `profile_missing` / `not_authenticated`
    /// stays on `publicKeyFailure` for the Cantonese banner. Success does
    /// not mean the partner key is ready.
    @discardableResult
    func ensurePublicKeyUploaded(userId: UUID) async -> PublicKeyPublish {
        if UITesting.blocksNetwork { return .skipped }
        if SB.client.auth.currentUser?.id != userId {
            ownPublicKeyOnServer = false
            publicKeyFailure = .notAuthenticated
            return .writeFailed
        }
        do {
            let publicKey = try KeyManager.shared.myPublicKeyBase64()
            struct Args: Encodable { let p_public_key: String }
            _ = try await SB.client
                .rpc("kk_set_public_key", params: Args(p_public_key: publicKey))
                .execute()
            ownPublicKeyOnServer = true
            publicKeyFailure = nil
            return .published
        } catch {
            ownPublicKeyOnServer = false
            publicKeyFailure = RPCUserFacing.failure(for: error)
            authLog.error("kk_set_public_key failed: \(error.localizedDescription, privacy: .public)")
            return .writeFailed
        }
    }

    /// Upserts the user row including the device's X25519 public key. The
    /// private key never leaves the device. Session restore does not call
    /// this — `ensurePublicKeyUploaded` covers that path.
    private func upsertProfile(userId: UUID, profile: UserProfile) async throws {
        let publicKey = try KeyManager.shared.myPublicKeyBase64()
        let row = UserProfileUpsert(userId: userId, profile: profile, publicKey: publicKey)
        try await SB.client
            .from("users")
            .upsert(row)
            .execute()
    }

    // MARK: - Nonce helpers

    /// Cryptographically secure random alphanumeric nonce. Apple recommends
    /// a 32-char nonce.
    private static func randomNonceString(length: Int = 32) -> String {
        let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remaining = length
        while remaining > 0 {
            var bytes = [UInt8](repeating: 0, count: 16)
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            for byte in bytes where remaining > 0 {
                if byte < charset.count {
                    result.append(charset[Int(byte)])
                    remaining -= 1
                }
            }
        }
        return result
    }

    /// SHA-256(nonce) — what we send to Apple. Apple includes the *unhashed*
    /// nonce inside the identity token; Supabase verifies SHA256(returned) ==
    /// the value in token.
    private static func sha256(_ input: String) -> String {
        let data = Data(input.utf8)
        let hash = SHA256.hash(data: data)
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}
