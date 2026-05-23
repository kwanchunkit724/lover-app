package michel.kit.us.features.time

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import michel.kit.us.data.DecryptedEntry
import michel.kit.us.data.EntryPayload
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import michel.kit.us.util.TimeFormatting
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Simplified add-entry sheet — mirrors iOS AddEntryView.swift sections
 * (title, date, tag, who, memorable). Photo cover picker is Round 2 (parity
 * with the chat camera/photo pipeline which is being built separately).
 */
@Composable
fun AddEntryDialog(
    initialDate: LocalDate,
    onSubmit: (EntryPayload) -> Unit,
    onClose: () -> Unit,
    // v1.6.0 — when non-null, prefill all fields and treat submit as edit.
    existing: DecryptedEntry? = null
) {
    val palette = LocalLoverColors.current
    val existingPayload = existing?.payload
    var title by remember { mutableStateOf(existingPayload?.title ?: "") }
    var date by remember {
        mutableStateOf(
            existingPayload?.dateISO?.let { TimeFormatting.parseISO(it) } ?: initialDate
        )
    }
    var tag by remember { mutableStateOf(existingPayload?.tag ?: "出遊") }
    var who by remember { mutableStateOf(existingPayload?.who ?: "both") }
    var memorable by remember { mutableStateOf(existingPayload?.isSpecial ?: true) }
    var showDatePicker by remember { mutableStateOf(false) }

    // v1.6.0 — future events disable photo upload. Android doesn't yet
    // expose a photo picker in this dialog (parity with Round 2 chat
    // media pipeline), so for now we just surface the hint copy so the
    // UX promise matches iOS — once a Round-2 picker lands, gate it on
    // !isFutureEvent and feed the bytes into a coverHandle update.
    val today = remember { LocalDate.now() }
    val isFutureEvent = date.isAfter(today)

    val suggestions = listOf("食飯", "睇戲", "行山", "散步", "煮嘢食", "紀念日")
    val tags = listOf("特別日子", "出遊", "食", "屋企", "散步")
    val whoOptions = listOf("both" to "我哋兩個", "mine" to "只係我", "theirs" to "只係對方")

    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Scaffold(
            containerColor = palette.paper,
            topBar = {
                TopAppBar(
                    title = {
                        Text(if (existing == null) "新提醒" else "改提醒",
                            style = DSText.ui(16, FontWeight.SemiBold)
                                .copy(color = palette.ink))
                    },
                    navigationIcon = {
                        IconButton(onClick = onClose) {
                            Icon(Icons.Outlined.Close, contentDescription = "關閉",
                                tint = palette.rose)
                        }
                    },
                    actions = {
                        TextButton(
                            enabled = title.isNotBlank(),
                            onClick = {
                                // v1.6.0 — preserve any fields from the
                                // existing payload (coverHandle, photoCount,
                                // notes, reflection, kaomoji) that this
                                // simplified Android dialog doesn't expose.
                                val payload = existingPayload?.copy(
                                    title = title.trim(),
                                    dateISO = TimeFormatting.isoFromDate(date),
                                    who = who,
                                    tag = tag,
                                    isSpecial = memorable,
                                ) ?: EntryPayload(
                                    title = title.trim(),
                                    dateISO = TimeFormatting.isoFromDate(date),
                                    proposedBy = "me",
                                    who = who,
                                    tag = tag,
                                    isSpecial = memorable,
                                )
                                onSubmit(payload)
                            }
                        ) {
                            Text(if (existing == null) "加入" else "儲存",
                                style = DSText.ui(14, FontWeight.SemiBold)
                                    .copy(color = if (title.isNotBlank()) palette.rose else palette.inkMuted))
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
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 20.dp, vertical = 16.dp)
            ) {
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    label = { Text("想做啲乜？", style = DSText.ui(13)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )
                Spacer(Modifier.height(8.dp))

                // Suggestions
                Row(
                    modifier = Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    suggestions.forEach { s ->
                        Chip(text = "＋ $s", onClick = { title = s })
                    }
                }

                Spacer(Modifier.height(22.dp))
                SectionLabel("日期")
                Spacer(Modifier.height(6.dp))
                Box(
                    Modifier.fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(palette.surface)
                        .border(0.5.dp, palette.line, RoundedCornerShape(14.dp))
                        .clickable { showDatePicker = true }
                        .padding(14.dp)
                ) {
                    Text(TimeFormatting.fullString(TimeFormatting.isoFromDate(date)),
                        style = DSText.ui(14).copy(color = palette.ink))
                }

                Spacer(Modifier.height(22.dp))
                SectionLabel("標籤")
                Spacer(Modifier.height(6.dp))
                Row(
                    Modifier.horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    tags.forEach { t ->
                        TagChip(label = "＃$t", active = t == tag, onClick = { tag = t })
                    }
                }

                Spacer(Modifier.height(22.dp))
                SectionLabel("邊個")
                Spacer(Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    whoOptions.forEach { (k, label) ->
                        WhoButton(label = label, active = who == k, modifier = Modifier.weight(1f),
                            onClick = { who = k })
                    }
                }

                Spacer(Modifier.height(22.dp))
                SectionLabel("封面相片 (可以唔加)")
                Spacer(Modifier.height(6.dp))
                Box(
                    Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(14.dp))
                        .background(palette.surface)
                        .border(0.5.dp, palette.line, RoundedCornerShape(14.dp))
                        .padding(14.dp)
                ) {
                    Column(horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.fillMaxWidth()) {
                        if (isFutureEvent) {
                            Text("活動發生後再加相",
                                style = DSText.ui(13).copy(color = palette.inkMuted))
                            Spacer(Modifier.height(4.dp))
                            Text("到時返嚟編輯就得",
                                style = DSText.mono(11).copy(color = palette.inkSoft))
                        } else {
                            // Past / today — picker not yet wired on Android.
                            // Disabled with the same copy as before so user
                            // knows it's coming. Once the chat-media picker
                            // ships here, swap this for the actual picker UI.
                            Text("相片上載即將推出",
                                style = DSText.ui(13).copy(color = palette.inkMuted))
                            Spacer(Modifier.height(4.dp))
                            Text("Round 2 wired with chat media pipeline",
                                style = DSText.mono(11).copy(color = palette.inkSoft))
                        }
                    }
                }

                Spacer(Modifier.height(22.dp))
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text("過咗之後存做記憶",
                            style = DSText.ui(14, FontWeight.Medium).copy(color = palette.ink))
                        Text("當日相片、語音、對話會自動結集",
                            style = DSText.mono(10).copy(color = palette.inkMuted))
                    }
                    Switch(checked = memorable, onCheckedChange = { memorable = it },
                        colors = SwitchDefaults.colors(checkedThumbColor = palette.rose))
                }
                Spacer(Modifier.height(30.dp))
            }
        }
    }

    if (showDatePicker) {
        val initMillis = date.atStartOfDay(ZoneId.systemDefault()).toInstant().toEpochMilli()
        val state = rememberDatePickerState(initialSelectedDateMillis = initMillis)
        DatePickerDialog(
            onDismissRequest = { showDatePicker = false },
            confirmButton = {
                TextButton(onClick = {
                    state.selectedDateMillis?.let {
                        date = Instant.ofEpochMilli(it).atZone(ZoneId.of("Asia/Hong_Kong"))
                            .toLocalDate()
                    }
                    showDatePicker = false
                }) { Text("好") }
            },
            dismissButton = {
                TextButton(onClick = { showDatePicker = false }) { Text("取消") }
            }
        ) { DatePicker(state = state) }
    }
}

