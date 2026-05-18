package michel.kit.us.service

import android.Manifest
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import kotlinx.coroutines.launch
import kotlinx.serialization.Serializable
import michel.kit.us.MainActivity
import michel.kit.us.R
import michel.kit.us.data.PushRepository
import michel.kit.us.data.SupabaseClient

/**
 * Android counterpart of iOS PushService callbacks.
 *
 * onNewToken — Firebase rotated the token (app install, data clear, app
 * restore on a new device, etc.). Re-upload to public.users.fcm_token via
 * the set_fcm_token RPC.
 *
 * onMessageReceived — fired when the app is in foreground OR when the push
 * payload is data-only. For notification-style payloads delivered while the
 * app is backgrounded, the system tray notification is created by FCM
 * itself using the Edge Function's `notification` block — this callback
 * does NOT fire in that case.
 *
 * Wire-compat with the Edge Function (supabase/functions/send-push/index.ts):
 *   notification.title — sender's my_name
 *   notification.body  — generic "sent you a message ♡" string (NEVER
 *                        contains decrypted content — push payload is E2EE-safe)
 *   data.thread_id     — couple UUID (used as the notification tag so
 *                        multiple messages collapse into one)
 */
class LoverFcmService : FirebaseMessagingService() {

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        // Same RPC the PushRepository uses. We're outside a Composable here
        // so we just talk to the Supabase client directly.
        scope.launch {
            val client = SupabaseClient.instance
            if (client.auth.currentUserOrNull()?.id != null) {
                runCatching {
                    // Supabase Kotlin 3.x rpc takes JsonObject, not data class.
                    client.postgrest.rpc("set_fcm_token", buildJsonObject {
                        put("p_token", token)
                    })
                }
            }
        }
    }

    override fun onMessageReceived(message: RemoteMessage) {
        super.onMessageReceived(message)

        // Foreground delivery: build a manual notification. Background
        // delivery with a notification block is handled by FCM SDK itself,
        // so this branch only fires while the user has the app open OR
        // for data-only pushes (we don't send those right now, but if the
        // server is ever updated to send ciphertext + decrypt-on-tap, this
        // is the entry point).
        val notif = message.notification
        val data = message.data
        val title = notif?.title ?: data["title"] ?: "新訊息"
        // Stay generic — body must never contain decrypted message text.
        // 新訊息 = "new message"
        val body = notif?.body ?: data["body"] ?: "新訊息"
        val threadId = data["thread_id"]

        postNotification(title = title, body = body, tag = threadId)
    }

    private fun postNotification(title: String, body: String, tag: String?) {
        // Android 13+: bail if user denied POST_NOTIFICATIONS — surfacing
        // an exception would just crash a background service.
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.TIRAMISU) {
            if (ContextCompat.checkSelfPermission(
                    this, Manifest.permission.POST_NOTIFICATIONS
                ) != PackageManager.PERMISSION_GRANTED
            ) return
        }

        val openIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        val pending = PendingIntent.getActivity(
            this, 0, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val builder = NotificationCompat.Builder(this, PushRepository.MESSAGES_CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(pending)
            .setAutoCancel(true)
            .setPriority(NotificationCompat.PRIORITY_HIGH)

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        // Tag = couple UUID so subsequent messages collapse into one entry.
        nm.notify(tag, 1, builder.build())
    }

    @Serializable
    private data class TokenArgs(val p_token: String)
}
