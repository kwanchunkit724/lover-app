package michel.kit.us.data

import io.github.jan.supabase.postgrest.postgrest
import io.github.jan.supabase.postgrest.query.Columns
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import java.time.LocalDate
import java.util.UUID

/**
 * Port of ios/LoverApp/Services/PairingService.swift.
 *
 * Wraps the two pairing RPCs + the couples query:
 *   create_pairing_code(p_anniversary_iso)  → 6-digit code (10-min TTL)
 *   redeem_pairing_code(p_code, p_anniversary_iso)  → atomic pair
 *
 * Tracks `couple` + `partner` state. UI routes signed-in-but-unpaired users
 * to [PairingScreen] and signed-in-and-paired users to the chat.
 */
class PairingRepository {

    @Serializable
    data class Couple(
        val id: String,
        @SerialName("user_a_id") val userAId: String,
        @SerialName("user_b_id") val userBId: String,
        @SerialName("paired_at") val pairedAt: String
    ) {
        fun coupleUuid(): UUID = UUID.fromString(id)
        fun partnerId(me: UUID): UUID? = when (UUID.fromString(userAId.lowercase())) {
            me -> UUID.fromString(userBId.lowercase())
            else -> if (UUID.fromString(userBId.lowercase()) == me) UUID.fromString(userAId.lowercase()) else null
        }
    }

    @Serializable
    data class PartnerRow(
        val id: String,
        @SerialName("my_name") val myName: String,
        @SerialName("partner_name") val partnerName: String,
        @SerialName("anniversary_iso") val anniversaryIso: String,
        @SerialName("theme_id") val themeId: String,
        @SerialName("public_key") val publicKey: String? = null
    )

    data class ActiveCode(val code: String, val anniversaryIso: String, val expiresAtEpochSec: Long)

    private val client = SupabaseClient.instance

    private val _couple = MutableStateFlow<Couple?>(null)
    val couple: StateFlow<Couple?> = _couple.asStateFlow()

    private val _partner = MutableStateFlow<PartnerRow?>(null)
    val partner: StateFlow<PartnerRow?> = _partner.asStateFlow()

    private val _activeCode = MutableStateFlow<ActiveCode?>(null)
    val activeCode: StateFlow<ActiveCode?> = _activeCode.asStateFlow()

    private val _isLoading = MutableStateFlow(false)
    val isLoading: StateFlow<Boolean> = _isLoading.asStateFlow()

    private val _lastError = MutableStateFlow<String?>(null)
    val lastError: StateFlow<String?> = _lastError.asStateFlow()

    val isPaired: Boolean get() = _couple.value != null

    /** Fetch the couple row (RLS scopes to me) + the partner user row. */
    suspend fun refresh(meId: UUID) {
        _isLoading.value = true
        try {
            val couples: List<Couple> = client.postgrest["couples"]
                .select()
                .decodeList()
            val first = couples.firstOrNull()
            _couple.value = first
            _partner.value = null
            if (first != null) {
                val partnerId = first.partnerId(meId)
                if (partnerId != null) {
                    val rows: List<PartnerRow> = client.postgrest["users"]
                        .select(columns = Columns.ALL) {
                            filter { eq("id", partnerId.toString()) }
                        }
                        .decodeList()
                    _partner.value = rows.firstOrNull()
                }
            }
        } catch (t: Throwable) {
            _lastError.value = friendly(t)
        } finally {
            _isLoading.value = false
        }
    }

    @Serializable
    internal data class CreateArgs(val p_anniversary_iso: String)

    suspend fun createCode(anniversary: LocalDate) {
        _isLoading.value = true
        _lastError.value = null
        try {
            val iso = anniversary.toString()
            // Supabase Kotlin 3.x `rpc(name, params)` requires JsonObject.
            val code: String = client.postgrest
                .rpc("create_pairing_code", buildJsonObject {
                    put("p_anniversary_iso", iso)
                })
                .decodeAs<String>()
            _activeCode.value = ActiveCode(
                code = code,
                anniversaryIso = iso,
                expiresAtEpochSec = System.currentTimeMillis() / 1000 + 10 * 60
            )
        } catch (t: Throwable) {
            _lastError.value = friendly(t)
        } finally {
            _isLoading.value = false
        }
    }

    fun clearActiveCode() {
        _activeCode.value = null
    }

    @Serializable
    internal data class RedeemArgs(val p_code: String, val p_anniversary_iso: String)

    suspend fun redeem(code: String, anniversary: LocalDate, meId: UUID): Boolean {
        _isLoading.value = true
        _lastError.value = null
        return try {
            client.postgrest.rpc("redeem_pairing_code", buildJsonObject {
                put("p_code", code)
                put("p_anniversary_iso", anniversary.toString())
            })
            refresh(meId)
            true
        } catch (t: Throwable) {
            _lastError.value = friendly(t)
            false
        } finally {
            _isLoading.value = false
        }
    }

    suspend fun unpair() {
        _isLoading.value = true
        try {
            client.postgrest.rpc("unpair")
            _couple.value = null
            _partner.value = null
            _activeCode.value = null
        } catch (t: Throwable) {
            _lastError.value = friendly(t)
        } finally {
            _isLoading.value = false
        }
    }

    // Same mapping as PairingService.swift `friendlyMessage(for:)`.
    private fun friendly(t: Throwable): String {
        val raw = t.message ?: t.toString()
        val low = raw.lowercase()
        return when {
            "anniversary_mismatch" in low -> "紀念日對唔上 — 兩個人輸入嘅日子要一樣"
            "invalid_code" in low -> "配對碼錯咗 — 再對下"
            "code_expired" in low -> "配對碼過期 — 重新生成一個"
            "already_paired" in low -> "已經配對咗 — 唔可以再 pair"
            "cannot_pair_with_self" in low -> "唔可以同自己 pair 喎 ｡°(°.◜ᯅ◝°)°｡"
            "profile_missing" in low -> "未完成註冊 — 重新登入再試"
            "not_authenticated" in low -> "未登入 — 重新登入"
            else -> raw
        }
    }
}
