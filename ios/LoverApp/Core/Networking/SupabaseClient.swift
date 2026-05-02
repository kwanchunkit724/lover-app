import Foundation

/// Thin wrapper over the supabase-swift SDK. Defines our app's networking surface.
/// Centralising it here means crypto, retry, and offline behaviour live in one place
/// rather than scattered across feature modules.
///
/// Real implementation will depend on the supabase-swift package
/// (https://github.com/supabase/supabase-swift). This file declares the contract
/// our features code against.
protocol BackendClient: Sendable {
    func currentUserId() async -> UUID?

    func signInWithApple(idToken: String, nonce: String) async throws -> AuthSession

    func uploadPublicKey(_ publicKey: Data) async throws

    func createInvite() async throws -> InviteHandle

    func redeemInvite(code: String) async throws -> RedeemedInvite

    func sendMessage(_ message: OutgoingMessage) async throws -> SentMessage

    func subscribeMessages(coupleId: UUID) -> AsyncStream<RemoteMessage>

    func uploadMedia(ciphertext: Data, contentType: String) async throws -> MediaHandle

    func unpair() async throws
}

struct AuthSession: Sendable {
    let userId: UUID
    let accessToken: String
    let refreshToken: String
    let expiresAt: Date
}

struct InviteHandle: Sendable {
    let coupleId: UUID
    let code: String
    let expiresAt: Date
    let shareURL: URL
}

struct RedeemedInvite: Sendable {
    let coupleId: UUID
    let partnerUserId: UUID
    let partnerPublicKey: Data
}

struct OutgoingMessage: Sendable {
    enum Kind: String, Sendable { case text, kaomoji, image, audio }
    let coupleId: UUID
    let kind: Kind
    let ciphertext: Data
    let nonce: Data
    let tag: Data
}

struct SentMessage: Sendable {
    let id: UUID
    let createdAt: Date
}

struct RemoteMessage: Sendable {
    let id: UUID
    let coupleId: UUID
    let senderId: UUID
    let kind: String
    let ciphertext: Data
    let nonce: Data
    let tag: Data
    let createdAt: Date
}

struct MediaHandle: Sendable {
    let id: UUID
    let storagePath: String
}
