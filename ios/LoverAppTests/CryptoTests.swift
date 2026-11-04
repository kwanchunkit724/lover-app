import XCTest
import CryptoKit
@testable import Us

/// Pure crypto tests — no Keychain, no Supabase, no MainActor CryptoService.prepare.
/// Exercises the same AES-GCM + HKDF + X25519 path the production seal/open uses.
final class CryptoTests: XCTestCase {

    // MARK: - Helpers

    private func deriveChatKey(
        myPriv: Curve25519.KeyAgreement.PrivateKey,
        partnerPub: Curve25519.KeyAgreement.PublicKey,
        coupleId: UUID
    ) -> SymmetricKey {
        let shared = try! myPriv.sharedSecretFromKeyAgreement(with: partnerPub)
        let salt = Data(coupleId.uuidString.utf8) // UUID.uuidString is UPPERCASE
        let info = Data("us.chat.v1".utf8)
        return shared.hkdfDerivedSymmetricKey(
            using: SHA256.self,
            salt: salt,
            sharedInfo: info,
            outputByteCount: 32
        )
    }

    private func seal(_ payload: ChatPayload, key: SymmetricKey) throws -> String {
        let plaintext = try JSONEncoder.iso.encode(payload)
        let sealed = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealed.combined else {
            XCTFail("AES.GCM.seal returned nil combined")
            throw CryptoService.CryptoError.sealFailed
        }
        return combined.base64EncodedString()
    }

    // MARK: - Round-trip

    func test_aesGcm_roundTrip_textPayload() throws {
        let key = SymmetricKey(size: .bits256)
        let original = ChatPayload.text("hello 我哋 ❤")
        let cipher = try seal(original, key: key)
        let opened = try CryptoService.open(cipher, key: key)
        XCTAssertEqual(opened.kind, .text)
        XCTAssertEqual(opened.text, "hello 我哋 ❤")
        XCTAssertEqual(opened.v, 1)
    }

    func test_aesGcm_roundTrip_photoPayload() throws {
        let key = SymmetricKey(size: .bits256)
        let payload = ChatPayload(kind: .photo, text: nil, mediaHandle: "chat-media/abc.jpg", sentAt: Date())
        let cipher = try seal(payload, key: key)
        let opened = try CryptoService.open(cipher, key: key)
        XCTAssertEqual(opened.kind, .photo)
        XCTAssertEqual(opened.mediaHandle, "chat-media/abc.jpg")
    }

    func test_aesGcm_roundTrip_videoPayload_durationInText() throws {
        let key = SymmetricKey(size: .bits256)
        // Wire format: video/voice duration lives in `text` as "0:NN"
        let payload = ChatPayload(kind: .video, text: "0:12", mediaHandle: "chat-media/clip.mp4", sentAt: Date())
        let cipher = try seal(payload, key: key)
        let opened = try CryptoService.open(cipher, key: key)
        XCTAssertEqual(opened.kind, .video)
        XCTAssertEqual(opened.text, "0:12")
        XCTAssertEqual(opened.mediaHandle, "chat-media/clip.mp4")
    }

    // MARK: - Cross-key (both sides of pair)

    func test_x25519_hkdf_bothSidesDeriveIdenticalKey() throws {
        let alice = Curve25519.KeyAgreement.PrivateKey()
        let bob = Curve25519.KeyAgreement.PrivateKey()
        let coupleId = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!

        let aliceKey = deriveChatKey(myPriv: alice, partnerPub: bob.publicKey, coupleId: coupleId)
        let bobKey = deriveChatKey(myPriv: bob, partnerPub: alice.publicKey, coupleId: coupleId)

        // SymmetricKey has no Equatable; compare via sealing
        let payload = ChatPayload.text("from alice")
        let cipher = try seal(payload, key: aliceKey)
        let opened = try CryptoService.open(cipher, key: bobKey)
        XCTAssertEqual(opened.text, "from alice")
    }

