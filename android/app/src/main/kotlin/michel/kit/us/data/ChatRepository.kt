package michel.kit.us.data

import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Order
import io.github.jan.supabase.postgrest.query.filter.FilterOperator
import io.github.jan.supabase.realtime.PostgresAction
import io.github.jan.supabase.realtime.channel
import io.github.jan.supabase.realtime.postgresChangeFlow
import io.github.jan.supabase.realtime.realtime
import kotlinx.coroutines.*
import kotlinx.coroutines.flow.*
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import michel.kit.us.domain.DecryptedMessage
import michel.kit.us.domain.ReactionAtom
import java.time.Instant
import java.util.UUID

/**
 * Port of ios/LoverApp/Services/ChatService.swift (the rewrite that ships
 * with v1.5 / migration 0013 — reply, reactions, edit, unsend, vanish, read).
 *
 * Behaviour notes preserved from iOS:
 *   * Realtime + 5s polling fallback (in case the websocket drops silently).
 *   * fetchOnce() client-side-filters expired vanish-mode rows + renders
 *     soft-deleted rows with a "已撤回" placeholder so reply chains stay intact.
 *   * Read receipts are best-effort (silent on error).
 *   * Reactions are non-critical (silent on error).
 *   * Realtime channel name "messages-<lowercase couple uuid>" matches iOS
 *     exactly so both apps land in the same Supabase realtime room.
 *
 * Wire types are `@Serializable` data classes named identically (snake_case)
 * to the iOS struct fields — the JSON shape on the wire is identical.
 */
