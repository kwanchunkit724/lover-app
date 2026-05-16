package michel.kit.us.domain

import androidx.compose.runtime.Immutable

/**
 * Lightweight identity card for either user. Mirror of
 * ios/LoverApp/Models/Person.swift.
 */
@Immutable
data class Person(
    val id: String,
    val name: String,
    val initial: String,
    val tint: Tint
) {
    enum class Tint { rose, sage, amber }
}
