package michel.kit.us

import android.content.Context
import androidx.compose.runtime.staticCompositionLocalOf
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.Dispatchers
import michel.kit.us.data.AnniversaryRepository
import michel.kit.us.data.AuthRepository
import michel.kit.us.data.ChatRepository
import michel.kit.us.data.CryptoService
import michel.kit.us.data.EntryRepository
import michel.kit.us.data.KeyManager
import michel.kit.us.data.PairingRepository
import michel.kit.us.data.PresenceRepository
import michel.kit.us.data.SupabaseClient
import michel.kit.us.data.UserProfileRepository
import io.github.jan.supabase.auth.auth
import java.util.UUID

/**
 * Tiny manual DI container. Holds the singleton repositories so view-models
 * can grab the same instances across navigation. Avoids pulling in Hilt for
 * a 12-screen app.
 *
 * Created in [MainActivity] (per Activity, but the process is single-Activity
 * so effectively process-scoped) and exposed via [LocalAppContainer].
 */
class AppContainer(context: Context) {
    val scope: CoroutineScope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    val keyManager: KeyManager = KeyManager(context.applicationContext)
    val crypto: CryptoService = CryptoService()
    val auth: AuthRepository = AuthRepository(keyManager)
    val pairing: PairingRepository = PairingRepository()
    val chat: ChatRepository = ChatRepository(crypto, scope)
    val entries: EntryRepository = EntryRepository(crypto, scope)
    val anniversaries: AnniversaryRepository = AnniversaryRepository(crypto, scope)
    val userProfile: UserProfileRepository = UserProfileRepository()
    val presence: PresenceRepository = PresenceRepository(scope) {
        runCatching {
            SupabaseClient.instance.auth.currentUserOrNull()?.id?.let(UUID::fromString)
        }.getOrNull()
    }
}

val LocalAppContainer = staticCompositionLocalOf<AppContainer> {
    error("AppContainer not provided")
}