@Composable
private fun SectionLabel(text: String) {
    val palette = LocalLoverColors.current
    Text(text.uppercase(),
        style = DSText.mono(10).copy(color = palette.inkMuted))
}

@Composable
private fun Chip(text: String, onClick: () -> Unit) {
    val palette = LocalLoverColors.current
    Box(
        Modifier
            .clip(RoundedCornerShape(50))
            .background(palette.surface)
            .border(1.dp, palette.line, RoundedCornerShape(50))
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) {
        Text(text, style = DSText.ui(12).copy(color = palette.inkSoft))
    }
}

@Composable
private fun TagChip(label: String, active: Boolean, onClick: () -> Unit) {
    val palette = LocalLoverColors.current
    Box(
        Modifier
            .clip(RoundedCornerShape(50))
            .background(if (active) palette.roseSoft else androidx.compose.ui.graphics.Color.Transparent)
            .border(
                if (active) 1.5.dp else 1.dp,
                if (active) palette.rose else palette.line,
                RoundedCornerShape(50)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 12.dp, vertical = 6.dp)
    ) {
        Text(label, style = DSText.ui(12).copy(color = palette.ink))
    }
}

@Composable
private fun WhoButton(label: String, active: Boolean, modifier: Modifier = Modifier, onClick: () -> Unit) {
    val palette = LocalLoverColors.current
    Box(
        modifier
            .clip(RoundedCornerShape(10.dp))
            .background(if (active) palette.roseSoft else androidx.compose.ui.graphics.Color.Transparent)
            .border(
                if (active) 1.5.dp else 1.dp,
                if (active) palette.rose else palette.line,
                RoundedCornerShape(10.dp)
            )
            .clickable(onClick = onClick)
            .padding(vertical = 8.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(label, style = DSText.ui(12).copy(color = palette.ink))
    }
}

