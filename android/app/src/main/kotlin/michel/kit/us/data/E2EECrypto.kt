package michel.kit.us.data

import android.util.Base64
import kotlinx.serialization.KSerializer
import kotlinx.serialization.json.Json
import java.security.SecureRandom
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Generic typed-payload seal/open over the shared E2EE chat key.
 *
 * Mirror of the iOS `CryptoService` Codable extensions in
 * AnniversaryService.swift — provides `sealJson<T>()` / `openJson<T>()` for
 * entries + anniversaries (whose plaintext is an arbitrary JSON-encoded
 * struct, not the chat `ChatPayload` shape).
 *
 * Reaches into [CryptoService] via reflection to grab the same derived AES
 * key the chat code uses. This is intentional — Round 1 of Phase B should
 * not touch CryptoService.kt (chat agent B2 owns it) so the typed seal API
 * lives in this companion file instead of as a method on the class.
 */
private val sharedJson = Json {
    ignoreUnknownKeys = true
    explicitNulls = false
    encodeDefaults = true
}

private fun CryptoService.requireChatKey(): ByteArray {
    val field = CryptoService::class.java.getDeclaredField("chatKey").apply { isAccessible = true }
    val key = field.get(this) as? ByteArray ?: throw CryptoService.CryptoError.NotReady
    return key
}

fun <T> CryptoService.sealJson(serializer: KSerializer<T>, value: T): String {
    val key = requireChatKey()
    val plaintext = sharedJson.encodeToString(serializer, value).toByteArray(Charsets.UTF_8)
    val nonce = ByteArray(12).also { SecureRandom().nextBytes(it) }
    val cipher = Cipher.getInstance("AES/GCM/NoPadding")
    cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
    val ctAndTag = cipher.doFinal(plaintext)
    val combined = ByteArray(nonce.size + ctAndTag.size)
    System.arraycopy(nonce, 0, combined, 0, nonce.size)
    System.arraycopy(ctAndTag, 0, combined, nonce.size, ctAndTag.size)
    return Base64.encodeToString(combined, Base64.NO_WRAP)
}

fun <T> CryptoService.openJson(serializer: KSerializer<T>, ciphertextB64: String): T {
    val key = requireChatKey()
    val combined = try {
        Base64.decode(ciphertextB64, Base64.NO_WRAP)
    } catch (t: Throwable) {
        throw CryptoService.CryptoError.InvalidBase64
    }
    if (combined.size < 12 + 16) throw CryptoService.CryptoError.OpenFailed(null)
    val nonce = combined.copyOfRange(0, 12)
    val rest = combined.copyOfRange(12, combined.size)
    return try {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), GCMParameterSpec(128, nonce))
        val plain = cipher.doFinal(rest)
        sharedJson.decodeFromString(serializer, String(plain, Charsets.UTF_8))
    } catch (t: Throwable) {
        throw CryptoService.CryptoError.OpenFailed(t)
    }
}
