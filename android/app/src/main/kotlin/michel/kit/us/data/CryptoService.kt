package michel.kit.us.data

import android.util.Base64
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import org.bouncycastle.crypto.agreement.X25519Agreement
import org.bouncycastle.crypto.digests.SHA256Digest
import org.bouncycastle.crypto.generators.HKDFBytesGenerator
import org.bouncycastle.crypto.params.HKDFParameters
import org.bouncycastle.crypto.params.X25519PrivateKeyParameters
import org.bouncycastle.crypto.params.X25519PublicKeyParameters
import java.security.SecureRandom
import java.util.UUID
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * Symmetric chat-channel key derivation + AES-GCM seal/open.
 *
 * Mirror of ios/LoverApp/Services/CryptoService.swift. Wire format MUST be
 * byte-identical to the iOS implementation:
 *
 *     shared    = ECDH(my_priv, partner_pub)            // X25519, 32 raw bytes
 *     chatKey   = HKDF-SHA256(
 *                     ikm   = shared,
 *                     salt  = UTF-8(couple_id.uppercase UUID string),
 *                     info  = UTF-8("us.chat.v1"),
 *                     L     = 32
 *                 )
 *
 * Encrypted blob (stored as base64 in `messages.ciphertext_b64`):
 *
 *     [ 12-byte nonce | ciphertext | 16-byte GCM tag ]
 *
 * The plaintext is the JSON encoding of [ChatPayload] using ISO-8601 dates.
 *
 * CRITICAL — iOS CryptoKit's `UUID.uuidString` returns UPPERCASE
 * (e.g. "550E8400-E29B-41D4-A716-446655440000"). [SupabaseClient] sends UUIDs
 * to Postgres which stores them as lowercase, but iOS builds the HKDF salt
 * from the in-memory UUID — and `UUID.uuidString` is documented uppercase.
 * Android's [UUID.toString] is documented LOWERCASE. We force uppercase here
 * to match iOS.
 *
 * Verified test vector: a message produced by iOS CryptoKit must round-trip
 * through Android, and vice versa. See PHASE-A.md "Wire compatibility test".
 */
@Serializable
data class ChatPayload(
    val v: Int = 1,
    val kind: Kind,
    val text: String? = null,
    val mediaHandle: String? = null,
    // v1.6.0 — duration in seconds for voice + video kinds. Replaces the
    // legacy "text=0:NN" duration hack. Both platforms must agree on the
    // field name.
    val voiceDurationSec: Int? = null,
    val sentAt: String  // ISO-8601 UTC, matches Swift JSONEncoder.dateEncodingStrategy = .iso8601
) {
    @Serializable
    enum class Kind { text, kaomoji, photo, voice, video }

    companion object {
        fun text(t: String): ChatPayload = ChatPayload(
            kind = Kind.text,
            text = t,
            sentAt = IsoDate.now()
        )
    }
}

class CryptoService {

    private val _isReady = MutableStateFlow(false)
    val isReady: StateFlow<Boolean> = _isReady.asStateFlow()

    private val _lastPrepareError = MutableStateFlow<String?>(null)
    val lastPrepareError: StateFlow<String?> = _lastPrepareError.asStateFlow()

    @Volatile
    private var chatKey: ByteArray? = null

    /**
     * Internal accessor for [MediaRepository] which needs the raw key to
     * AES-GCM-seal arbitrary file bytes (photos / voice) outside the
     * ChatPayload JSON envelope. Returns null when crypto not ready.
     */
    internal fun chatKeyBytesOrNull(): ByteArray? = chatKey

    /** JSON encoder shared with [ChatPayload]; matches iOS JSONEncoder.iso. */
    private val json = Json {
        ignoreUnknownKeys = true
        explicitNulls = false  // iOS .iso encoder omits nil fields
        encodeDefaults = true
    }

    sealed class CryptoError(msg: String) : RuntimeException(msg) {
        object PartnerKeyMissing : CryptoError("partner key missing")
        object NotReady : CryptoError("crypto not ready")
        object InvalidBase64 : CryptoError("invalid base64")
        object SealFailed : CryptoError("seal failed")
        class OpenFailed(cause: Throwable?) : CryptoError("open failed: ${cause?.message}")
    }

    /**
     * Computes the chat key from my private key + partner's public key +
     * couple_id (used as HKDF salt). Idempotent.
     *
     * @param coupleId The couple UUID. Will be uppercased to match iOS exactly.
     * @param partnerPublicKeyBase64 base64(rawX25519PublicKey32) from partner's users row.
     * @param myPrivateKey 32-byte raw X25519 private key from [KeyManager].
     */
    fun prepare(
        coupleId: UUID,
        partnerPublicKeyBase64: String?,
        myPrivateKey: ByteArray
    ) {
        try {
            if (partnerPublicKeyBase64.isNullOrEmpty()) {
                throw CryptoError.PartnerKeyMissing
            }
            val partnerPubRaw = Base64.decode(partnerPublicKeyBase64, Base64.NO_WRAP)
            if (partnerPubRaw.size != X25519PublicKeyParameters.KEY_SIZE) {
                throw CryptoError.PartnerKeyMissing
            }
            val shared = x25519SharedSecret(myPrivateKey, partnerPubRaw)
            val salt = coupleId.toString().uppercase().toByteArray(Charsets.UTF_8)
            val info = "us.chat.v1".toByteArray(Charsets.UTF_8)
            chatKey = hkdfSha256(ikm = shared, salt = salt, info = info, length = 32)
            _isReady.value = true
            _lastPrepareError.value = null
        } catch (t: Throwable) {
            _lastPrepareError.value = t.toString()
            chatKey = null
            _isReady.value = false
            throw t
        }
    }

