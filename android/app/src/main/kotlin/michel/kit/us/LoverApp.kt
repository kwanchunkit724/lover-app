package michel.kit.us

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.material3.TabRowDefaults.tabIndicatorOffset
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Chat
import androidx.compose.material.icons.outlined.CalendarToday
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
import kotlinx.coroutines.delay
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import michel.kit.us.features.activities.ActivitiesScreen
import michel.kit.us.features.auth.AuthScreen
import michel.kit.us.features.chat.ChatScreen

import michel.kit.us.features.onboarding.OnboardingScreen
import michel.kit.us.features.pairing.PairingScreen
import michel.kit.us.features.profile.ProfileScreen
import michel.kit.us.features.time.AnniversariesScreen
import michel.kit.us.features.time.TimeScreen
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import michel.kit.us.ui.theme.LoverAppTheme
import michel.kit.us.ui.theme.LoverPalette

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
    val profile by container.userProfile.profile.collectAsStateWithLifecycle()

    // Per-couple theme variant — Phase B Round 2. Pick the palette by the
    // theme_id stored on the partner's user row (or my own — same value
    // because both partners share a theme). Re-wrap with LoverAppTheme so
    // LocalLoverColors + Material color scheme both update.
    val partnerThemeId = container.pairing.partner.collectAsStateWithLifecycle().value?.themeId
    val themeId = profile?.themeId ?: partnerThemeId
    val palette = remember(themeId) { LoverPalette.forId(themeId) }

    // One-time: show onboarding splash on very first launch.
    var seenOnboarding by rememberSaveable { mutableStateOf(false) }

    // Sign-in / sign-out bootstrap: initial couple + profile fetch, or tear
    // everything down on logout.
    LaunchedEffect(userId) {
        val uid = userId
        if (uid != null) {
            container.pairing.refresh(uid)
            container.userProfile.refresh(uid)
        } else {
            container.crypto.reset()
            container.chat.stop()
            container.entries.stop()
            container.anniversaries.stop()
            container.presence.stop()
            container.mood.stop()
            container.meetups.stop()
            container.checklist.stop()
        }
    }

    // While signed in but not yet paired, poll for the couple row so the
    // *generator* side advances into the app the moment the partner redeems
    // the code. Owning the poll here (not just in PairingViewModel) means it
    // survives recomposition + works regardless of which pairing sub-screen
    // is shown. Without this the generator stayed stuck on the code screen.
    LaunchedEffect(userId, couple) {
        val uid = userId ?: return@LaunchedEffect
        if (couple != null) return@LaunchedEffect
        while (isActive && container.pairing.couple.value == null) {
            delay(3000)
            runCatching { container.pairing.refresh(uid) }
        }
    }

    // When the couple becomes known — at cold start (already paired) OR live
    // (just paired via the poll above) — derive the E2EE key + start every
    // per-couple repo. Keyed on couple?.id so it fires whether the couple was
    // present at sign-in or appeared later. The previous code only started
    // these inside LaunchedEffect(userId), so pairing *after* sign-in left
    // chat/crypto un-started (messages never loaded, repos never subscribed).
    LaunchedEffect(userId, couple?.id) {
        val uid = userId ?: return@LaunchedEffect
        val c = couple ?: return@LaunchedEffect
        var partner = container.pairing.partner.value
        if (partner?.publicKey == null) {
            runCatching { container.pairing.refresh(uid) }
            partner = container.pairing.partner.value
        }
        val pubKey = partner?.publicKey ?: return@LaunchedEffect
        runCatching {
            container.crypto.prepare(
                coupleId = c.coupleUuid(),
                partnerPublicKeyBase64 = pubKey,
                myPrivateKey = container.keyManager.myPrivateKey()
            )
            container.chat.start(c.coupleUuid())
            container.entries.start(c.coupleUuid())
            container.anniversaries.start(c.coupleUuid())
            container.presence.start(c.coupleUuid())
            container.mood.start(c.coupleUuid())
            container.meetups.start(c.coupleUuid())
            container.checklist.start(c.coupleUuid())
        }
    }

    // Phase C — pause heartbeat + leave presence channel on STOP (app
    // backgrounded), rejoin on START. Without this we'd keep firing the
    // 30-second update_last_seen RPC while suspended, draining battery and
    // misreporting the user as "online".
    val lifecycleOwner = androidx.lifecycle.compose.LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner, couple) {
        val obs = androidx.lifecycle.LifecycleEventObserver { _, event ->
            when (event) {
                androidx.lifecycle.Lifecycle.Event.ON_STOP -> {
                    container.presence.pause()
                    container.mood.pause()
                    container.meetups.pause()
                    container.checklist.pause()
                }
                androidx.lifecycle.Lifecycle.Event.ON_START -> {
                    couple?.let {
                        container.presence.resume(it.coupleUuid())
                        container.mood.resume(it.coupleUuid())
                        container.meetups.resume(it.coupleUuid())
                        container.checklist.resume(it.coupleUuid())
                    }
                }
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(obs)
        onDispose { lifecycleOwner.lifecycle.removeObserver(obs) }
    }

    LoverAppTheme(variant = palette) {
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
}

private enum class Tab(val labelRes: Int, val icon: androidx.compose.ui.graphics.vector.ImageVector) {
    // v1.6.0 — Memory tab removed from main nav (still reachable via Time
    // "anniversaries" entry point). Order matches iOS: 對話/時間/玩樂/我哋.
    Chat(R.string.tab_chat, Icons.Outlined.Chat),
    Time(R.string.tab_time, Icons.Outlined.CalendarToday),
    Activities(R.string.tab_activities, Icons.Outlined.Stars),
    Profile(R.string.tab_profile, Icons.Outlined.Favorite),
}

@Composable
private fun MainTabs() {
    val palette = LocalLoverColors.current
    var current by rememberSaveable { mutableStateOf(Tab.Chat) }
    var showAnniversariesFromTime by androidx.compose.runtime.remember { mutableStateOf(false) }

    // v1.6.0 — When on Chat, render the tab row at the TOP of the Chat
    // screen instead of a bottom NavigationBar. This keeps the soft keyboard
    // from competing with chat content. Other destinations keep the bottom
    // nav for muscle-memory parity with iOS.
    val onChat = current == Tab.Chat

    Scaffold(
        bottomBar = {
            if (!onChat) {
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
            }
        },
        containerColor = palette.paper
    ) { padding ->
        Box(modifier = Modifier.fillMaxSize().padding(padding)) {
            if (onChat) {
                Column(modifier = Modifier.fillMaxSize()) {
                    ChatTopTabRow(current = current, onSelect = { current = it })
                    ChatScreen()
                }
            } else {
                when (current) {
                    Tab.Chat       -> ChatScreen()
                    Tab.Activities -> ActivitiesScreen()
                    Tab.Time       -> TimeScreen(onOpenAnniversaries = { showAnniversariesFromTime = true })
                    Tab.Profile    -> ProfileScreen()
                }
            }
            if (showAnniversariesFromTime) {
                AnniversariesScreen(onClose = { showAnniversariesFromTime = false })
            }
        }
    }
}

@Composable
private fun ChatTopTabRow(current: Tab, onSelect: (Tab) -> Unit) {
    val palette = LocalLoverColors.current
    TabRow(
        selectedTabIndex = Tab.entries.indexOf(current),
        containerColor = palette.nav,
        contentColor = palette.ink,
        indicator = { positions ->
            val idx = Tab.entries.indexOf(current).coerceAtLeast(0)
            TabRowDefaults.SecondaryIndicator(
                Modifier.tabIndicatorOffset(positions[idx]),
                color = palette.rose
            )
        },
        divider = { HorizontalDivider(thickness = 0.5.dp, color = palette.line) }
    ) {
        Tab.entries.forEach { tab ->
            Tab(
                selected = current == tab,
                onClick = { onSelect(tab) },
                selectedContentColor = palette.rose,
                unselectedContentColor = palette.inkMuted,
                text = {
                    Text(
                        stringResource(tab.labelRes),
                        style = androidx.compose.material3.MaterialTheme.typography.labelMedium
                    )
                }
            )
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
