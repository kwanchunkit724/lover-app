import Foundation
import AuthenticationServices
import CryptoKit
import Supabase

// Native Sign in with Apple → Supabase. Apple gives us an identityToken (a
// signed JWT containing the user's stable Apple ID). We pass it to Supabase
// Auth's signInWithIdToken, which validates the JWT against Apple's public
// keys and returns a Supabase session.
//
// Phase 3a scope: just sign in. The first time a user signs in, we also
// upsert a row into public.users using the local UserProfile (collected during
// onboarding). Phase 3b layers on the pairing flow.

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

    @Published private(set) var state: State = .unknown

    /// Random nonce used for the current Sign-in-with-Apple request. Apple
    /// echoes it in the identityToken so we can detect replay attacks.
    private var currentNonce: String?

    // MARK: - Session bootstrap

    /// Called on app launch. If a previous session exists in the keychain,
    /// transition to .signedIn; otherwise .signedOut.
    func bootstrap() async {
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
    /// and (if first sign-in) upserts the public.users row from the local
    /// UserProfile. On failure: surfaces an error string.
    func handleAppleResult(_ result: Result<ASAuthorization, Error>,
                           profile: UserProfile) async {
        switch result {
        case .failure(let error):
            // User cancelled is harmless; everything else surfaces.
            if (error as? ASAuthorizationError)?.code == .canceled { return }
            state = .error(error.localizedDescription)

        case .success(let auth):
            guard let nonce = currentNonce else {
                state = .error("missing nonce")
                return
            }
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential,
                  let tokenData = credential.identityToken,
                  let token = String(data: tokenData, encoding: .utf8) else {
                state = .error("missing identity token")
                return
            }

            do {
                let session = try await SB.client.auth.signInWithIdToken(
                    credentials: .init(provider: .apple, idToken: token, nonce: nonce)
                )
                try await upsertProfile(userId: session.user.id, profile: profile)
                state = .signedIn(userId: session.user.id)
            } catch {
                state = .error(error.localizedDescription)
            }
        }
    }

    /// Signs out, clears local Supabase session.
    func signOut() async {
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
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        let trimmedCode  = code.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let session = try await SB.client.auth.verifyOTP(
                email: trimmedEmail,
                token: trimmedCode,
                type: .email
            )
            try await upsertProfile(userId: session.user.id, profile: profile)
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

    private struct UserRow: Codable {
        let id: UUID
        let myName: String
        let partnerName: String
        let anniversaryISO: String
        let themeId: String
        let publicKey: String

        enum CodingKeys: String, CodingKey {
            case id
            case myName        = "my_name"
            case partnerName   = "partner_name"
            case anniversaryISO = "anniversary_iso"
            case themeId       = "theme_id"
            case publicKey     = "public_key"
        }
    }

    /// Upserts the user row including the device's X25519 public key. The
    /// private key never leaves the device. If a partner is already paired
    /// before this device's public_key was uploaded, the partner's chat
    /// derivation will fail until they refresh the partner row.
    private func upsertProfile(userId: UUID, profile: UserProfile) async throws {
        let publicKey = try KeyManager.shared.myPublicKeyBase64()
        let row = UserRow(
            id: userId,
            myName: profile.myName,
            partnerName: profile.partnerName,
            anniversaryISO: profile.anniversaryISO,
            themeId: profile.themeId,
            publicKey: publicKey
        )
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
