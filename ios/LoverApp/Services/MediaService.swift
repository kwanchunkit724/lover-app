import Foundation
import CryptoKit
import Supabase

// Phase 4c — encrypt + upload + download + decrypt for chat media (photos
// for v0.4.2; voice + video sit in this same surface when wired).
//
// Object naming: "couple-{couple_id}/{uuid}.bin"
// Object payload: AES-GCM SealedBox.combined of the original file bytes,
// using the same chat key derived in CryptoService.

@MainActor
final class MediaService {

    private let crypto: CryptoService
    private let bucket = "chat-media"

    init(crypto: CryptoService) {
        self.crypto = crypto
    }

    /// Encrypts data, uploads it to Storage, returns the path (mediaHandle)
    /// to embed in ChatPayload.mediaHandle.
    func encryptAndUpload(data: Data, coupleId: UUID) async throws -> String {
        guard let key = crypto.chatKey else { throw CryptoService.CryptoError.notReady }
        let sealed = try seal(data, with: key)
        let path = "couple-\(coupleId.uuidString.lowercased())/\(UUID().uuidString.lowercased()).bin"
        try await SB.client.storage.from(bucket).upload(
            path: path,
            file: sealed,
            options: .init(contentType: "application/octet-stream", upsert: false)
        )
        return path
    }

    /// Downloads the ciphertext blob and decrypts it with the chat key.
    func downloadAndDecrypt(path: String) async throws -> Data {
        guard let key = crypto.chatKey else { throw CryptoService.CryptoError.notReady }
        let cipher = try await SB.client.storage.from(bucket).download(path: path)
        return try open(cipher, with: key)
    }

    // MARK: - Raw seal/open helpers — CryptoService handles JSON envelopes;
    // these handle arbitrary file bytes.

    private func seal(_ data: Data, with key: SymmetricKey) throws -> Data {
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw CryptoService.CryptoError.sealFailed
        }
        return combined
    }

    private func open(_ combined: Data, with key: SymmetricKey) throws -> Data {
        let box = try AES.GCM.SealedBox(combined: combined)
        return try AES.GCM.open(box, using: key)
    }
}
