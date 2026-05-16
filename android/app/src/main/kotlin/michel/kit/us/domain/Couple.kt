package michel.kit.us.domain

import androidx.compose.runtime.Immutable
import java.time.Instant
import java.util.UUID

/** Mirror of ios/LoverApp/Services/PairingService.swift `Couple` struct. */
@Immutable
data class Couple(
    val id: UUID,
    val userAId: UUID,
    val userBId: UUID,
    val pairedAt: Instant
) {
    fun partnerId(me: UUID): UUID? = when (me) {
        userAId -> userBId
        userBId -> userAId
        else -> null
    }
}
