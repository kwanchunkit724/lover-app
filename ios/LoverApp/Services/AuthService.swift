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
    }

    // MARK: - Profile upsert

    private struct UserRow: Codable {
        let id: UUID
        let myName: String
        let partnerName: String
        let anniversaryISO: String
        let themeId: String

        enum CodingKeys: String, CodingKey {
            case id
            case myName        = "my_name"
            case partnerName   = "partner_name"
            case anniversaryISO = "anniversary_iso"
            case themeId       = "theme_id"
        }
    }

    private func upsertProfile(userId: UUID, profile: UserProfile) async throws {
        let row = UserRow(
            id: userId,
            myName: profile.myName,
            partnerName: profile.partnerName,
            anniversaryISO: profile.anniversaryISO,
            themeId: profile.themeId
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
