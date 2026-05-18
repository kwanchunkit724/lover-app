package michel.kit.us.features.time

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.CalendarMonth
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.lifecycle.viewmodel.compose.viewModel
import michel.kit.us.LocalAppContainer
import michel.kit.us.data.DecryptedEntry
import michel.kit.us.features.memory.EntryDetailScreen
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import michel.kit.us.util.TimeFormatting
import java.time.LocalDate
import java.time.YearMonth

/**
 * 時間 tab — calendar grid + selected-day detail + 紀念日 ribbon. Mirror of
 * ios/.../TimeView.swift v1.5.1 (no MockData fallbacks).
 *
 * Add-entry sheet + add-anniversary navigation live in [AddEntryDialog] and
 * the separate [michel.kit.us.features.time.AnniversariesScreen].
 */
@Composable
fun TimeScreen(onOpenAnniversaries: () -> Unit) {
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
    val items by vm.items.collectAsStateWithLifecycle()
    val anniv by vm.anniversaries.collectAsStateWithLifecycle()
    val selectedISO by vm.selectedISO.collectAsStateWithLifecycle()
    val viewYear by vm.viewYear.collectAsStateWithLifecycle()
    val viewMonth by vm.viewMonth.collectAsStateWithLifecycle()
    val today = remember { TimeFormatting.todayISO() }
    val scroll = rememberScrollState()

    var showAddEntry by remember { mutableStateOf(false) }
    var presented by remember { mutableStateOf<DecryptedEntry?>(null) }

    val nextAnniv = remember(anniv) {
        anniv.map { a ->
            val occ = TimeFormatting.nextOccurrence(a.payload.baseDateISO, a.payload.recur.name)
            Triple(a, occ.daysAway, occ.ordinal)
        }.minByOrNull { it.second }
    }
    val isCurrentMonth = viewYear == LocalDate.now().year && viewMonth == LocalDate.now().monthValue

    Column(modifier = Modifier.fillMaxSize().background(palette.paper).verticalScroll(scroll)) {
        if (isCurrentMonth && nextAnniv != null) {
            AnniversaryRibbon(
                title = nextAnniv.first.payload.title,
                days = nextAnniv.second,
                ordinal = nextAnniv.third,
                rose = palette.rose,
                onClick = onOpenAnniversaries
            )
        }

        // Month header
        Row(
            modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            TextButton(onClick = vm::prevMonth) {
                Text("‹", style = DSText.mono(16).copy(color = palette.inkSoft))
            }
            Column(Modifier.weight(1f)) {
                Text("$viewYear ${TimeFormatting.monthsTC[viewMonth - 1]}",
                    style = DSText.head(24).copy(color = palette.ink))
                val prefix = "%04d-%02d".format(viewYear, viewMonth)
                val month = items.filter { it.payload.dateISO.startsWith(prefix) }
                val memories = month.count { it.payload.dateISO < today }
                val upcoming = month.size - memories
                Text("$memories 個記憶 · $upcoming 個提醒",
                    style = DSText.mono(10).copy(color = palette.inkMuted))
            }
            TextButton(onClick = vm::nextMonth) {
                Text("›", style = DSText.mono(16).copy(color = palette.inkSoft))
            }
            IconButton(
                onClick = { showAddEntry = true },
                modifier = Modifier.size(34.dp).clip(CircleShape).background(palette.rose)
            ) {
                Icon(Icons.Outlined.Add, contentDescription = "新增", tint = Color.White)
            }
        }

        // Calendar grid
        MonthGrid(
            year = viewYear,
            month = viewMonth,
            todayISO = today,
            entries = items,
            selectedISO = selectedISO,
            onSelect = vm::selectISO
        )

        // Selected day section
        SelectedDaySection(
            selectedISO = selectedISO,
            today = today,
            entries = items.filter { it.payload.dateISO == selectedISO },
            onTap = { presented = it }
        )

        Spacer(Modifier.height(28.dp))
    }

    if (showAddEntry) {
        AddEntryDialog(
            initialDate = TimeFormatting.parseISO(selectedISO) ?: LocalDate.now(),
            onSubmit = { payload ->
                vm.addEntry(payload); showAddEntry = false
            },
            onClose = { showAddEntry = false }
        )
    }

    presented?.let { e ->
        EntryDetailScreen(entry = e, onClose = { presented = null })
    }
}

