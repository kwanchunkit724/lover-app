package michel.kit.us.data

import io.github.jan.supabase.postgrest.postgrest
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.util.UUID

/**
 * Mirror of ios/LoverApp/Services/UserProfileStore.swift — but backed by the
 * public.users row instead of UserDefaults (Android already writes name +
 * anniversary + theme into the row at sign-up via [AuthRepository]).
 */
class UserProfileRepository {
    private val client = SupabaseClient.instance

    @Serializable
    data class UserRow(
        val id: String,
        @SerialName("my_name") val myName: String,
        @SerialName("partner_name") val partnerName: String,
        @SerialName("anniversary_iso") val anniversaryIso: String,
        @SerialName("theme_id") val themeId: String,
        @SerialName("public_key") val publicKey: String? = null
    )

    private val _profile = MutableStateFlow<UserRow?>(null)
    val profile: StateFlow<UserRow?> = _profile.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    suspend fun refresh(meId: UUID) {
        try {
            val rows: List<UserRow> = client.postgrest["users"]
                .select {
                    filter { eq("id", meId.toString()) }
                    limit(1)
                }
                .decodeList()
            _profile.value = rows.firstOrNull()
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    suspend fun setTheme(themeId: String) {
        val me = _profile.value ?: return
        try {
            client.postgrest["users"].update(buildJsonObject {
                put("theme_id", themeId)
            }) {
                filter { eq("id", me.id) }
            }
            _profile.value = me.copy(themeId = themeId)
        } catch (t: Throwable) {
            _lastError.value = t.message
        }
    }

    suspend fun deleteAccount(): Boolean = try {
        client.postgrest.rpc("delete_my_account", JsonObject(emptyMap()))
        _profile.value = null
        true
    } catch (t: Throwable) {
        _lastError.value = t.message
        false
    }
}
