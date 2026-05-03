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
        case text, kaomoji, photo, voice
    }

    static func text(_ t: String) -> ChatPayload {
        ChatPayload(kind: .text, text: t, mediaHandle: nil, sentAt: Date())
    }
}

@MainActor
final class CryptoService {

    /// Derived shared key for the active couple. nil until both sides have
    /// uploaded a public_key AND we've called `prepare(couple:partner:)`.
    private(set) var chatKey: SymmetricKey?

    /// Computes the chat key from my private key + partner's public key +
    /// couple_id (used as salt). Idempotent; safe to call multiple times.
    /// Throws if partner.public_key is missing or invalid.
    func prepare(coupleId: UUID, partner: PairingService.PartnerRow) throws {
        guard let pubB64 = partner.publicKey else {
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
    }

    func reset() {
        chatKey = nil
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
