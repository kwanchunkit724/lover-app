package michel.kit.us.features.time

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import michel.kit.us.LocalAppContainer
import michel.kit.us.data.AnniversaryPayload
import michel.kit.us.data.DecryptedAnniversary
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import michel.kit.us.util.TimeFormatting

/**
 * Full anniversaries list — port of ios/.../AnniversariesView.swift. Hero card
 * for the soonest, then list with countdown badges. Add via [AddAnniversaryDialog].
 */
@Composable
fun AnniversariesScreen(onClose: () -> Unit) {
    val container = LocalAppContainer.current
    val meId by container.auth.currentUserId.collectAsStateWithLifecycle(initialValue = null)
    val vm: TimeViewModel = viewModel(
        factory = object : androidx.lifecycle.ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T =
                TimeViewModel(container.entries, container.anniversaries, meIdProvider = { meId }) as T
        }
    )
    val palette = LocalLoverColors.current
    val items by vm.anniversaries.collectAsStateWithLifecycle()

    var showAdd by remember { mutableStateOf(false) }

    val sorted = remember(items) {
        items.map { a ->
            val occ = TimeFormatting.nextOccurrence(a.payload.baseDateISO, a.payload.recur.name)
            Triple(a, occ.daysAway, occ)
        }.sortedBy { it.second }
    }

    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Scaffold(
            containerColor = palette.paper,
            topBar = {
                TopAppBar(
                    title = {
                        Text("紀念日", style = DSText.ui(17, FontWeight.SemiBold)
                            .copy(color = palette.ink))
                    },
                    navigationIcon = {
                        IconButton(onClick = onClose) {
                            Icon(Icons.Outlined.ArrowBack, contentDescription = "返回",
                                tint = palette.rose)
                        }
                    },
                    actions = {
                        IconButton(onClick = { showAdd = true }) {
                            Icon(Icons.Outlined.Add, contentDescription = "新增",
                                tint = palette.rose)
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = palette.nav)
                )
            }
        ) { padding ->
            if (sorted.isEmpty()) {
                EmptyState(padding = padding, onAdd = { showAdd = true })
            } else {
                LazyColumn(
                    modifier = Modifier.fillMaxSize().padding(padding),
                    contentPadding = PaddingValues(horizontal = 20.dp, vertical = 16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    item { HeroCard(sorted.first(), rose = palette.rose) }
                    item {
                        Text("所有 · ${sorted.size} 個",
                            style = DSText.mono(10).copy(color = palette.inkMuted))
                    }
                    items(sorted.drop(1), key = { it.first.id }) { (a, days, occ) ->
                        AnniversaryRow(a = a, days = days, isoDate = occ.isoDate,
                            onDelete = { vm.deleteAnniversary(a.id) })
                    }
                    item {
                        AddButton(onClick = { showAdd = true })
                    }
                }
            }
        }
    }

    if (showAdd) {
        AddAnniversaryDialog(
            onSubmit = { vm.addAnniversary(it); showAdd = false },
            onClose = { showAdd = false }
        )
    }
}

@Composable
private fun EmptyState(padding: PaddingValues, onAdd: () -> Unit) {
    val palette = LocalLoverColors.current
    Column(
        modifier = Modifier.fillMaxSize().padding(padding).padding(top = 60.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("(´｡• ω •｡`)", style = DSText.mono(40).copy(color = palette.rose))
        Spacer(Modifier.height(14.dp))
        Text("仲未有紀念日", style = DSText.head(18).copy(color = palette.ink))
        Spacer(Modifier.height(6.dp))
        Text("加返你哋一齊嘅日子、生日、月誌\n兩個人都會見到",
            style = DSText.ui(12).copy(color = palette.inkSoft))
        Spacer(Modifier.height(16.dp))
        AddButton(onClick = onAdd)
    }
}

@Composable
private fun AddButton(onClick: () -> Unit) {
    val palette = LocalLoverColors.current
    Box(
        Modifier
            .fillMaxWidth()
            .padding(horizontal = 24.dp)
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, palette.lineStrong, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(14.dp),
        contentAlignment = Alignment.Center
    ) {
        Text("＋ 加新紀念日",
            style = DSText.ui(13).copy(color = palette.inkMuted))
    }
}

@Composable
private fun HeroCard(triple: Triple<DecryptedAnniversary, Int, TimeFormatting.Occurrence>, rose: Color) {
    val (a, days, occ) = triple
    Box(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(rose)
            .padding(20.dp)
    ) {
        Column {
            Text("下一個 · 倒數中",
                style = DSText.mono(10).copy(color = Color.White.copy(alpha = 0.8f)))
            Spacer(Modifier.height(4.dp))
            Text(a.payload.title,
                style = DSText.head(22).copy(color = Color.White))
            Spacer(Modifier.height(4.dp))
            Text("${occ.isoDate} · 星期${TimeFormatting.weekday(occ.isoDate)}" +
                    if ((occ.ordinal ?: 0) > 0) " · 第 ${occ.ordinal} 年" else "",
                style = DSText.mono(12).copy(color = Color.White.copy(alpha = 0.85f)))
            Spacer(Modifier.height(18.dp))
            Row(verticalAlignment = Alignment.Bottom) {
                Text("$days", style = DSText.head(56, FontWeight.Bold).copy(color = Color.White))
                Spacer(Modifier.width(8.dp))
                Text("日後 ♡",
                    style = DSText.mono(14).copy(color = Color.White.copy(alpha = 0.9f)))
            }
        }
    }
}

@Composable
private fun AnniversaryRow(
    a: DecryptedAnniversary,
    days: Int,
    isoDate: String,
    onDelete: () -> Unit
) {
    val palette = LocalLoverColors.current
    var menu by remember { mutableStateOf(false) }
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(palette.surface)
            .border(0.5.dp, palette.line, RoundedCornerShape(14.dp))
            .clickable(onClick = { menu = true })
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(
            Modifier.size(44.dp).clip(CircleShape).background(palette.roseSoft),
            contentAlignment = Alignment.Center
        ) {
            Text(a.payload.emoji ?: "♡", style = DSText.head(22))
        }
        Spacer(Modifier.width(14.dp))
        Column(Modifier.weight(1f)) {
            Text(a.payload.title,
                style = DSText.ui(14, FontWeight.SemiBold).copy(color = palette.ink))
            Text("$isoDate · ${if (a.payload.recur.name == "yearly") "年" else "月"}",
                style = DSText.mono(11).copy(color = palette.inkMuted))
        }
        Column(horizontalAlignment = Alignment.End) {
            Text("$days", style = DSText.head(18).copy(color = palette.rose))
            Text("日後", style = DSText.mono(10).copy(color = palette.inkMuted))
        }
        DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
            DropdownMenuItem(
                text = { Text("刪除") },
                onClick = { menu = false; onDelete() }
            )
        }
    }
}
