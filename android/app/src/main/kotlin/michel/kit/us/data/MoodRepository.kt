package michel.kit.us.data

import io.github.jan.supabase.auth.auth
import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.Instant
import java.util.UUID

/**
 * Port of ios/LoverApp/Models/Mood.swift + Services/MoodService.swift.
 *
 * Mood wire value MUST match the server CHECK + iOS: happy/sad/angry/love/tired.
 * Each mood carries a kaomoji, a cheer tap-target, and copy. Durable mood lives
 * on users.mood (set_mood RPC); cheers delivered via postgres_changes.
 */
enum class Mood {
    happy, sad, angry, love, tired;

    val kao: String get() = when (this) {
        happy -> "(◕‿◕)"; sad -> "(╥_╥)"; angry -> "(`Д´)"; love -> "(♡‿♡)"; tired -> "(-_-)"
    }
    val label: String get() = when (this) {
        happy -> "開心"; sad -> "唔開心"; angry -> "嬲嬲"; love -> "好愛你"; tired -> "好攰"
    }
    val targetTaps: Int get() = when (this) {
        happy, love -> 1; tired -> 30; sad, angry -> 100
    }
    val cheerVerb: String get() = when (this) {
        happy -> "同佢擊掌"; love -> "錫返佢一啖"; sad -> "氹返佢開心"; angry -> "氹返佢唔好嬲"; tired -> "幫佢叉電"
    }
    val cheerKao: String get() = when (this) {
        happy -> "(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧"; love -> "(づ｡◕‿‿◕｡)づ"; sad -> "(｡•́︿•̀｡)"; angry -> "(╬ Ò﹏Ó)"; tired -> "(ᴗ_ᴗ｡)"
    }
    val doneKao: String get() = "٩(◕‿◕)۶"
    val needsCheer: Boolean get() = this == sad || this == angry || this == tired
    val cheerDoneMessage: String get() = when (this) {
        happy -> "同你擊掌 ✋ (◕‿◕)"; love -> "錫返你一啖 (♡‿♡)"; sad -> "氹返你開心喇 (◕‿◕)"
        angry -> "氹返你唔好嬲喇 (◕‿◕)"; tired -> "幫你叉返電 ⚡ (◕‿◕)"
    }
    companion object {
        fun fromWire(s: String?): Mood? = entries.firstOrNull { it.name == s }
    }
}

