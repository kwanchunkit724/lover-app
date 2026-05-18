package michel.kit.us.features.profile

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import michel.kit.us.LocalAppContainer
import michel.kit.us.domain.Person
import michel.kit.us.features.settings.SettingsScreen
import michel.kit.us.features.time.AnniversariesScreen
import michel.kit.us.ui.components.DSAvatar
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import michel.kit.us.util.TimeFormatting

/**
 * 我哋 tab — couple identity card, anniversaries shortcut, settings shortcut.
 * Mirror of ios/.../ProfileView.swift v1.5.1 (no MockData fallback — "…"
 * placeholders when data hasn't loaded).
 */
@Composable
fun ProfileScreen() {
    val container = LocalAppContainer.current
    val palette = LocalLoverColors.current
    val profile by container.userProfile.profile.collectAsStateWithLifecycle()
    val partner by container.pairing.partner.collectAsStateWithLifecycle()
    val couple by container.pairing.couple.collectAsStateWithLifecycle()
    val anniv by container.anniversaries.items.collectAsStateWithLifecycle()

    var showSettings by remember { mutableStateOf(false) }
    var showAnniversaries by remember { mutableStateOf(false) }

    val myName = profile?.myName ?: "…"
    val partnerName = partner?.myName ?: profile?.partnerName ?: "…"
    val me = Person(id = "me", name = myName, initial = myName.take(1), tint = Person.Tint.rose)
    val partnerP = Person(id = "partner", name = partnerName, initial = partnerName.take(1),
        tint = Person.Tint.sage)

    // Anniversary cross-check: prefer the earlier of the two (matches iOS).
    val annivISO: String? = run {
        val mine = profile?.anniversaryIso
        val theirs = partner?.anniversaryIso
        when {
            mine != null && theirs != null -> if (mine < theirs) mine else theirs
            else -> mine ?: theirs
        }
    }
    val days = annivISO?.let { TimeFormatting.daysBetween(it, TimeFormatting.todayISO()) }

    val nextAnniv = anniv.map { a ->
        val occ = TimeFormatting.nextOccurrence(a.payload.baseDateISO, a.payload.recur.name)
        Triple(a, occ.daysAway, occ.ordinal)
    }.minByOrNull { it.second }

    Column(
        modifier = Modifier.fillMaxSize().background(palette.paper)
            .verticalScroll(rememberScrollState())
    ) {
        Text("我哋",
            style = DSText.head(32).copy(color = palette.ink),
            modifier = Modifier.padding(start = 20.dp, top = 8.dp, bottom = 16.dp))

        // Identity card
        Column(
            modifier = Modifier.padding(horizontal = 20.dp).fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(palette.surface)
                .border(0.5.dp, palette.line, RoundedCornerShape(18.dp))
                .padding(20.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                DSAvatar(person = partnerP, size = 56.dp)
                Text(" ♡ ",
                    style = DSText.head(22).copy(color = palette.rose))
                DSAvatar(person = me, size = 56.dp)
            }
            Spacer(Modifier.height(14.dp))
            Text("$myName & $partnerName",
                style = DSText.head(22).copy(color = palette.ink))
            Spacer(Modifier.height(4.dp))
            if (days != null && annivISO != null) {
                Text("一齊 $days 日 · 自 ${TimeFormatting.displayFromISO(annivISO)}",
                    style = DSText.mono(11).copy(color = palette.inkMuted))
            } else {
                Text("…", style = DSText.mono(11).copy(color = palette.inkMuted))
            }
            if (couple != null) {
                Spacer(Modifier.height(10.dp))
                Box(
                    Modifier.clip(RoundedCornerShape(50))
                        .background(palette.sageSoft)
                        .padding(horizontal = 10.dp, vertical = 4.dp)
                ) {
                    Text("✓ 已配對 ♡",
                        style = DSText.mono(11).copy(color = palette.sage))
                }
            }
        }

        Spacer(Modifier.height(20.dp))

        // Anniversaries section
        Column(Modifier.padding(horizontal = 20.dp)) {
            Label("紀念日")
            Spacer(Modifier.height(8.dp))
            Column(
                Modifier.fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(palette.surface)
                    .border(0.5.dp, palette.line, RoundedCornerShape(14.dp))
            ) {
                if (anniv.isEmpty()) {
                    ProfileRow(label = "未有紀念日 · 入 + 添加", value = "→",
                        onClick = { showAnniversaries = true }, isLast = true)
                } else {
                    if (nextAnniv != null) {
                        ProfileRow(
                            label = "下一個：${nextAnniv.first.payload.title}",
                            value = "${nextAnniv.second} 日後 →",
                            onClick = { showAnniversaries = true })
                    }
                    ProfileRow(
                        label = "所有紀念日 (${anniv.size})",
                        value = "→",
                        onClick = { showAnniversaries = true },
                        isLast = true
                    )
                }
            }
        }

        Spacer(Modifier.height(22.dp))

        // Settings shortcut
        Column(Modifier.padding(horizontal = 20.dp)) {
            Label("設定")
            Spacer(Modifier.height(8.dp))
            Column(
                Modifier.fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(palette.surface)
                    .border(0.5.dp, palette.line, RoundedCornerShape(14.dp))
            ) {
                ProfileRow(label = "主題", value = "${profile?.themeId ?: "…"} →",
                    onClick = { showSettings = true })
                ProfileRow(label = "帳戶 · 登出 · 刪除", value = "→",
                    onClick = { showSettings = true }, isLast = true)
            }
        }
        Spacer(Modifier.height(40.dp))
    }

    if (showSettings) {
        SettingsScreen(onClose = { showSettings = false })
    }
    if (showAnniversaries) {
        AnniversariesScreen(onClose = { showAnniversaries = false })
    }
}

@Composable
private fun Label(text: String) {
    val palette = LocalLoverColors.current
    Text(text.uppercase(),
        style = DSText.mono(10).copy(color = palette.inkMuted))
}

@Composable
private fun ProfileRow(
    label: String,
    value: String,
    isLast: Boolean = false,
    onClick: () -> Unit
) {
    val palette = LocalLoverColors.current
    Column(Modifier.fillMaxWidth().clickable(onClick = onClick)) {
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 14.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(label, style = DSText.ui(14).copy(color = palette.ink))
            Spacer(Modifier.weight(1f))
            Text(value, style = DSText.mono(13).copy(color = palette.inkSoft))
        }
        if (!isLast) {
            Box(Modifier.fillMaxWidth().height(0.5.dp).background(palette.line))
        }
    }
}
