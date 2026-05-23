package michel.kit.us.features.memory

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import kotlinx.coroutines.launch
import michel.kit.us.LocalAppContainer
import michel.kit.us.data.DecryptedEntry
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import michel.kit.us.util.TimeFormatting

/**
 * Mirror of ios/.../EntryDetailView.swift, simplified. Shown as a full-screen
 * Dialog. Same screen handles both upcoming (reminder) and past (memory)
 * entries; status pill + section list switch based on whether the entry date
 * is in the past.
 */
@Composable
fun EntryDetailScreen(
    entry: DecryptedEntry,
    onClose: () -> Unit,
    // v1.6.0 — tap "改" → host shows the AddEntryDialog pre-filled.
    onEdit: (() -> Unit)? = null
) {
    val palette = LocalLoverColors.current
    val container = LocalAppContainer.current
    val scope = rememberCoroutineScope()
    val scroll = rememberScrollState()
    val today = remember { TimeFormatting.todayISO() }
    val isPast = entry.payload.dateISO < today

    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false, dismissOnClickOutside = false)
    ) {
        Scaffold(
            containerColor = palette.paper,
            topBar = {
                TopAppBar(
                    title = {
                        Text(if (isPast) "記憶" else "提醒",
                            style = DSText.mono(11).copy(color = palette.inkMuted))
                    },
                    navigationIcon = {
                        IconButton(onClick = onClose) {
                            Icon(Icons.Outlined.Close, contentDescription = "關閉",
                                tint = palette.rose)
                        }
                    },
                    actions = {
                        // v1.6.0 — edit button (host wires the dialog).
                        if (onEdit != null) {
                            TextButton(onClick = onEdit) {
                                Text("改", style = DSText.ui(14, FontWeight.SemiBold)
                                    .copy(color = palette.rose))
                            }
                        }
                        TextButton(onClick = {
                            scope.launch {
                                container.entries.delete(entry.id)
                                onClose()
                            }
                        }) {
                            Text("刪除", style = DSText.mono(11).copy(color = palette.rose))
                        }
                    },
                    colors = TopAppBarDefaults.topAppBarColors(containerColor = palette.nav)
                )
            }
        ) { padding ->
            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(padding)
                    .verticalScroll(scroll)
                    .padding(horizontal = 20.dp, vertical = 16.dp)
            ) {
                // Status pill
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        Modifier
                            .clip(RoundedCornerShape(50))
                            .background(if (isPast) palette.sageSoft else palette.roseSoft)
                            .padding(horizontal = 8.dp, vertical = 3.dp)
                    ) {
                        Text(
                            if (isPast) "已發生 · 記憶" else "未發生 · 提醒",
                            style = DSText.mono(10)
                                .copy(color = if (isPast) palette.sage else palette.rose)
                        )
                    }
                    Spacer(Modifier.width(8.dp))
                    Text("＃${entry.payload.tag}",
                        style = DSText.mono(10).copy(color = palette.inkMuted))
                }
                Spacer(Modifier.height(8.dp))
                Text(entry.payload.title + if (entry.payload.isSpecial) " ♡" else "",
                    style = DSText.head(28).copy(color = palette.ink))
                Spacer(Modifier.height(6.dp))
                Text(TimeFormatting.fullString(entry.payload.dateISO) +
                        (entry.payload.time?.let { " · $it" } ?: ""),
                    style = DSText.mono(12).copy(color = palette.inkMuted))

                Spacer(Modifier.height(14.dp))
                // Meta row
                Row(horizontalArrangement = Arrangement.spacedBy(14.dp)) {
                    Text("📍 ${entry.payload.location ?: "冇地點"}",
                        style = DSText.ui(12).copy(color = palette.inkSoft))
                    Text("👥 " + whoLabel(entry.payload.who),
                        style = DSText.ui(12).copy(color = palette.inkSoft))
                }

                entry.payload.notes?.let { notes ->
                    Spacer(Modifier.height(18.dp))
                    SectionLabel("筆記")
                    Spacer(Modifier.height(8.dp))
                    Card(
                        modifier = Modifier.fillMaxWidth(),
                        colors = CardDefaults.cardColors(containerColor = palette.surface),
                        shape = RoundedCornerShape(14.dp)
                    ) {
                        Text("📝 $notes",
                            modifier = Modifier
                                .border(0.5.dp, palette.line, RoundedCornerShape(14.dp))
                                .padding(14.dp),
                            style = DSText.ui(14).copy(color = palette.ink))
                    }
                }

                entry.payload.reflection?.let { r ->
                    Spacer(Modifier.height(18.dp))
                    Box(
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(14.dp))
                            .background(palette.roseSoft)
                            .padding(14.dp)
                    ) {
                        Column {
                            Text("${r.from.uppercase()} 寫低",
                                style = DSText.mono(10, FontWeight.SemiBold)
                                    .copy(color = palette.rose))
                            Spacer(Modifier.height(6.dp))
                            Text(r.text,
                                style = DSText.ui(14).copy(color = palette.ink))
                            r.kaomoji?.let {
                                Spacer(Modifier.height(4.dp))
                                Text(it,
                                    style = DSText.mono(16).copy(color = palette.rose))
                            }
                        }
                    }
                }
                Spacer(Modifier.height(30.dp))
            }
        }
    }
}

@Composable
private fun SectionLabel(text: String) {
    val palette = LocalLoverColors.current
    Text(text.uppercase(),
        style = DSText.mono(10).copy(color = palette.inkMuted))
}

private fun whoLabel(who: String): String = when (who) {
    "mine"   -> "只係我"
    "theirs" -> "只係對方"
    else     -> "我哋兩個"
}