    func test_hkdf_salt_usesUppercaseUUID() throws {
        // Swift UUID.uuidString is uppercase; a lowercase salt must NOT match.
        let alice = Curve25519.KeyAgreement.PrivateKey()
        let bob = Curve25519.KeyAgreement.PrivateKey()
        let upper = "ABCDEF12-3456-7890-ABCD-EF1234567890"
        let lower = upper.lowercased()

        let shared = try alice.sharedSecretFromKeyAgreement(with: bob.publicKey)
        let info = Data("us.chat.v1".utf8)
        let keyUpper = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: Data(upper.utf8), sharedInfo: info, outputByteCount: 32)
        let keyLower = shared.hkdfDerivedSymmetricKey(
            using: SHA256.self, salt: Data(lower.utf8), sharedInfo: info, outputByteCount: 32)

        let payload = ChatPayload.text("salt probe")
        let cipher = try seal(payload, key: keyUpper)
        // Wrong-case salt → different key → open must fail
        XCTAssertThrowsError(try CryptoService.open(cipher, key: keyLower))
    }

    // MARK: - Tamper / wrong key / garbage

    func test_tamperedCiphertext_throws() throws {
        let key = SymmetricKey(size: .bits256)
        let cipher = try seal(ChatPayload.text("secret"), key: key)
        guard var bytes = Data(base64Encoded: cipher), bytes.count > 20 else {
            return XCTFail("unexpected cipher length")
        }
        // Flip a bit past the 12-byte nonce, inside ciphertext/tag.
        bytes[20] ^= 0x01
        let tampered = bytes.base64EncodedString()
        XCTAssertThrowsError(try CryptoService.open(tampered, key: key))
    }

    func test_wrongKey_throws() throws {
        let keyA = SymmetricKey(size: .bits256)
        let keyB = SymmetricKey(size: .bits256)
        let cipher = try seal(ChatPayload.text("nope"), key: keyA)
        XCTAssertThrowsError(try CryptoService.open(cipher, key: keyB))
    }

    func test_invalidBase64_throws() {
        let key = SymmetricKey(size: .bits256)
        XCTAssertThrowsError(try CryptoService.open("%%%not-base64%%%", key: key)) { err in
            guard case CryptoService.CryptoError.invalidBase64 = err else {
                return XCTFail("expected invalidBase64, got \(err)")
            }
        }
    }

    func test_truncatedCombined_throws() {
        let key = SymmetricKey(size: .bits256)
        // 4 random bytes — shorter than nonce+tag minimum
        let short = Data([0x01, 0x02, 0x03, 0x04]).base64EncodedString()
        XCTAssertThrowsError(try CryptoService.open(short, key: key))
    }

    // MARK: - Public key decode

    func test_decodePublicKey_roundTrip() throws {
        let priv = Curve25519.KeyAgreement.PrivateKey()
        let b64 = priv.publicKey.rawRepresentation.base64EncodedString()
        let decoded = try KeyManager.decodePublicKey(base64: b64)
        XCTAssertEqual(decoded.rawRepresentation, priv.publicKey.rawRepresentation)
    }

    func test_decodePublicKey_invalidBase64_throws() {
        XCTAssertThrowsError(try KeyManager.decodePublicKey(base64: "!!!"))
    }

    // MARK: - ChatPayload Codable

    func test_chatPayload_jsonRoundTrip_allKinds() throws {
        let kinds: [ChatPayload.Kind] = [.text, .kaomoji, .photo, .voice, .video]
        for kind in kinds {
            let original = ChatPayload(kind: kind, text: "x", mediaHandle: "h", sentAt: Date(timeIntervalSince1970: 1_700_000_000))
            let data = try JSONEncoder.iso.encode(original)
            let decoded = try JSONDecoder.iso.decode(ChatPayload.self, from: data)
            XCTAssertEqual(decoded.kind, kind)
            XCTAssertEqual(decoded.text, "x")
            XCTAssertEqual(decoded.mediaHandle, "h")
            XCTAssertEqual(decoded.v, 1)
        }
    }
}