    fun reset() {
        chatKey?.fill(0)
        chatKey = null
        _isReady.value = false
    }

    /** Encrypts a [ChatPayload], returns base64(nonce || ct || tag). */
    fun seal(payload: ChatPayload): String {
        val key = chatKey ?: throw CryptoError.NotReady
        val plaintext = json.encodeToString(ChatPayload.serializer(), payload).toByteArray(Charsets.UTF_8)
        val nonce = ByteArray(12).also { SecureRandom().nextBytes(it) }
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
        val ctAndTag = cipher.doFinal(plaintext)  // ciphertext || 16-byte tag
        val combined = ByteArray(nonce.size + ctAndTag.size)
        System.arraycopy(nonce, 0, combined, 0, nonce.size)
        System.arraycopy(ctAndTag, 0, combined, nonce.size, ctAndTag.size)
        return Base64.encodeToString(combined, Base64.NO_WRAP)
    }

    /** Decrypts a base64 SealedBox.combined back into a [ChatPayload]. */
    fun open(ciphertextB64: String): ChatPayload {
        val key = chatKey ?: throw CryptoError.NotReady
        val combined = try {
            Base64.decode(ciphertextB64, Base64.NO_WRAP)
        } catch (t: Throwable) {
            throw CryptoError.InvalidBase64
        }
        if (combined.size < 12 + 16) throw CryptoError.OpenFailed(null)
        val nonce = combined.copyOfRange(0, 12)
        val rest  = combined.copyOfRange(12, combined.size)  // ct + 16-byte tag
        return try {
            val cipher = Cipher.getInstance("AES/GCM/NoPadding")
            cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
            val plain = cipher.doFinal(rest)
            json.decodeFromString(ChatPayload.serializer(), String(plain, Charsets.UTF_8))
        } catch (t: Throwable) {
            throw CryptoError.OpenFailed(t)
        }
    }

    // ---------------------------------------------------------------------
    // X25519 ECDH via BouncyCastle. CryptoKit's
    // `sharedSecretFromKeyAgreement` returns the raw 32-byte X25519 output
    // (no HKDF, no curve encoding) — same as BouncyCastle's X25519Agreement.
    // Test vector: RFC 7748 §6.1 Alice/Bob keys must produce the same K.

    private fun x25519SharedSecret(myPrivRaw: ByteArray, partnerPubRaw: ByteArray): ByteArray {
        require(myPrivRaw.size == X25519PrivateKeyParameters.KEY_SIZE) {
            "X25519 private key must be 32 bytes, got ${myPrivRaw.size}"
        }
        require(partnerPubRaw.size == X25519PublicKeyParameters.KEY_SIZE) {
            "X25519 public key must be 32 bytes, got ${partnerPubRaw.size}"
        }
        val agreement = X25519Agreement().apply {
            init(X25519PrivateKeyParameters(myPrivRaw, 0))
        }
        val shared = ByteArray(agreement.agreementSize)
        agreement.calculateAgreement(X25519PublicKeyParameters(partnerPubRaw, 0), shared, 0)
        return shared
    }

    // HKDF-SHA256. CryptoKit's `hkdfDerivedSymmetricKey(salt:sharedInfo:)` is
    // RFC 5869 with empty PRK ladder, so we use BouncyCastle's HKDFBytesGenerator.
    private fun hkdfSha256(ikm: ByteArray, salt: ByteArray, info: ByteArray, length: Int): ByteArray {
        val hkdf = HKDFBytesGenerator(SHA256Digest())
        hkdf.init(HKDFParameters(ikm, salt, info))
        val out = ByteArray(length)
        hkdf.generateBytes(out, 0, length)
        return out
    }
}

// ISO-8601 helper. Java `Instant.toString()` produces RFC 3339 / ISO-8601
// like "2026-05-17T10:23:45.123Z" which matches Swift JSONEncoder.iso output
// well enough for round-trip (both sides parse with their own iso decoder).
internal object IsoDate {
    fun now(): String = java.time.Instant.now().toString()

    /**
     * Tolerant ISO-8601 → Instant. Postgres/PostgREST returns timestamptz with
     * a numeric offset ("2026-06-03T12:26:51.446483+00:00"), NOT a 'Z'. On some
     * platform java.time builds (older Android) `Instant.parse` only accepts a
     * 'Z' terminator and throws DateTimeParseException on "+00:00" — which, in
     * ChatRepository.fetchOnce, propagated out of the row mapper and silently
     * emptied the whole message list. OffsetDateTime.parse handles both 'Z' and
     * numeric offsets on every platform; we keep Instant.parse as a fast path.
     */
    fun instant(raw: String): java.time.Instant =
        try {
            java.time.Instant.parse(raw)
        } catch (_: java.time.format.DateTimeParseException) {
            java.time.OffsetDateTime.parse(raw).toInstant()
        }
}