class MoodRepository(
    private val scope: CoroutineScope
) {
    private val client = SupabaseClient.instance

    private val _myMood = MutableStateFlow<Mood?>(null)
    val myMood: StateFlow<Mood?> = _myMood.asStateFlow()
    private val _partnerMood = MutableStateFlow<Mood?>(null)
    val partnerMood: StateFlow<Mood?> = _partnerMood.asStateFlow()
    /** Set when the partner finished cheering ME (drives a celebration). */
    private val _incomingCheer = MutableStateFlow<Mood?>(null)
    val incomingCheer: StateFlow<Mood?> = _incomingCheer.asStateFlow()

    private var coupleId: UUID? = null
    private var meId: UUID? = null
    private var partnerId: UUID? = null
    private var job: Job? = null
    private var startedAt = Instant.now()

    fun start(coupleId: UUID) {
        if (this.coupleId == coupleId && job?.isActive == true) return
        stop()
        this.coupleId = coupleId
        this.meId = runCatching { client.auth.currentUserOrNull()?.id?.let(UUID::fromString) }.getOrNull()
        startedAt = Instant.now()
        job = scope.launch { bootstrap(coupleId) }
    }

    fun stop() {
        job?.cancel(); job = null
        coupleId = null; meId = null; partnerId = null
        _partnerMood.value = null; _incomingCheer.value = null
    }

    fun pause() = stop()
    fun resume(coupleId: UUID) = start(coupleId)

    fun consumeIncomingCheer() { _incomingCheer.value = null }

    /** Optimistically flip partner mood to happy after I cheer them. */
    fun markPartnerCheered() { _partnerMood.value = Mood.happy }

    suspend fun setMood(mood: Mood?) {
        try {
            client.postgrest.rpc("set_mood", buildJsonObject { put("p_mood", mood?.name) })
            _myMood.value = mood
        } catch (_: Throwable) {}
    }

    suspend fun sendCheerComplete(targetMood: Mood) {
        val cid = coupleId ?: return
        val me = meId ?: return
        val partner = partnerId ?: return
        try {
            client.postgrest["cheers"].insert(
                CheerOut(cid.toString(), me.toString(), partner.toString(), targetMood.name)
            )
        } catch (_: Throwable) {}
    }

    private suspend fun bootstrap(coupleId: UUID) {
        val me = meId ?: return
        try {
            val c: CoupleRow = client.postgrest["couples"].select {
                filter { eq("id", coupleId.toString()) }
            }.decodeSingle()
            partnerId = if (UUID.fromString(c.user_a_id) == me) UUID.fromString(c.user_b_id)
                        else UUID.fromString(c.user_a_id)
        } catch (_: Throwable) { return }

        refreshMoods()
        scope.launch {
            while (coroutineContext.isActive) {
                delay(15_000)
                refreshMoods()
            }
        }
        subscribeCheers(coupleId)
    }

    private suspend fun refreshMoods() {
        val me = meId ?: return
        val partner = partnerId ?: return
        try {
            val rows: List<UserMoodRow> = client.postgrest["users"].select {
                filter { isIn("id", listOf(me.toString(), partner.toString())) }
            }.decodeList()
            rows.forEach { r ->
                val m = Mood.fromWire(r.mood)
                when (UUID.fromString(r.id)) {
                    me -> _myMood.value = m
                    partner -> _partnerMood.value = m
                }
            }
        } catch (_: Throwable) {}
    }

    private suspend fun subscribeCheers(coupleId: UUID) {
        val cidStr = coupleId.toString().lowercase()
        val channel = client.realtime.channel("cheers-$cidStr") {}
        val inserts = channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            table = "cheers"
            filter("couple_id", FilterOperator.EQ, cidStr)
        }
        val subscribed = try { channel.subscribe(blockUntilSubscribed = true); true } catch (_: Throwable) { false }
        if (!subscribed) {
            withContext(NonCancellable) { runCatching { client.realtime.removeChannel(channel) } }
            return
        }
        try {
            inserts.collect { handleCheerEvent() }
        } finally {
            // See ChecklistRepository.runRealtime — remove the channel so a
            // fresh one is created on resume(), avoiding the "postgresChangeFlow
            // after joining" crash on background→resume.
            withContext(NonCancellable) { runCatching { client.realtime.removeChannel(channel) } }
        }
    }

    private suspend fun handleCheerEvent() {
        val cid = coupleId ?: return
        val me = meId ?: return
        try {
            val rows: List<CheerIn> = client.postgrest["cheers"].select {
                filter { eq("couple_id", cid.toString()) }
                order("created_at", Order.DESCENDING)
                limit(1)
            }.decodeList()
            val latest = rows.firstOrNull() ?: return
            if (UUID.fromString(latest.to_user_id) != me) return
            if (IsoDate.instant(latest.created_at).isBefore(startedAt.minusSeconds(5))) return
            val mood = Mood.fromWire(latest.mood) ?: Mood.happy
            _incomingCheer.value = mood
            setMood(Mood.happy)
        } catch (_: Throwable) {}
    }

    @Serializable private data class CoupleRow(val user_a_id: String, val user_b_id: String)
    @Serializable private data class UserMoodRow(val id: String, val mood: String? = null)
    @Serializable private data class CheerOut(
        val couple_id: String, val from_user_id: String, val to_user_id: String, val mood: String
    )
    @Serializable private data class CheerIn(val to_user_id: String, val mood: String, val created_at: String)
}