@Composable
private fun AnniversaryRibbon(
    title: String,
    days: Int,
    ordinal: Int?,
    rose: Color,
    onClick: () -> Unit
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 8.dp)
            .clip(RoundedCornerShape(14.dp))
            .background(rose)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text("下一個紀念日",
                style = DSText.mono(10).copy(color = Color.White.copy(alpha = 0.85f)))
            Row(verticalAlignment = Alignment.Bottom) {
                Text(title,
                    style = DSText.head(15).copy(color = Color.White))
                if (ordinal != null && ordinal > 0) {
                    Spacer(Modifier.width(4.dp))
                    Text("· 第 $ordinal 年",
                        style = DSText.ui(14).copy(color = Color.White.copy(alpha = 0.85f)))
                }
            }
        }
        Column(horizontalAlignment = Alignment.End) {
            Text("$days",
                style = DSText.head(30, FontWeight.Bold).copy(color = Color.White))
            Text("日後",
                style = DSText.mono(9).copy(color = Color.White.copy(alpha = 0.85f)))
        }
    }
}

@Composable
private fun MonthGrid(
    year: Int,
    month: Int,
    todayISO: String,
    entries: List<DecryptedEntry>,
    selectedISO: String,
    onSelect: (String) -> Unit
) {
    val palette = LocalLoverColors.current
    val ym = YearMonth.of(year, month)
    val daysInMonth = ym.lengthOfMonth()
    val firstDow = ym.atDay(1).dayOfWeek.value % 7   // Sun=0..Sat=6

    val cells: List<Int?> = buildList {
        repeat(firstDow) { add(null) }
        for (d in 1..daysInMonth) add(d)
        while (size % 7 != 0) add(null)
    }

    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 8.dp)) {
        // Weekday header
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
            TimeFormatting.weekdays.forEach { d ->
                Text(d,
                    modifier = Modifier.weight(1f).padding(vertical = 4.dp),
                    style = DSText.mono(10).copy(color = palette.inkMuted),
                    textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            }
        }
        // Grid: 7-column rows.
        cells.chunked(7).forEach { row ->
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(3.dp)) {
                row.forEach { day ->
                    Box(Modifier.weight(1f).aspectRatio(1f)) {
                        if (day != null) {
                            val iso = "%04d-%02d-%02d".format(year, month, day)
                            val dayEntries = entries.filter { it.payload.dateISO == iso }
                            DayCell(
                                day = day,
                                iso = iso,
                                isToday = iso == todayISO,
                                isSelected = iso == selectedISO,
                                isPastEmpty = iso < todayISO && dayEntries.isEmpty(),
                                entries = dayEntries,
                                onTap = { onSelect(iso) }
                            )
                        }
                    }
                }
            }
            Spacer(Modifier.height(3.dp))
        }
    }
}