class ChatRepository(
    private val crypto: CryptoService,
    private val scope: CoroutineScope
) {
    private val client = SupabaseClient.instance
    private val media = MediaRepository(crypto)

    /** Exposed for [features.chat.EncryptedAsyncImage] + [EncryptedAudioPlayback]. */
    val mediaRepository: MediaRepository get() = media

    private val _messages = MutableStateFlow<List<DecryptedMessage>>(emptyList())
    val messages: StateFlow<List<DecryptedMessage>> = _messages.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _vanishMode = MutableStateFlow(false)
    val vanishMode: StateFlow<Boolean> = _vanishMode.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    private var coupleId: UUID? = null
    private var pollJob: Job? = null
    private var realtimeJob: Job? = null

    val coupleIdValue: UUID? get() = coupleId

    // ---------------------------------------------------------------------
    // Lifecycle

    fun start(coupleId: UUID) {
        if (this.coupleId == coupleId && realtimeJob?.isActive == true) return
        this.coupleId = coupleId
        stop()
        pollJob = scope.launch { runPollLoop() }
        realtimeJob = scope.launch { runRealtimeLoop(coupleId) }
        scope.launch { refreshVanishMode() }
    }

    fun stop() {
        pollJob?.cancel(); pollJob = null
        realtimeJob?.cancel(); realtimeJob = null
    }

    // ---------------------------------------------------------------------
    // Send / edit / unsend / read

    suspend fun sendText(text: String, senderId: UUID, replyToId: UUID? = null) {
        val trimmed = text.trim()
        val cid = coupleId ?: return
        if (trimmed.isEmpty()) return
        try {
            val cipher = crypto.seal(ChatPayload.text(trimmed))
            val row = OutgoingRow(cid.toString(), senderId.toString(), cipher, replyToId?.toString())
            client.postgrest["messages"].insert(row)
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    /**
     * Encrypts the photo bytes, uploads to chat-media, then inserts a
     * `kind=photo` message row. Mirror of iOS ChatService.sendPhoto.
     */
    suspend fun sendPhoto(
        bytes: ByteArray,
        caption: String?,
        senderId: UUID,
        replyToId: UUID? = null
    ) {
        val cid = coupleId ?: return
        try {
            val path = media.uploadEncrypted(bytes, cid)
            val payload = ChatPayload(
                kind = ChatPayload.Kind.photo,
                text = caption,
                mediaHandle = path,
                sentAt = IsoDate.now()
            )
            val cipher = crypto.seal(payload)
            val row = OutgoingRow(cid.toString(), senderId.toString(), cipher, replyToId?.toString())
            client.postgrest["messages"].insert(row)
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    /**
     * v1.6.0 — video send. Mirror of sendPhoto: bytes are an already
     * re-encoded 720p H.264 MP4 (see VideoPicker). Wire shape matches iOS.
     */
    suspend fun sendVideo(
        bytes: ByteArray,
        durationSec: Int,
        senderId: UUID,
        replyToId: UUID? = null
    ) {
        val cid = coupleId ?: return
        try {
            val path = media.uploadEncrypted(bytes, cid)
            val payload = ChatPayload(
                kind = ChatPayload.Kind.video,
                text = null,
                mediaHandle = path,
                voiceDurationSec = durationSec,
                sentAt = IsoDate.now()
            )
            val cipher = crypto.seal(payload)
            val row = OutgoingRow(cid.toString(), senderId.toString(), cipher, replyToId?.toString())
            client.postgrest["messages"].insert(row)
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    /**
     * Encrypts the voice clip bytes, uploads to chat-media, then inserts a
     * `kind=voice` row. text="0:NN" stores the duration string (same as iOS).
     */
    suspend fun sendVoice(
        bytes: ByteArray,
        durationSec: Int,
        senderId: UUID,
        replyToId: UUID? = null
    ) {
        val cid = coupleId ?: return
        try {
            val path = media.uploadEncrypted(bytes, cid)
            val durationStr = String.format("0:%02d", durationSec)
            val payload = ChatPayload(
                kind = ChatPayload.Kind.voice,
                text = durationStr,
                mediaHandle = path,
                sentAt = IsoDate.now()
            )
            val cipher = crypto.seal(payload)
            val row = OutgoingRow(cid.toString(), senderId.toString(), cipher, replyToId?.toString())
            client.postgrest["messages"].insert(row)
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    suspend fun editText(messageId: UUID, newText: String) {
        val trimmed = newText.trim()
        if (trimmed.isEmpty()) return
        try {
            val cipher = crypto.seal(ChatPayload.text(trimmed))
            client.postgrest["messages"].update(
                EditPayload(cipher, Instant.now().toString())
            ) {
                filter { eq("id", messageId.toString()) }
            }
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    suspend fun unsend(messageId: UUID) {
        try {
            client.postgrest["messages"].update(
                UnsendPayload(Instant.now().toString())
            ) {
                filter { eq("id", messageId.toString()) }
            }
            fetchOnce()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    suspend fun markRead(messageId: UUID) {
        // Silent — read receipts are best-effort.
        // Supabase Kotlin 3.x `rpc(name, params)` requires params: JsonObject —
        // the older `<T : Any>` reified overload is gone. Build the JSON inline.
        runCatching {
            client.postgrest.rpc("mark_message_read", buildJsonObject {
                put("p_message_id", messageId.toString())
            })
        }
    }

    // ---------------------------------------------------------------------
    // Reactions

    suspend fun addReaction(messageId: UUID, emoji: String, userId: UUID) {
        try {
            client.postgrest["message_reactions"].insert(
                ReactionRow(messageId.toString(), userId.toString(), emoji, null)
            )
            fetchReactions()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    suspend fun removeReaction(messageId: UUID, emoji: String, userId: UUID) {
        try {
            client.postgrest["message_reactions"].delete {
                filter {
                    eq("message_id", messageId.toString())
                    eq("user_id", userId.toString())
                    eq("emoji", emoji)
                }
            }
            fetchReactions()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    // ---------------------------------------------------------------------
    // Vanish mode

    suspend fun setVanishMode(enabled: Boolean) {
        try {
            client.postgrest.rpc("set_vanish_mode", buildJsonObject {
                put("p_enabled", enabled)
            })
            _vanishMode.value = enabled
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    suspend fun refreshVanishMode() {
        val cid = coupleId ?: return
        runCatching {
            val row: VanishRow = client.postgrest["couples"]
                .select(columns = io.github.jan.supabase.postgrest.query.Columns.list("vanish_mode")) {
                    filter { eq("id", cid.toString()) }
                    limit(1)
                    single()
                }
                .decodeAs()
            _vanishMode.value = row.vanish_mode
        }
    }

    // ---------------------------------------------------------------------
    // Polling

    private suspend fun runPollLoop() {
        fetchOnce()
        while (currentCoroutineContext().isActive) {
            delay(5_000)
            if (!currentCoroutineContext().isActive) break
            fetchOnce()
        }
    }

    // ---------------------------------------------------------------------
    // Realtime — three concurrent listeners merged into one collect.

    private suspend fun runRealtimeLoop(coupleId: UUID) {
        // Channel name + filter strings MUST match iOS exactly so both
        // clients land in the same Supabase realtime room.
        val realtime = client.realtime
        val channel = realtime.channel("messages-${coupleId.toString().lowercase()}") {}

        val coupleIdString = coupleId.toString().lowercase()

        val msgInserts = channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            table = "messages"
            filter("couple_id", FilterOperator.EQ, coupleIdString)
        }
        val msgUpdates = channel.postgresChangeFlow<PostgresAction.Update>(schema = "public") {
            table = "messages"
            filter("couple_id", FilterOperator.EQ, coupleIdString)
        }
        val reactInserts = channel.postgresChangeFlow<PostgresAction.Insert>(schema = "public") {
            table = "message_reactions"
        }
        val reactDeletes = channel.postgresChangeFlow<PostgresAction.Delete>(schema = "public") {
            table = "message_reactions"
        }

        try {
            channel.subscribe(blockUntilSubscribed = true)
        } catch (t: Throwable) {
            _lastError.value = "realtime: ${t.message}"
            return
        }

        coroutineScope {
            launch { msgInserts.collect { fetchOnce() } }
            launch { msgUpdates.collect { fetchOnce() } }
            launch { reactInserts.collect { fetchReactions() } }
            launch { reactDeletes.collect { fetchReactions() } }
        }
    }

    // ---------------------------------------------------------------------
    // Fetch

    private suspend fun fetchOnce() {
        val cid = coupleId ?: return
        _isLoading.value = true
        try {
            // Order DESC + limit 500 = newest 500. Reverse below so the UI
            // still gets ascending order. Old code used ascending + limit 500
            // which silently dropped newest messages once couple exceeded 500.
            val rows: List<IncomingRow> = client.postgrest["messages"]
                .select {
                    filter { eq("couple_id", cid.toString()) }
                    order("created_at", Order.DESCENDING)
                    limit(500)
                }
                .decodeList()
                .reversed()

            val now = Instant.now()
            val decoded: MutableList<DecryptedMessage> = rows.mapNotNull { row ->
                val createdAt = Instant.parse(row.created_at)
                val expiresAt = row.expires_at?.let(Instant::parse)
                val deletedAt = row.deleted_at?.let(Instant::parse)
                val editedAt  = row.edited_at?.let(Instant::parse)
                val readAt    = row.read_at?.let(Instant::parse)

                // Client-side TTL filter — server eventually deletes via cron.
                if (expiresAt != null && expiresAt.isBefore(now)) return@mapNotNull null

                if (deletedAt != null) {
                    // Soft-deleted: keep placeholder so reply chains stay intact.
                    return@mapNotNull DecryptedMessage(
                        id = UUID.fromString(row.id),
                        senderId = UUID.fromString(row.sender_id),
                        payload = ChatPayload(
                            kind = ChatPayload.Kind.text,
                            text = null,
                            mediaHandle = null,
                            sentAt = row.created_at
                        ),
                        createdAt = createdAt,
                        decryptionFailed = false,
                        replyToId = row.reply_to_id?.let(UUID::fromString),
                        editedAt = editedAt,
                        deletedAt = deletedAt,
                        expiresAt = expiresAt,
                        readAt = readAt,
                        reactions = emptyList()
                    )
                }

                val payload = runCatching { crypto.open(row.ciphertext_b64) }.getOrNull()
                if (payload != null) {
                    DecryptedMessage(
                        id = UUID.fromString(row.id),
                        senderId = UUID.fromString(row.sender_id),
                        payload = payload,
                        createdAt = createdAt,
                        decryptionFailed = false,
                        replyToId = row.reply_to_id?.let(UUID::fromString),
                        editedAt = editedAt,
                        deletedAt = deletedAt,
                        expiresAt = expiresAt,
                        readAt = readAt,
                        reactions = emptyList()
                    )
                } else {
                    DecryptedMessage.failed(
                        id = UUID.fromString(row.id),
                        senderId = UUID.fromString(row.sender_id),
                        createdAt = createdAt
                    ).copy(
                        replyToId = row.reply_to_id?.let(UUID::fromString),
                        editedAt = editedAt,
                        deletedAt = deletedAt,
                        expiresAt = expiresAt,
                        readAt = readAt
                    )
                }
            }.toMutableList()

            // Merge cached reactions in case the message refresh races ahead
            // of the reaction refresh.
            val cached = _messages.value.associate { it.id to it.reactions }
            for (i in decoded.indices) {
                cached[decoded[i].id]?.let { existing ->
                    decoded[i] = decoded[i].copy(reactions = existing)
                }
            }

            _messages.value = decoded
        } catch (t: Throwable) {
            _lastError.value = t.message
        } finally {
            _isLoading.value = false
        }

        fetchReactions()
    }

    private suspend fun fetchReactions() {
        val ids = _messages.value.map { it.id }
        if (ids.isEmpty()) return
        runCatching {
            val rows: List<ReactionRow> = client.postgrest["message_reactions"]
                .select(columns = io.github.jan.supabase.postgrest.query.Columns.list(
                    "message_id", "user_id", "emoji", "created_at"
                )) {
                    filter { isIn("message_id", ids.map(UUID::toString)) }
                }
                .decodeList()
            val grouped = rows.groupBy { it.message_id }
            val updated = _messages.value.map { msg ->
                val list = grouped[msg.id.toString()]?.map {
                    ReactionAtom(UUID.fromString(it.user_id), it.emoji)
                }.orEmpty()
                msg.copy(reactions = list)
            }
            _messages.value = updated
        }
    }

    // ---------------------------------------------------------------------
    // Wire types — snake_case to match the JSON shape iOS produces.

    @Serializable
    private data class OutgoingRow(
        val couple_id: String,
        val sender_id: String,
        val ciphertext_b64: String,
        val reply_to_id: String?
    )

    @Serializable
    private data class EditPayload(
        val ciphertext_b64: String,
        val edited_at: String
    )

    @Serializable
    private data class UnsendPayload(val deleted_at: String)

    @Serializable
    internal data class MarkReadArgs(val p_message_id: String)

    @Serializable
    internal data class VanishArgs(val p_enabled: Boolean)

    @Serializable
    internal data class VanishRow(val vanish_mode: Boolean)

    @Serializable
    private data class ReactionRow(
        val message_id: String,
        val user_id: String,
        val emoji: String,
        val created_at: String? = null
    )

    @Serializable
    private data class IncomingRow(
        val id: String,
        val couple_id: String,
        val sender_id: String,
        val ciphertext_b64: String,
        val created_at: String,
        val reply_to_id: String? = null,
        val edited_at: String? = null,
        val deleted_at: String? = null,
        val expires_at: String? = null,
        val read_at: String? = null
    )
}
