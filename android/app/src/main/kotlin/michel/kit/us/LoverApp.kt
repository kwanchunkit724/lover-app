package michel.kit.us

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Chat
import androidx.compose.material.icons.outlined.CalendarToday
import androidx.compose.material.icons.outlined.PhotoLibrary
import androidx.compose.material.icons.outlined.Schedule
import androidx.compose.material.icons.outlined.Favorite
import androidx.compose.material.icons.outlined.Stars
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import kotlinx.coroutines.launch
import michel.kit.us.features.activities.ActivitiesScreen
import michel.kit.us.features.auth.AuthScreen
import michel.kit.us.features.chat.ChatScreen
import michel.kit.us.features.memory.MemoryScreen
import michel.kit.us.features.onboarding.OnboardingScreen
import michel.kit.us.features.pairing.PairingScreen
import michel.kit.us.features.profile.ProfileScreen
import michel.kit.us.features.time.AnniversariesScreen
import michel.kit.us.features.time.TimeScreen
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

/**
 * Root composable. Decides which top-level screen to show based on auth +
 * pairing state — mirrors iOS RootView routing.
 *
 *   no auth session   → AuthScreen (onboarding can come before in Phase B)
 *   signed in, no pair → PairingScreen
 *   signed in + paired → MainTabs (chat is the only functional tab in Phase A)
 *
 * The flat state machine matches the iOS RootView; we collapsed the
 * Onboarding step to a "show once" rememberSaveable bool so the user can
 * skip into auth on a fresh install without ceremony.
 */
@Composable
fun LoverApp() {
    val context = LocalContext.current
    val container = remember(context) { AppContainer(context) }

    CompositionLocalProvider(LocalAppContainer provides container) {
        RootRouter()
    }
}

@Composable
private fun RootRouter() {
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    val userId by container.auth.currentUserId.collectAsStateWithLifecycle(initialValue = null)
    val couple by container.pairing.couple.collectAsStateWithLifecycle()

    // One-time: show onboarding splash on very first launch.
    var seenOnboarding by rememberSaveable { mutableStateOf(false) }

    // When we transition into signed-in, fetch the couple row + bootstrap
    // crypto (needs partner pubkey).
    LaunchedEffect(userId) {
        val uid = userId
        if (uid != null) {
            container.pairing.refresh(uid)
            container.userProfile.refresh(uid)
            val c = container.pairing.couple.value
            val partner = container.pairing.partner.value
            if (c != null && partner?.publicKey != null) {
                runCatching {
                    container.crypto.prepare(
                        coupleId = c.coupleUuid(),
                        partnerPublicKeyBase64 = partner.publicKey,
                        myPrivateKey = container.keyManager.myPrivateKey()
                    )
                    container.chat.start(c.coupleUuid())
                    container.entries.start(c.coupleUuid())
                    container.anniversaries.start(c.coupleUuid())
                }
            }
        } else {
            container.crypto.reset()
            container.chat.stop()
            container.entries.stop()
            container.anniversaries.stop()
        }
    }

    when {
        !seenOnboarding && userId == null -> OnboardingScreen(onContinue = { seenOnboarding = true })
        userId == null -> AuthScreen()
        couple == null -> PairingScreen(
            meId = userId!!,
            onPaired = { /* LaunchedEffect above re-fires when couple changes */ }
        )
        else -> MainTabs()
    }
}

private enum class Tab(val labelRes: Int, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    Chat(R.string.tab_chat, Icons.Outlined.Chat),
    Activities(R.string.tab_activities, Icons.Outlined.Stars),
    Memory(R.string.tab_memory, Icons.Outlined.PhotoLibrary),
    Time(R.string.tab_time, Icons.Outlined.CalendarToday),
    Profile(R.string.tab_profile, Icons.Outlined.Favorite),
}

@Composable
private fun MainTabs() {
    val palette = LocalLoverColors.current
    var current by rememberSaveable { mutableStateOf(Tab.Chat) }
    var showAnniversariesFromTime by androidx.compose.runtime.remember { mutableStateOf(false) }

    Scaffold(
        bottomBar = {
            NavigationBar(containerColor = palette.nav, tonalElevation = 0.dp) {
                Tab.entries.forEach { tab ->
                    NavigationBarItem(
                        selected = current == tab,
                        onClick = { current = tab },
                        icon = { Icon(tab.icon, contentDescription = null) },
                        label = { Text(stringResource(tab.labelRes), style = DSText.mono(10)) }
                    )
                }
            }
        },
        containerColor = palette.paper
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            when (current) {
                Tab.Chat       -> ChatScreen()
                Tab.Activities -> ActivitiesScreen()
                Tab.Memory     -> MemoryScreen()
                Tab.Time       -> TimeScreen(onOpenAnniversaries = { showAnniversariesFromTime = true })
                Tab.Profile    -> ProfileScreen()
            }
            if (showAnniversariesFromTime) {
                AnniversariesScreen(onClose = { showAnniversariesFromTime = false })
            }
        }
    }
}

@Composable
private fun ComingSoonPlaceholder(label: String) {
    val palette = LocalLoverColors.current
    Box(
        modifier = Modifier.fillMaxSize().background(palette.paper),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(label, style = DSText.head(28).copy(color = palette.ink))
            Spacer(Modifier.height(6.dp))
            Text(stringResource(R.string.common_coming_soon), style = DSText.mono(12).copy(color = palette.inkMuted))
        }
    }
}
