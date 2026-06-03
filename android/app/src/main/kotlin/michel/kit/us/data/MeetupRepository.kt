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
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit
import java.util.UUID

/**
 * Port of ios/LoverApp/Services/MeetupService.swift — "next meet-up" loop.
 * meet_date is plaintext (countdown); selfies are E2EE storage paths.
 */
@Serializable
data class Meetup(
    val id: String,
    val couple_id: String,
    val created_by: String,
    val meet_date: String,
    val title: String,
    val status: String,
    val selfie_a_handle: String? = null,
    val selfie_b_handle: String? = null,
    val created_at: String,
    val completed_at: String? = null
) {
    val isUpcoming: Boolean get() = status == "upcoming"
    val daysUntil: Int get() = try {
        ChronoUnit.DAYS.between(
            LocalDate.now(ZoneId.of("Asia/Hong_Kong")),
            LocalDate.parse(meet_date)
        ).toInt()
    } catch (_: Throwable) { 0 }
}

class MeetupRepository(
    private val crypto: CryptoService,
    private val scope: CoroutineScope
) {
    private val client = SupabaseClient.instance
    private val media = MediaRepository(crypto)

    private val _all = MutableStateFlow<List<Meetup>>(emptyList())
    val all: StateFlow<List<Meetup>> = _all.asStateFlow()
    private val _upcoming = MutableStateFlow<Meetup?>(null)
    val upcoming: StateFlow<Meetup?> = _upcoming.asStateFlow()
    private val _dueMeetup = MutableStateFlow<Meetup?>(null)
    val dueMeetup: StateFlow<Meetup?> = _dueMeetup.asStateFlow()
    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    private var coupleId: UUID? = null
    private var meId: UUID? = null
    private var isUserA = false
    private var job: Job? = null

    fun start(coupleId: UUID) {
        if (this.coupleId == coupleId && job?.isActive == true) return
        stop()
        this.coupleId = coupleId
        this.meId = runCatching { client.auth.currentUserOrNull()?.id?.let(UUID::fromString) }.getOrNull()
        job = scope.launch { bootstrap(coupleId) }
    }

    fun stop() {
        job?.cancel(); job = null
        coupleId = null; meId = null
        _all.value = emptyList(); _upcoming.value = null; _dueMeetup.value = null
    }

    fun pause() = stop()
    fun resume(coupleId: UUID) = start(coupleId)
    fun clearError() { _lastError.value = null }
    suspend fun refresh() = fetchOnce()

    suspend fun createMeetup(meetDate: String, title: String) {
        val cid = coupleId ?: return
        val me = meId ?: run { _lastError.value = "未準備好（請重開 app 再試）"; return }
        try {
            client.postgrest["meetups"].insert(
                MeetupOut(cid.toString(), me.toString(), meetDate,
                    title.ifBlank { "下次見面" })
            )
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = "建立見面失敗：${t.message}"
        }
    }

    suspend fun submitSelfie(meetupId: UUID, data: ByteArray) {
        val cid = coupleId ?: return
        try {
            val path = media.uploadEncrypted(data, cid)
            client.postgrest.rpc("set_meetup_selfie", buildJsonObject {
                put("p_meetup_id", meetupId.toString())
                put("p_handle", path)
            })
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = "上載自拍失敗：${t.message}"
        }
    }

    suspend fun cancelMeetup(id: UUID) {
        try {
            client.postgrest["meetups"].update({ set("status", "cancelled") }) {
                filter { eq("id", id.toString()) }
            }
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    private suspend fun bootstrap(coupleId: UUID) {
        val me = meId ?: return
        try {
            val c: CoupleRow = client.postgrest["couples"].select {
                filter { eq("id", coupleId.toString()) }
            }.decodeSingle()
            isUserA = UUID.fromString(c.user_a_id) == me
        } catch (_: Throwable) { return }

        fetchOnce()
        scope.launch {
            while (coroutineContext.isActive) { delay(30_000); fetchOnce() }
        }

        val cidStr = coupleId.toString().lowercase()
        val channel = client.realtime.channel("meetups-$cidStr") {}
        val inserts = channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            table = "meetups"; filter("couple_id", FilterOperator.EQ, cidStr)
        }
        val updates = channel.postgresChangeFlow<PostgresAction.Update>(schema = "public") {
            table = "meetups"; filter("couple_id", FilterOperator.EQ, cidStr)
        }
        val subscribed = try { channel.subscribe(blockUntilSubscribed = true); true } catch (_: Throwable) { false }
        if (!subscribed) {
            withContext(NonCancellable) { runCatching { client.realtime.removeChannel(channel) } }
            return
        }
        try {
            coroutineScope {
                launch { inserts.collect { fetchOnce() } }
                launch { updates.collect { fetchOnce() } }
            }
        } finally {
            // See ChecklistRepository.runRealtime — remove the cached channel so
            // resume() builds a fresh one instead of crashing on rejoin.
            withContext(NonCancellable) { runCatching { client.realtime.removeChannel(channel) } }
        }
    }

    private suspend fun fetchOnce() {
        val cid = coupleId ?: return
        try {
            val rows: List<Meetup> = client.postgrest["meetups"].select {
                filter { eq("couple_id", cid.toString()) }
                order("meet_date", Order.ASCENDING)
            }.decodeList()
            _all.value = rows
            _upcoming.value = rows.firstOrNull { it.isUpcoming && it.daysUntil >= 0 }
            _dueMeetup.value = rows.firstOrNull { m ->
                if (!m.isUpcoming || m.daysUntil > 0) return@firstOrNull false
                val mine = if (isUserA) m.selfie_a_handle else m.selfie_b_handle
                mine == null
            }
        } catch (t: Throwable) {
            _lastError.value = "載入見面失敗：${t.message}"
        }
    }

    @Serializable private data class CoupleRow(val user_a_id: String, val user_b_id: String)
    @Serializable private data class MeetupOut(
        val couple_id: String, val created_by: String, val meet_date: String, val title: String
    )
}