@Composable
private fun DayCell(
    day: Int,
    iso: String,
    isToday: Boolean,
    isSelected: Boolean,
    isPastEmpty: Boolean,
    entries: List<DecryptedEntry>,
    onTap: () -> Unit
) {
    val palette = LocalLoverColors.current
    val bg = when {
        isToday -> palette.rose
        isPastEmpty -> Color.Transparent
        else -> palette.surface
    }
    val dayColor = when {
        isToday -> Color.White
        isPastEmpty -> palette.inkMuted
        else -> palette.ink
    }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(8.dp))
            .background(bg)
            .border(
                if (isSelected) 2.dp else 0.5.dp,
                if (isSelected) palette.rose else palette.line,
                RoundedCornerShape(8.dp)
            )
            .clickable(onClick = onTap)
            .padding(horizontal = 5.dp, vertical = 4.dp)
    ) {
        Text("$day",
            style = DSText.mono(11, if (isToday) FontWeight.Bold else FontWeight.Medium)
                .copy(color = dayColor))
        entries.take(2).forEach { e ->
            Spacer(Modifier.height(2.dp))
            Text(
                (if (e.payload.isSpecial) "♡ " else "") + e.payload.title,
                style = DSText.ui(8, FontWeight.Medium).copy(
                    color = if (isToday) Color.White else palette.rose
                ),
                maxLines = 1
            )
        }
        if (entries.size > 2) {
            Text("+${entries.size - 2}",
                style = DSText.mono(8).copy(
                    color = if (isToday) Color.White.copy(alpha = 0.8f) else palette.inkMuted
                ))
        }
    }
}

@Composable
private fun SelectedDaySection(
    selectedISO: String,
    today: String,
    entries: List<DecryptedEntry>,
    onTap: (DecryptedEntry) -> Unit
) {
    val palette = LocalLoverColors.current
    val isPast = selectedISO < today
    val isToday = selectedISO == today

    Column(Modifier.padding(horizontal = 16.dp, vertical = 20.dp)) {
        Row(verticalAlignment = Alignment.Bottom) {
            Text(if (isToday) "今日" else if (isPast) "回望" else "將至",
                style = DSText.head(18).copy(color = palette.ink))
            Spacer(Modifier.width(8.dp))
            Text("${TimeFormatting.mdString(selectedISO)} · 星期${TimeFormatting.weekday(selectedISO)}" +
                    if (entries.isEmpty()) "" else " · ${entries.size} 件事",
                style = DSText.mono(11).copy(color = palette.inkMuted))
        }
        Spacer(Modifier.height(10.dp))
        if (entries.isEmpty()) {
            EmptyDayBox(isPast = isPast, isToday = isToday)
        } else {
            entries.forEach { e ->
                EntryRow(entry = e, isPast = e.payload.dateISO < today, onTap = { onTap(e) })
                Spacer(Modifier.height(8.dp))
            }
        }
    }
}

@Composable
private fun EmptyDayBox(isPast: Boolean, isToday: Boolean) {
    val palette = LocalLoverColors.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .border(1.dp, palette.lineStrong, RoundedCornerShape(14.dp))
            .padding(24.dp),
        horizontalAlignment = Alignment.CenterHorizontally
    ) {
        Text(
            when {
                isPast -> "呢日冇記低嘢"
                isToday -> "tap \"+\" 加件事"
                else -> "冇活動"
            },
            style = DSText.ui(13).copy(color = palette.inkMuted)
        )
        Spacer(Modifier.height(4.dp))
        Text(if (isPast) "(´｡• ω •｡`)" else "＿(:3 」∠)＿",
            style = DSText.mono(16).copy(color = palette.inkSoft))
    }
}

@Composable
private fun EntryRow(entry: DecryptedEntry, isPast: Boolean, onTap: () -> Unit) {
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
        Box(Modifier.width(4.dp).height(40.dp).clip(RoundedCornerShape(50))
            .background(if (isPast) palette.sage else palette.rose))
        Spacer(Modifier.width(12.dp))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(entry.payload.title + if (entry.payload.isSpecial) " ♡" else "",
                    style = DSText.ui(15, FontWeight.SemiBold).copy(color = palette.ink))
                Spacer(Modifier.weight(1f))
                entry.payload.time?.let { t ->
                    Text(t, style = DSText.mono(12).copy(color = palette.inkSoft))
                }
            }
            entry.payload.location?.let { loc ->
                Text("📍 $loc", style = DSText.ui(12).copy(color = palette.inkSoft))
            }
        }
    }
}
