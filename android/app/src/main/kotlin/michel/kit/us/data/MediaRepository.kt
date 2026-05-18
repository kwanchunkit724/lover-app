package michel.kit.us.data

import io.github.jan.supabase.storage.storage
import java.security.SecureRandom
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Encrypt + upload + download + decrypt for chat media (photos, voice).
 *
 * Port of ios/LoverApp/Services/MediaService.swift. Wire format MUST be
 * byte-identical to iOS so a photo encrypted by iOS round-trips to Android
 * and vice versa.
 *
 *   Bucket   : "chat-media"
 *   Path     : "couple-<lowercase-uuid>/<lowercase-uuid>.bin"
 *   Payload  : [12-byte nonce | ciphertext | 16-byte GCM tag]
 *              (same AES-GCM SealedBox.combined layout as text messages —
 *              CryptoKit's `AES.GCM.seal(...).combined` on iOS)
 *
 * Key is the same per-couple `chatKey` derived in [CryptoService] (X25519
 * ECDH + HKDF-SHA256).
 */
class MediaRepository(
    private val crypto: CryptoService
) {
    private val client = SupabaseClient.instance
    private val bucket = "chat-media"

    /**
     * Encrypts [plaintext] with the shared chat key, uploads to Supabase
     * Storage, returns the path (mediaHandle) to embed in
     * ChatPayload.mediaHandle.
     */
    suspend fun uploadEncrypted(plaintext: ByteArray, coupleId: UUID): String {
        val sealed = sealRaw(plaintext)
        val path = "couple-${coupleId.toString().lowercase()}/${UUID.randomUUID().toString().lowercase()}.bin"
        client.storage.from(bucket).upload(path = path, data = sealed) {
            upsert = false
            contentType = io.ktor.http.ContentType.parse("application/octet-stream")
        }
        return path
    }

    /** Downloads the ciphertext blob and decrypts it with the chat key. */
    suspend fun downloadAndDecrypt(path: String): ByteArray {
        val cipher = client.storage.from(bucket).downloadAuthenticated(path)
        return openRaw(cipher)
    }

    // -----------------------------------------------------------------------
    // Raw seal/open — CryptoService.seal/open work on JSON-encoded
    // ChatPayload envelopes. Media files are arbitrary bytes, so we run
    // AES-GCM directly with the shared chat key. Layout matches CryptoKit
    // AES.GCM.SealedBox.combined exactly: [12B nonce | ct | 16B tag].

    private fun sealRaw(plaintext: ByteArray): ByteArray {
        val key = crypto.chatKeyBytesOrNull() ?: throw CryptoService.CryptoError.NotReady
        val nonce = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
        val ctAndTag = cipher.doFinal(plaintext)
        val combined = ByteArray(nonce.size + ctAndTag.size)
        System.arraycopy(nonce, 0, combined, 0, nonce.size)
        System.arraycopy(ctAndTag, 0, combined, nonce.size, ctAndTag.size)
        return combined
    }

    private fun openRaw(combined: ByteArray): ByteArray {
        val key = crypto.chatKeyBytesOrNull() ?: throw CryptoService.CryptoError.NotReady
        if (combined.size < 12 + 16) throw CryptoService.CryptoError.OpenFailed(null)
        val nonce = combined.copyOfRange(0, 12)
        val rest = combined.copyOfRange(12, combined.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
        return cipher.doFinal(rest)
    }
}
