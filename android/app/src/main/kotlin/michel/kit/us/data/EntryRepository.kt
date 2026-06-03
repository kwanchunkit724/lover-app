package michel.kit.us.data

import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.Serializable
import java.time.Instant
import java.util.UUID

/**
 * Port of ios/LoverApp/Services/EntryService.swift.
 *
 * E2EE shared timetable entries. Either partner can add or delete; both see
 * the same list via 10-second polling (Realtime is Round 2). Plaintext shape
 * mirrors iOS [EntryPayload] field-for-field so wire is compatible.
 */
@Serializable
data class EntryPayload(
    val v: Int = 1,
    val title: String,
    val dateISO: String,
    val time: String? = null,
    val location: String? = null,
    val proposedBy: String,
    val who: String,
    val tag: String,
    val isSpecial: Boolean,
    val notes: String? = null,
    val kaomoji: String? = null,
    val photoCount: Int = 0,
    val voiceCount: Int = 0,
    val messageCount: Int = 0,
    val reflection: ReflectionPayload? = null,
    val coverHandle: String? = null
) {
    @Serializable
    data class ReflectionPayload(val from: String, val text: String, val kaomoji: String? = null)
}

data class DecryptedEntry(
    val id: UUID,
    val senderId: UUID,
    val payload: EntryPayload,
    val createdAt: Instant
)

class EntryRepository(
    private val crypto: CryptoService,
    private val scope: CoroutineScope
) {
    private val client = SupabaseClient.instance

    private val _items = MutableStateFlow<List<DecryptedEntry>>(emptyList())
    val items: StateFlow<List<DecryptedEntry>> = _items.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    private var coupleId: UUID? = null
    private var pollJob: Job? = null

    fun start(coupleId: UUID) {
        if (this.coupleId == coupleId && pollJob?.isActive == true) return
        this.coupleId = coupleId
        stop()
        pollJob = scope.launch {
            fetchOnce()
            while (isActive) {
                delay(10_000)
                if (!isActive) break
                fetchOnce()
            }
        }
    }

    fun stop() {
        pollJob?.cancel(); pollJob = null
    }

    suspend fun add(payload: EntryPayload, senderId: UUID) {
        val cid = coupleId ?: return
        try {
            val cipher = crypto.sealJson(EntryPayload.serializer(), payload)
            val row = OutgoingRow(cid.toString(), senderId.toString(), cipher)
            client.postgrest["entries"].insert(row)
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    /**
     * v1.6.0 — edit an existing entry. Re-seals the new [payload] and
     * UPDATEs the ciphertext_b64 column. RLS (entries_update_member,
     * migration 0017) enforces couple membership server-side.
     */
    suspend fun update(id: UUID, payload: EntryPayload) {
        try {
            val cipher = crypto.sealJson(EntryPayload.serializer(), payload)
            client.postgrest["entries"].update(UpdatePayload(cipher)) {
                filter { eq("id", id.toString()) }
            }
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    @Serializable
    private data class UpdatePayload(val ciphertext_b64: String)

    suspend fun delete(id: UUID) {
        try {
            client.postgrest["entries"].delete {
                filter { eq("id", id.toString()) }
            }
            _items.value = _items.value.filterNot { it.id == id }
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    suspend fun fetchOnce() {
        val cid = coupleId ?: return
        _isLoading.value = true
        try {
            val rows: List<IncomingRow> = client.postgrest["entries"]
                .select {
                    filter { eq("couple_id", cid.toString()) }
                    order("created_at", Order.ASCENDING)
                }
                .decodeList()
            _items.value = rows.mapNotNull { row ->
                val payload = runCatching {
                    crypto.openJson(EntryPayload.serializer(), row.ciphertext_b64)
                }.getOrNull() ?: return@mapNotNull null
                DecryptedEntry(
                    id = UUID.fromString(row.id),
                    senderId = UUID.fromString(row.sender_id),
                    payload = payload,
                    createdAt = IsoDate.instant(row.created_at)
                )
            }
        } catch (t: Throwable) {
            _lastError.value = t.message
        } finally {
            _isLoading.value = false
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
        val created_at: String
    )
}
