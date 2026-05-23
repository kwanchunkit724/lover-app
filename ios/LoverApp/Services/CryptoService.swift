import Foundation
import CryptoKit

// Symmetric chat-channel key derivation + AES-GCM seal/open.
//
// At pair time both sides know each other's X25519 public key (via users
// table). Each side computes:
//
//     shared = ECDH(my_priv, partner_pub)
//     chatKey = HKDF-SHA256(shared, salt=couple_id, info="us.chat.v1", 32 bytes)
//
// Both sides arrive at identical 32-byte chatKey.
//
// Encrypted message blob layout (sent as base64 in messages.ciphertext_b64):
//     SealedBox.combined = [12-byte nonce | ciphertext | 16-byte tag]
//
// Plaintext is the JSON-encoded ChatPayload (versioned envelope so Phase
// 4b can add photo/voice without a schema migration).

struct ChatPayload: Codable, Equatable {
    var v: Int = 1
    var kind: Kind
    var text: String?
    var mediaHandle: String?     // Phase 4b — Supabase storage path
    var sentAt: Date

    enum Kind: String, Codable, Equatable {
        // v1.6.0 — `video` added for in-chat short video send (mirrors photo
        // path, reuses MediaService.encryptAndUpload + chat-media bucket).
        // Lowercase wire string shared with Android; do NOT rename without a
        // corresponding Android wire-format change.
        case text, kaomoji, photo, voice, video
    }

    static func text(_ t: String) -> ChatPayload {
        ChatPayload(kind: .text, text: t, mediaHandle: nil, sentAt: Date())
    }
}

@MainActor
final class CryptoService: ObservableObject {

    /// Derived shared key for the active couple. nil until both sides have
    /// uploaded a public_key AND we've called `prepare(couple:partner:)`.
    private(set) var chatKey: SymmetricKey?
    /// v1.3.2 — published mirror of (chatKey != nil) so SwiftUI can react.
    /// Without this the chat view had no way to tell "still preparing" from
    /// "ready to send", and a tap on send while !ready silently dropped
    /// the message at the seal step.
    @Published private(set) var isReady: Bool = false
    /// v1.3.2 — surfaces the most recent prepare attempt's error so the
    /// chat view can render something specific instead of a generic banner.
    @Published var lastPrepareError: String?

    /// Computes the chat key from my private key + partner's public key +
    /// couple_id (used as salt). Idempotent; safe to call multiple times.
    /// Throws if partner.public_key is missing or invalid.
    func prepare(coupleId: UUID, partner: PairingService.PartnerRow) throws {
        do {
            guard let pubB64 = partner.publicKey, !pubB64.isEmpty else {
                throw CryptoError.partnerKeyMissing
            }
            let myPriv = try KeyManager.shared.myPrivateKey()
            let partnerPub = try KeyManager.decodePublicKey(base64: pubB64)
            let shared = try myPriv.sharedSecretFromKeyAgreement(with: partnerPub)
            let salt = Data(coupleId.uuidString.utf8)
            let info = Data("us.chat.v1".utf8)
            chatKey = shared.hkdfDerivedSymmetricKey(
                using: SHA256.self,
                salt: salt,
                sharedInfo: info,
                outputByteCount: 32
            )
            isReady = true
            lastPrepareError = nil
        } catch {
            lastPrepareError = String(describing: error)
            throw error
        }
    }

    func reset() {
        chatKey = nil
        isReady = false
    }

    // MARK: - Seal / open

    /// Encrypts a ChatPayload, returns base64-encoded SealedBox.combined.
    func seal(_ payload: ChatPayload) throws -> String {
        guard let key = chatKey else { throw CryptoError.notReady }
        let plaintext = try JSONEncoder.iso.encode(payload)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else { throw CryptoError.sealFailed }
        return combined.base64EncodedString()
    }

    /// Decrypts a base64-encoded SealedBox.combined back into a ChatPayload.
    /// Throws on tamper / wrong key / decode failure — caller should render a
    /// "(decryption failed)" placeholder rather than dropping the message.
    func open(_ ciphertextB64: String) throws -> ChatPayload {
        guard let key = chatKey else { throw CryptoError.notReady }
        guard let combined = Data(base64Encoded: ciphertextB64) else {
            throw CryptoError.invalidBase64
        }
        let box = try AES.GCM.SealedBox(combined: combined)
        let plain = try AES.GCM.open(box, using: key)
        return try JSONDecoder.iso.decode(ChatPayload.self, from: plain)
    }

    // MARK: - Errors

    enum CryptoError: Error {
        case partnerKeyMissing
        case notReady
        case invalidBase64
        case sealFailed
    }
}

// MARK: - JSON ISO date helpers

extension JSONEncoder {
    static let iso: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()
}

extension JSONDecoder {
    static let iso: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}
