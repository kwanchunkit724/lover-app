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
import java.time.Instant
import java.util.UUID

/**
 * Port of ios/LoverApp/Services/ChecklistService.swift — shared quick checklist
 * (short-term memory: what to buy / do). Item text is E2EE (sealed as a
 * ChatPayload.text with the couple chat key); `done` is a plaintext column.
 * Realtime via postgres_changes, same as messages.
 */
data class ChecklistItem(
    val id: UUID,
    val text: String,
    val done: Boolean,
    val senderId: UUID,
    val createdAt: Instant
)

class ChecklistRepository(
    private val crypto: CryptoService,
    private val scope: CoroutineScope
) {
    private val client = SupabaseClient.instance

    private val _items = MutableStateFlow<List<ChecklistItem>>(emptyList())
    val items: StateFlow<List<ChecklistItem>> = _items.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    private var coupleId: UUID? = null
    private var meId: UUID? = null
    private var job: Job? = null

    val openCount: Int get() = _items.value.count { !it.done }

    fun start(coupleId: UUID) {
        if (this.coupleId == coupleId && job?.isActive == true) return
        stop()
        this.coupleId = coupleId
        this.meId = runCatching {
            client.auth.currentUserOrNull()?.id?.let(UUID::fromString)
        }.getOrNull()
        job = scope.launch {
            fetchOnce()
            runRealtime(coupleId)
        }
    }

    fun stop() {
        job?.cancel(); job = null
        coupleId = null; meId = null
        _items.value = emptyList()
    }

    fun pause() = stop()
    fun resume(coupleId: UUID) = start(coupleId)

    suspend fun add(text: String) {
        val cid = coupleId ?: return
        val me = meId ?: run { _lastError.value = "未準備好（請重開 app 再試）"; return }
        val trimmed = text.trim()
        if (trimmed.isEmpty()) return
        try {
            val cipher = crypto.seal(ChatPayload.text(trimmed))
            client.postgrest["checklist_items"].insert(
                OutgoingRow(cid.toString(), me.toString(), cipher)
            )
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = "加入失敗：${t.message}"
        }
    }

    suspend fun toggle(item: ChecklistItem) {
        try {
            client.postgrest["checklist_items"].update({ set("done", !item.done) }) {
                filter { eq("id", item.id.toString()) }
            }
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    suspend fun remove(item: ChecklistItem) {
        try {
            client.postgrest["checklist_items"].delete {
                filter { eq("id", item.id.toString()) }
            }
            _items.value = _items.value.filterNot { it.id == item.id }
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    suspend fun clearDone() {
        val cid = coupleId ?: return
        try {
            client.postgrest["checklist_items"].delete {
                filter {
                    eq("couple_id", cid.toString())
                    eq("done", true)
                }
            }
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    fun clearError() { _lastError.value = null }

    private suspend fun runRealtime(coupleId: UUID) {
        val cidStr = coupleId.toString().lowercase()
        val channel = client.realtime.channel("checklist-$cidStr") {}
        val inserts = channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            table = "checklist_items"
            filter("couple_id", FilterOperator.EQ, cidStr)
        }
        val updates = channel.postgresChangeFlow<PostgresAction.Update>(schema = "public") {
            table = "checklist_items"
            filter("couple_id", FilterOperator.EQ, cidStr)
        }
        val deletes = channel.postgresChangeFlow<PostgresAction.Delete>(schema = "public") {
            table = "checklist_items"
        }
        val subscribed = try {
            channel.subscribe(blockUntilSubscribed = true); true
        } catch (t: Throwable) { false }
        if (!subscribed) {
            withContext(NonCancellable) { runCatching { client.realtime.removeChannel(channel) } }
            return
        }
        try {
            coroutineScope {
                launch { inserts.collect { fetchOnce() } }
                launch { updates.collect { fetchOnce() } }
                launch { deletes.collect { fetchOnce() } }
            }
        } finally {
            // Remove the channel so a fresh, un-joined one is created on the
            // next start(). Without this, resume() reuses the cached joined
            // channel and postgresChangeFlow throws "cannot call ... after
            // joining the channel", crashing the app on background→resume.
            withContext(NonCancellable) { runCatching { client.realtime.removeChannel(channel) } }
        }
    }

    private suspend fun fetchOnce() {
        val cid = coupleId ?: return
        try {
            val rows: List<IncomingRow> = client.postgrest["checklist_items"]
                .select {
                    filter { eq("couple_id", cid.toString()) }
                    order("created_at", Order.ASCENDING)
                }
                .decodeList()
            _items.value = rows.map { row ->
                val text = runCatching { crypto.open(row.ciphertext_b64).text }
                    .getOrNull() ?: "(無法解密)"
                ChecklistItem(
                    id = UUID.fromString(row.id),
                    text = text,
                    done = row.done,
                    senderId = UUID.fromString(row.sender_id),
                    createdAt = IsoDate.instant(row.created_at)
                )
            }
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    @Serializable
    private data class OutgoingRow(
        val couple_id: String,
        val sender_id: String,
        val ciphertext_b64: String
    )

    @Serializable
    private data class IncomingRow(
        val id: String,
        val couple_id: String,
        val sender_id: String,
        val ciphertext_b64: String,
        val done: Boolean,
        val created_at: String
    )
}
