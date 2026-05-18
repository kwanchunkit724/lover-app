package michel.kit.us.features.time

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import michel.kit.us.data.AnniversaryPayload
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import michel.kit.us.util.TimeFormatting
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * Sheet for adding a new shared anniversary — title + date + recurrence +
 * emoji picker. Mirrors iOS AddAnniversaryView.swift.
 */
@Composable
fun AddAnniversaryDialog(
    onSubmit: (AnniversaryPayload) -> Unit,
    onClose: () -> Unit
) {
    val palette = LocalLoverColors.current
    var title by remember { mutableStateOf("") }
    var date by remember { mutableStateOf(LocalDate.now()) }
    var recur by remember { mutableStateOf(AnniversaryPayload.Recur.yearly) }
    var emoji by remember { mutableStateOf("♡") }
    var showDatePicker by remember { mutableStateOf(false) }
    val emojiOptions = listOf("♡","☕","🍰","🎂","🏠","🌸","🎉","✈️","🌊","🌙","🍡")

    Dialog(
        onDismissRequest = onClose,
        properties = DialogProperties(usePlatformDefaultWidth = false)
    ) {
        Scaffold(
            containerColor = palette.paper,
            topBar = {
                TopAppBar(
                    title = { Text("新紀念日",
                        style = DSText.ui(17, FontWeight.SemiBold).copy(color = palette.ink)) },
                    navigationIcon = {
                        IconButton(onClick = onClose) {
                            Icon(Icons.Outlined.Close, contentDescription = "關閉",
                                tint = palette.inkSoft)
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
                    .padding(horizontal = 20.dp, vertical = 12.dp)
            ) {
                Label("名稱")
                Spacer(Modifier.height(6.dp))
                OutlinedTextField(
                    value = title,
                    onValueChange = { title = it },
                    placeholder = { Text("我哋一齊嘅日子", style = DSText.ui(14)) },
                    singleLine = true,
                    modifier = Modifier.fillMaxWidth()
                )

                Spacer(Modifier.height(18.dp))
                Label("日期")
                Spacer(Modifier.height(6.dp))
                Box(
                    Modifier.fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(palette.surface)
                        .border(0.5.dp, palette.line, RoundedCornerShape(12.dp))
                        .clickable { showDatePicker = true }
                        .padding(14.dp)
                ) {
                    Text(TimeFormatting.displayFromISO(TimeFormatting.isoFromDate(date)),
                        style = DSText.ui(15).copy(color = palette.ink))
                }

                Spacer(Modifier.height(18.dp))
                Label("重覆")
                Spacer(Modifier.height(6.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    RecurChip(label = "每年",
                        active = recur == AnniversaryPayload.Recur.yearly,
                        onClick = { recur = AnniversaryPayload.Recur.yearly })
                    RecurChip(label = "每月",
                        active = recur == AnniversaryPayload.Recur.monthly,
                        onClick = { recur = AnniversaryPayload.Recur.monthly })
                }

                Spacer(Modifier.height(18.dp))
                Label("Emoji")
                Spacer(Modifier.height(6.dp))
                // Manual grid (5 per row) to avoid nested LazyVerticalGrid scroll issues.
                emojiOptions.chunked(5).forEach { row ->
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        row.forEach { e ->
                            Box(
                                Modifier.size(44.dp)
                                    .clip(RoundedCornerShape(10.dp))
                                    .background(if (emoji == e) palette.roseSoft else palette.surface)
                                    .border(
                                        if (emoji == e) 1.5.dp else 0.5.dp,
                                        if (emoji == e) palette.rose else palette.line,
                                        RoundedCornerShape(10.dp)
                                    )
                                    .clickable { emoji = e },
                                contentAlignment = Alignment.Center
                            ) {
                                Text(e, style = DSText.head(22))
                            }
                        }
                    }
                    Spacer(Modifier.height(8.dp))
                }

                Spacer(Modifier.height(20.dp))
                Button(
                    onClick = {
                        onSubmit(
                            AnniversaryPayload(
                                title = title.trim(),
                                baseDateISO = TimeFormatting.isoFromDate(date),
                                recur = recur,
                                emoji = emoji
                            )
                        )
                    },
                    enabled = title.isNotBlank(),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = palette.rose,
                        contentColor = Color.White,
                        disabledContainerColor = palette.line,
                    ),
                    modifier = Modifier.fillMaxWidth().height(52.dp)
                ) {
                    Text("加入", style = DSText.ui(16, FontWeight.Medium))
                }
                Spacer(Modifier.height(28.dp))
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
private fun Label(text: String) {
    val palette = LocalLoverColors.current
    Text(text.uppercase(), style = DSText.mono(11).copy(color = palette.inkMuted))
}

@Composable
private fun RecurChip(label: String, active: Boolean, onClick: () -> Unit) {
    val palette = LocalLoverColors.current
    Box(
        Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(if (active) palette.rose else palette.surface)
            .border(
                if (active) 1.5.dp else 0.5.dp,
                if (active) palette.rose else palette.line,
                RoundedCornerShape(10.dp)
            )
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 10.dp)
    ) {
        Text(label, style = DSText.ui(14, FontWeight.Medium)
            .copy(color = if (active) Color.White else palette.inkSoft))
    }
}
