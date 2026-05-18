package michel.kit.us.data

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessaging
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.tasks.await
import kotlinx.serialization.Serializable

/**
 * Port of ios/LoverApp/Services/PushService.swift for Android / FCM.
 *
 * iOS uploads its APNs hex token into `users.device_token` via the
 * `set_device_token` RPC. We do the same for FCM with a sibling column
 * `users.fcm_token` (see supabase/migrations/0015_fcm_token.sql) and the
 * `set_fcm_token` RPC.
 *
 * The notification channel `messages` is created here so [LoverFcmService]
 * can post into it even when the app has never been opened since install.
 *
 * Sign-out flow: caller (AuthRepository.signOut) should invoke
 * [clearToken] before signing out so the token is wiped server-side
 * while we still have a JWT to authorize the RPC.
 */
class PushRepository(private val appContext: Context) {

    companion object {
        const val MESSAGES_CHANNEL_ID = "messages"
        const val MESSAGES_CHANNEL_NAME = "訊息"
    }

    private val client = SupabaseClient.instance

    /**
     * Idempotent. Call from MainActivity onCreate (before sign-in) so the
     * channel exists when the first push arrives, and again from sign-in
     * once we have a JWT so the token upload can happen.
     */
    fun ensureNotificationChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = appContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (nm.getNotificationChannel(MESSAGES_CHANNEL_ID) == null) {
            val channel = NotificationChannel(
                MESSAGES_CHANNEL_ID,
                MESSAGES_CHANNEL_NAME,
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "對方傳訊息畀你嘅通知"
            }
            nm.createNotificationChannel(channel)
        }
    }

    /** Android 13+: POST_NOTIFICATIONS is a runtime permission. */
    fun hasNotificationPermission(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.TIRAMISU) return true
        return ContextCompat.checkSelfPermission(
            appContext, Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
    }

    /**
     * Fetch the device's FCM token + upload it to public.users via RPC.
     * Best-effort: on any failure (placeholder google-services.json, no
     * network, etc.) we swallow the error — chat still works without push.
     */
    suspend fun bootstrap() {
        ensureNotificationChannel()
        runCatching {
            val token = FirebaseMessaging.getInstance().token.await()
            uploadToken(token)
        }
    }

    suspend fun uploadToken(token: String) {
        val uid = client.auth.currentUserOrNull()?.id ?: return
        runCatching {
            client.postgrest.rpc(
                "set_fcm_token",
                TokenArgs(p_token = token)
            )
        }
    }

    /** Called on sign-out so the server stops fanning out to a stale device. */
    suspend fun clearToken() {
        runCatching {
            // Pass empty string instead of null — the RPC accepts text, and
            // an empty token short-circuits the recipient lookup in the
            // Edge Function (empty string is falsy in JS truthiness check
            // via `if (recipient.fcm_token)`).
            client.postgrest.rpc(
                "set_fcm_token",
                TokenArgs(p_token = "")
            )
        }
        // Also delete the local FCM token so a fresh signup gets a new one.
        runCatching {
            FirebaseMessaging.getInstance().deleteToken().await()
        }
    }

    @Serializable
    private data class TokenArgs(val p_token: String)
}
