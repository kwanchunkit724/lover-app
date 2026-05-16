package michel.kit.us.data

import android.content.Context
import android.content.SharedPreferences
import android.util.Base64
import androidx.security.crypto.EncryptedSharedPreferences
import androidx.security.crypto.MasterKey
import org.bouncycastle.crypto.params.X25519PrivateKeyParameters
import java.security.SecureRandom

/**
 * X25519 keypair stored in EncryptedSharedPreferences, which under the hood
 * uses an AES-256-GCM key in the Android Keystore (hardware-backed on most
 * devices). Mirror of ios/LoverApp/Services/KeyManager.swift — the iOS side
 * stores the same 32 raw bytes in Keychain.
 *
 * The private key never leaves the device. The public key (derived on
 * demand) is uploaded to users.public_key after first sign-in so the
 * partner can derive the shared chat key.
 *
 * Threat model: couples app on personal devices. Hardware-backed AES wrapping
 * a stored X25519 private blob is sufficient — we don't need StrongBox / SEP-
 * style attestation.
 */
class KeyManager(context: Context) {

    private val prefs: SharedPreferences = run {
        val masterKey = MasterKey.Builder(context.applicationContext)
            .setKeyScheme(MasterKey.KeyScheme.AES256_GCM)
            .build()
        EncryptedSharedPreferences.create(
            context.applicationContext,
            PREFS_NAME,
            masterKey,
            EncryptedSharedPreferences.PrefKeyEncryptionScheme.AES256_SIV,
            EncryptedSharedPreferences.PrefValueEncryptionScheme.AES256_GCM
        )
    }

    /**
     * Returns this device's X25519 private key (raw 32 bytes), generating one
     * on first call. Idempotent.
     */
    @Synchronized
    fun myPrivateKey(): ByteArray {
        val stored = prefs.getString(KEY_PRIV, null)
        if (stored != null) {
            return Base64.decode(stored, Base64.NO_WRAP)
        }
        val priv = generateX25519Private()
        prefs.edit().putString(KEY_PRIV, Base64.encodeToString(priv, Base64.NO_WRAP)).apply()
        return priv
    }

    /** Convenience: base64(rawX25519PublicKey32). Uploaded to users.public_key. */
    fun myPublicKeyBase64(): String {
        val priv = X25519PrivateKeyParameters(myPrivateKey(), 0)
        val pub = priv.generatePublicKey().encoded
        return Base64.encodeToString(pub, Base64.NO_WRAP)
    }

    /**
     * Wipe the local private key. Used on sign-out / unpair so the next
     * sign-in starts fresh (and can't decrypt prior partner's messages).
     */
    fun reset() {
        prefs.edit().remove(KEY_PRIV).apply()
    }

    private fun generateX25519Private(): ByteArray {
        // BouncyCastle's X25519PrivateKeyParameters(SecureRandom) handles the
        // RFC 7748 clamping internally. We just feed a strong random.
        val params = X25519PrivateKeyParameters(SecureRandom())
        return params.encoded
    }

    companion object {
        // Filename appears in [data_extraction_rules.xml] — keep them in sync.
        private const val PREFS_NAME = "lover_secure_prefs"
        private const val KEY_PRIV = "x25519.private.v1"
    }
}
