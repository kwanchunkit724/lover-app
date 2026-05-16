package michel.kit.us.domain

import androidx.compose.runtime.Immutable
import michel.kit.us.data.ChatPayload
import java.time.Instant
import java.util.UUID

/**
 * Decrypted in-memory chat message. Mirror of iOS
 * `ChatService.DecryptedMessage` + Models/Message.swift (we collapse the two
 * iOS types into one since Android doesn't have the legacy mock-data path).
 *
 * `payload.kind` determines which fields are meaningful:
 *   - text/kaomoji → payload.text
 *   - photo        → payload.mediaHandle + payload.text (caption)
 *   - voice        → payload.mediaHandle + payload.text ("0:23" duration str)
 *
 * IG-style flags (v1.5):
 *   - isEdited (editedAt != null) → render "已編輯" before timestamp
 *   - isDeleted (deletedAt != null) → render dashed bubble + "已撤回"
 *   - replyToId → resolve to the original message for the reply preview
 *   - readAt → render ✓ vs ✓✓ on outgoing bubbles
 *   - expiresAt → vanish-mode TTL (client-side filter for already-expired)
 */
@Immutable
data class DecryptedMessage(
    val id: UUID,
    val senderId: UUID,
    val payload: ChatPayload,
    val createdAt: Instant,
    val decryptionFailed: Boolean,
    val replyToId: UUID? = null,
    val editedAt: Instant? = null,
    val deletedAt: Instant? = null,
    val expiresAt: Instant? = null,
    val readAt: Instant? = null,
    val reactions: List<ReactionAtom> = emptyList()
) {
    val isDeleted: Boolean get() = deletedAt != null
    val isEdited: Boolean get() = editedAt != null

    companion object {
        fun failed(id: UUID, senderId: UUID, createdAt: Instant): DecryptedMessage =
            DecryptedMessage(
                id = id,
                senderId = senderId,
                payload = ChatPayload(
                    kind = ChatPayload.Kind.text,
                    text = "(無法解密 — 可能對方換咗 device)",
                    mediaHandle = null,
                    sentAt = createdAt.toString()
                ),
                createdAt = createdAt,
                decryptionFailed = true
            )
    }
}

@Immutable
data class ReactionAtom(val userId: UUID, val emoji: String)
