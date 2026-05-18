package michel.kit.us.data

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.auth.providers.Google
import io.github.jan.supabase.auth.providers.builtin.Email
import io.github.jan.supabase.auth.providers.builtin.IDToken
import io.github.jan.supabase.auth.status.SessionStatus
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import java.util.UUID

/**
 * Port of ios/LoverApp/Services/AuthService.swift.
 *
 * Phase A scope: email + password (sign in / sign up / sign out) only.
 *
 * iOS uses Sign-in-with-Apple as primary path + Email OTP magic link as
 * secondary. On Android the natural parity is Google Sign-In via Credential
 * Manager → Supabase signInWithIdToken — that's a Phase B task because it
 * needs a Web Client ID configured in Google Cloud + the SHA-1 of the
 * Play upload key. Email/password works in the meantime for testing the
 * end-to-end pairing + chat flow.
 *
 * On first successful sign-in we upsert a row into public.users carrying the
 * device's X25519 public key — without that step the partner can't derive the
 * shared chat key. The iOS app collects a profile (name / partner name /
 * anniversary / theme) during onboarding; on Android we send sensible
 * defaults and let the user edit in Phase B settings.
 */
class AuthRepository(
    private val keyManager: KeyManager,
    private val push: PushRepository
) {
    private val client = SupabaseClient.instance
    private val auth = client.auth

    /** Stream of the current user id. null when signed out. */
    val currentUserId: Flow<UUID?> = auth.sessionStatus.map { status ->
        when (status) {
            is SessionStatus.Authenticated -> runCatching {
                UUID.fromString(status.session.user?.id)
            }.getOrNull()
            else -> null
        }
    }

    suspend fun bootstrap() {
        // Supabase Kotlin SDK auto-loads the session from SessionManager on
        // first auth access; no explicit call needed. Hitting `currentUserId`
        // is enough.
    }

    suspend fun signInWithEmail(email: String, password: String) {
        auth.signInWith(Email) {
            this.email = email.trim()
            this.password = password
        }
        upsertProfile()
        push.bootstrap()
    }

    /**
     * Phase B Round 2 — Google Sign-In via CredentialManager.
     * The UI launches `CredentialManager.getCredential(...)` with a
     * GetGoogleIdOption, extracts the Google ID token from the result, and
     * passes it here. Supabase verifies it server-side via the Google
     * provider (which must be enabled in the Supabase Dashboard with the
     * same Web Client ID).
     */
    suspend fun signInWithGoogle(idToken: String, rawNonce: String? = null) {
        auth.signInWith(IDToken) {
            provider = Google
            this.idToken = idToken
            if (rawNonce != null) nonce = rawNonce
        }
        upsertProfile()
        push.bootstrap()
    }

    suspend fun signUpWithEmail(email: String, password: String) {
        auth.signUpWith(Email) {
            this.email = email.trim()
            this.password = password
        }
        // Supabase may or may not auto-confirm depending on project settings;
        // if confirmation email is on, the user must confirm first. Best
        // effort: try to sign in immediately.
        runCatching {
            auth.signInWith(Email) {
                this.email = email.trim()
                this.password = password
            }
            upsertProfile()
            push.bootstrap()
        }
    }

    suspend fun signOut() {
        // Clear the FCM token server-side BEFORE auth.signOut() invalidates
        // our JWT — otherwise the RPC would 401.
        push.clearToken()
        auth.signOut()
        keyManager.reset()
    }

    /**
     * Upsert the user row including the device's X25519 public key. Mirrors
     * the iOS [AuthService.upsertProfile] private method but with sensible
     * defaults since Phase A skips onboarding profile collection.
     */
    private suspend fun upsertProfile() {
        val userId = auth.currentUserOrNull()?.id?.let(UUID::fromString) ?: return
        val publicKey = keyManager.myPublicKeyBase64()
        val row = UserRow(
            id = userId.toString(),
            myName = "我",
            partnerName = "另一半",
            anniversaryIso = java.time.LocalDate.now().toString(),
            themeId = "cream",
            publicKey = publicKey
        )
        client.postgrest["users"].upsert(row)
    }

    @Serializable
    private data class UserRow(
        val id: String,
        @SerialName("my_name") val myName: String,
        @SerialName("partner_name") val partnerName: String,
        @SerialName("anniversary_iso") val anniversaryIso: String,
        @SerialName("theme_id") val themeId: String,
        @SerialName("public_key") val publicKey: String
    )
}
