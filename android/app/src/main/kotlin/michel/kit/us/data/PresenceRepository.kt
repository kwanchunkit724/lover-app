package michel.kit.us.data

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.realtime.PresenceAction
import io.github.jan.supabase.realtime.RealtimeChannel
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.presenceChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.UUID

/**
 * Port of ios/LoverApp/Services/PresenceService.swift. Real partner presence
 * via Supabase Realtime presence channel + an `update_last_seen` heartbeat
 * RPC.
 *
 * Channel naming MUST match iOS exactly:
 *   "presence:<lowercase couple uuid>"
 *
 * Lifecycle: heartbeat MUST stop when the app is backgrounded — see pause()
 * / resume(). The hosting Compose layer calls those on lifecycle events.
 */
class PresenceRepository(
    private val scope: CoroutineScope,
    private val meIdProvider: () -> UUID?
) {
    private val client = SupabaseClient.instance

    private val _partnerOnline = MutableStateFlow(false)
    val partnerOnline: StateFlow<Boolean> = _partnerOnline.asStateFlow()

    private var coupleId: UUID? = null
    private var presenceJob: Job? = null
    private var heartbeatJob: Job? = null
    private val partnerKeys = mutableSetOf<String>()

    @Serializable
    private data class PresenceState(val online: Boolean, val userId: String)

    fun start(coupleId: UUID) {
        if (this.coupleId == coupleId && presenceJob?.isActive == true) return
        stop()
        this.coupleId = coupleId
        val me = meIdProvider() ?: return

        val key = "presence:${coupleId.toString().lowercase()}"
        val channel = client.realtime.channel(key)

        presenceJob = scope.launch {
            // Collect presence joins/leaves from the channel.
            val flow = channel.presenceChangeFlow()
            try {
                channel.subscribe(blockUntilSubscribed = true)
                channel.track(PresenceState(online = true, userId = me.toString()))
            } catch (t: Throwable) {
                return@launch
            }
            flow.collect { action: PresenceAction ->
                applyPresence(action, me)
            }
        }

        heartbeatJob = scope.launch {
            while (isActive) {
                runCatching {
                    client.postgrest.rpc("update_last_seen", buildJsonObject {})
                }
                delay(30_000)
            }
        }
    }

    fun stop() {
        presenceJob?.cancel(); presenceJob = null
        heartbeatJob?.cancel(); heartbeatJob = null
        val cid = coupleId
        if (cid != null) {
            val key = "presence:${cid.toString().lowercase()}"
            // Best-effort unsubscribe.
            runCatching {
                scope.launch {
                    client.realtime.channel(key).unsubscribe()
                }
            }
        }
        coupleId = null
        partnerKeys.clear()
        _partnerOnline.value = false
    }

    /** Background → leave channel + clear UI + stop heartbeat. */
    fun pause() = stop()

    /** Foreground → rejoin. */
    fun resume(coupleId: UUID) = start(coupleId)

    private fun applyPresence(action: PresenceAction, me: UUID) {
        // supabase-kt 3.x PresenceAction: `joins` and `leaves` are
        // Map<String, Presence>, where Presence carries `presenceRef` +
        // `state: JsonObject`. We dedupe partner-side presences by key.
        for ((key, p) in action.joins) {
            val uid = (p.state["userId"] as? JsonPrimitive)?.content
            if (uid != null && uid != me.toString()) {
                partnerKeys.add(key)
            }
        }
        for ((key, _) in action.leaves) {
            partnerKeys.remove(key)
        }
        _partnerOnline.value = partnerKeys.isNotEmpty()
    }
}
