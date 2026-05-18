package michel.kit.us.domain

import androidx.compose.runtime.Immutable
import java.time.Instant

/**
 * Lightweight identity card for either user. Mirror of
 * ios/LoverApp/Models/Person.swift.
 *
 * Phase C — adds [lastSeenAt] sourced from `users.last_seen_at` on the
 * partner profile. Used by the chat header to render
 * "上次在線 X 分鐘前" when the realtime presence channel says the partner
 * is offline.
 */
@Immutable
data class Person(
    val id: String,
    val name: String,
    val initial: String,
    val tint: Tint,
    val lastSeenAt: Instant? = null
) {
    enum class Tint { rose, sage, amber }
}
