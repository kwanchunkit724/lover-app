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
 * Port of ios/LoverApp/Services/AnniversaryService.swift.
 *
 * E2EE shared anniversaries. Phase B1 uses polling (every 30 s — anniversaries
 * change rarely) instead of Realtime; Realtime is Round 2.
 */
@Serializable
data class AnniversaryPayload(
    val v: Int = 1,
    val title: String,
    val baseDateISO: String,
    val recur: Recur,
    val kaomoji: String? = null,
    val emoji: String? = null,
    val subtitle: String? = null
) {
    @Serializable
    enum class Recur { yearly, monthly }
}

data class DecryptedAnniversary(
    val id: UUID,
    val senderId: UUID,
    val payload: AnniversaryPayload,
    val createdAt: Instant
)

class AnniversaryRepository(
    private val crypto: CryptoService,
    private val scope: CoroutineScope
) {
    private val client = SupabaseClient.instance

    private val _items = MutableStateFlow<List<DecryptedAnniversary>>(emptyList())
    val items: StateFlow<List<DecryptedAnniversary>> = _items.asStateFlow()

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
                delay(30_000)
                if (!isActive) break
                fetchOnce()
            }
        }
    }

    fun stop() {
        pollJob?.cancel(); pollJob = null
    }

    suspend fun add(payload: AnniversaryPayload, senderId: UUID) {
        val cid = coupleId ?: return
        try {
            val cipher = crypto.sealJson(AnniversaryPayload.serializer(), payload)
            val row = OutgoingRow(cid.toString(), senderId.toString(), cipher)
            client.postgrest["anniversaries"].insert(row)
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    suspend fun delete(id: UUID) {
        try {
            client.postgrest["anniversaries"].delete {
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
            val rows: List<IncomingRow> = client.postgrest["anniversaries"]
                .select {
                    filter { eq("couple_id", cid.toString()) }
                    order("created_at", Order.ASCENDING)
                }
                .decodeList()
            _items.value = rows.mapNotNull { row ->
                val payload = runCatching {
                    crypto.openJson(AnniversaryPayload.serializer(), row.ciphertext_b64)
                }.getOrNull() ?: return@mapNotNull null
                DecryptedAnniversary(
                    id = UUID.fromString(row.id),
                    senderId = UUID.fromString(row.sender_id),
                    payload = payload,
                    createdAt = Instant.parse(row.created_at)
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
