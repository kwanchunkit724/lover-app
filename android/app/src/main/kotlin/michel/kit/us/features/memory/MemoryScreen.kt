package michel.kit.us.features.memory

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import michel.kit.us.LocalAppContainer
import michel.kit.us.data.DecryptedEntry
import michel.kit.us.ui.components.DSPhotoPlaceholder
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import michel.kit.us.util.TimeFormatting

/**
 * 回憶 tab — there is no dedicated iOS MemoryBookView; the iOS app surfaces
 * past entries inside the Time tab. The Android Memory tab lifts that "past
 * entries with photos" list into its own screen so users can browse memories
 * without scrolling a calendar grid.
 */
@Composable
fun MemoryScreen() {
    val container = LocalAppContainer.current
    val palette = LocalLoverColors.current
    val vm: MemoryViewModel = viewModel(
        factory = object : androidx.lifecycle.ViewModelProvider.Factory {
            @Suppress("UNCHECKED_CAST")
            override fun <T : androidx.lifecycle.ViewModel> create(modelClass: Class<T>): T =
                MemoryViewModel(container.entries) as T
        }
    )
    val items by vm.items.collectAsStateWithLifecycle()
    val today = remember { TimeFormatting.todayISO() }
    val past = remember(items, today) {
        items.filter { it.payload.dateISO < today }
            .sortedByDescending { it.payload.dateISO }
    }

    var presented by remember { mutableStateOf<DecryptedEntry?>(null) }

    Column(modifier = Modifier.fillMaxSize().background(palette.paper)) {
        // Header
        Column(Modifier.padding(horizontal = 20.dp, vertical = 16.dp)) {
            Text("回憶", style = DSText.head(32).copy(color = palette.ink))
            Spacer(Modifier.height(2.dp))
            Text("過咗嘅日子、影過嘅相", style = DSText.mono(11).copy(color = palette.inkMuted))
        }

        if (past.isEmpty()) {
            EmptyMemory()
        } else {
            LazyColumn(
                modifier = Modifier.weight(1f),
                contentPadding = PaddingValues(horizontal = 20.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {
                items(past, key = { it.id }) { entry ->
                    MemoryRow(entry, onTap = { presented = entry })
                }
            }
        }
    }

    presented?.let { entry ->
        EntryDetailScreen(entry = entry, onClose = { presented = null })
    }
}

@Composable
private fun EmptyMemory() {
    val palette = LocalLoverColors.current
    Column(
        modifier = Modifier.fillMaxWidth().padding(40.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text("(´｡• ω •｡`)",
            style = DSText.mono(36).copy(color = palette.rose))
        Spacer(Modifier.height(10.dp))
        Text("仲未有回憶",
            style = DSText.head(18).copy(color = palette.ink))
        Spacer(Modifier.height(6.dp))
        Text("過咗嘅日子會自動入呢度",
            style = DSText.ui(12).copy(color = palette.inkSoft))
    }
}

@Composable
private fun MemoryRow(entry: DecryptedEntry, onTap: () -> Unit = {}) {
    val palette = LocalLoverColors.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .background(palette.surface)
            .border(0.5.dp, palette.line, RoundedCornerShape(14.dp))
            .clickable(onClick = onTap)
            .padding(12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Box(Modifier.size(64.dp).clip(RoundedCornerShape(10.dp))) {
            // Encrypted photo decode is Round 2 — show placeholder.
            DSPhotoPlaceholder(
                id = entry.payload.coverHandle ?: entry.id.toString(),
                height = 64.dp,
                cornerRadius = 10.dp
            )
        }
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Text("已發生 · ${TimeFormatting.mdString(entry.payload.dateISO)}",
                style = DSText.mono(10).copy(color = palette.sage))
            Spacer(Modifier.height(2.dp))
            Text(entry.payload.title + if (entry.payload.isSpecial) " ♡" else "",
                style = DSText.ui(15, FontWeight.SemiBold).copy(color = palette.ink))
            entry.payload.location?.let { loc ->
                Spacer(Modifier.height(2.dp))
                Text("📍 $loc",
                    style = DSText.mono(10).copy(color = palette.inkMuted))
            }
        }
    }
}
