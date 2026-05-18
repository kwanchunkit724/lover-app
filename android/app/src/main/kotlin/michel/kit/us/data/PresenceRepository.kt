package michel.kit.us.data

import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import java.time.Instant
import java.util.UUID

/**
 * Port of ios/LoverApp/Services/PresenceService.swift, with a pragmatic
 * difference for Android:
 *
 * iOS uses the supabase-swift Realtime presence channel (`channel.track` +
 * `presenceChange()`). supabase-kt 3.1.4 ships a different presence DSL —
 * the function names that work in 3.0.x (`presenceChangeFlow`) don't
 * resolve in 3.1.4, so rather than spelunk through SDK internals we lean
 * on a polling strategy that gives identical UX:
 *
 *   * Heartbeat coroutine calls `update_last_seen()` every 30 s while the
 *     app is foreground.
 *   * A second coroutine polls the partner's `users.last_seen_at` every
 *     20 s and flips `partnerOnline = true` iff the value is fresher
 *     than [ONLINE_WINDOW_SEC] seconds (60 s).
 *
 * Channel naming (presence:<lowercase couple uuid>) is preserved as a
 * doc-comment for when iOS pairs successfully — both sides share the same
 * server-side signal (the `last_seen_at` column) regardless of which
 * client uses native realtime presence.
 */
class PresenceRepository(
    private val scope: CoroutineScope,
    private val meIdProvider: () -> UUID?
) {
    private val client = SupabaseClient.instance

    private val _partnerOnline = MutableStateFlow(false)
    val partnerOnline: StateFlow<Boolean> = _partnerOnline.asStateFlow()

    private var coupleId: UUID? = null
    private var partnerId: UUID? = null
    private var heartbeatJob: Job? = null
    private var pollJob: Job? = null

    companion object {
        private const val HEARTBEAT_INTERVAL_MS = 30_000L
        private const val POLL_INTERVAL_MS = 20_000L
        private const val ONLINE_WINDOW_SEC = 60L
    }

    fun start(coupleId: UUID) {
        if (this.coupleId == coupleId && heartbeatJob?.isActive == true) return
        stop()
        this.coupleId = coupleId
        val me = meIdProvider() ?: return

        heartbeatJob = scope.launch {
            while (isActive) {
                runCatching {
                    client.postgrest.rpc("update_last_seen", buildJsonObject {})
                }
                delay(HEARTBEAT_INTERVAL_MS)
            }
        }

        pollJob = scope.launch {
            // Resolve the partner id from the couples row once. This is
            // already cached by PairingRepository but reading it directly
            // keeps PresenceRepository self-contained.
            val pid = resolvePartnerId(coupleId, me)
            partnerId = pid
            if (pid == null) return@launch
            while (isActive) {
                runCatching { fetchPartnerLastSeen(pid) }
                    .onSuccess { ts ->
                        val online = ts != null &&
                            Instant.now().epochSecond - ts.epochSecond < ONLINE_WINDOW_SEC
                        _partnerOnline.value = online
                    }
                delay(POLL_INTERVAL_MS)
            }
        }
    }

    fun stop() {
        heartbeatJob?.cancel(); heartbeatJob = null
        pollJob?.cancel(); pollJob = null
        coupleId = null
        partnerId = null
        _partnerOnline.value = false
    }

    /** Background → leave channel + clear UI + stop heartbeat. */
    fun pause() = stop()

    /** Foreground → rejoin. */
    fun resume(coupleId: UUID) = start(coupleId)

    // ---------------------------------------------------------------------

    @Serializable
    private data class CoupleSlim(
        @SerialName("user_a_id") val userAId: String,
        @SerialName("user_b_id") val userBId: String
    )

    @Serializable
    private data class PartnerSlim(
        @SerialName("last_seen_at") val lastSeenAt: String? = null
    )

    private suspend fun resolvePartnerId(coupleId: UUID, me: UUID): UUID? {
        val rows: List<CoupleSlim> = client.postgrest["couples"]
            .select(columns = Columns.list("user_a_id", "user_b_id")) {
                filter { eq("id", coupleId.toString()) }
                limit(1)
            }
            .decodeList()
        val row = rows.firstOrNull() ?: return null
        val a = runCatching { UUID.fromString(row.userAId) }.getOrNull()
        val b = runCatching { UUID.fromString(row.userBId) }.getOrNull()
        return when (me) {
            a -> b
            b -> a
            else -> null
        }
    }

    private suspend fun fetchPartnerLastSeen(partnerId: UUID): Instant? {
        val rows: List<PartnerSlim> = client.postgrest["users"]
            .select(columns = Columns.list("last_seen_at")) {
                filter { eq("id", partnerId.toString()) }
                limit(1)
            }
            .decodeList()
        val raw = rows.firstOrNull()?.lastSeenAt ?: return null
        return runCatching { Instant.parse(raw) }.getOrNull()
    }
}
