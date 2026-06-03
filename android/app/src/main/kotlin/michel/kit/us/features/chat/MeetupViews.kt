package michel.kit.us.features.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import michel.kit.us.data.Meetup
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors
import java.time.Instant
import java.time.ZoneId
import java.time.format.DateTimeFormatter

/** Countdown pill at the top of chat. Tapping opens the set dialog. */
@Composable
fun MeetupBanner(upcoming: Meetup?, onClick: () -> Unit) {
    val palette = LocalLoverColors.current
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .background(palette.roseSoft)
            .clickable(onClick = onClick)
            .padding(horizontal = 14.dp, vertical = 8.dp)
    ) {
        Text("💕", style = DSText.ui(13))
        Spacer(Modifier.width(8.dp))
        if (upcoming != null) {
            val d = upcoming.daysUntil
            Text(
                if (d <= 0) "今日見面！" else "仲有 $d 日見面",
                style = DSText.ui(13, FontWeight.SemiBold).copy(color = palette.ink)
            )
            Spacer(Modifier.width(6.dp))
            Text("· ${upcoming.title}", style = DSText.mono(11).copy(color = palette.inkMuted), maxLines = 1)
        } else {
            Text("設定下次見面", style = DSText.ui(13, FontWeight.SemiBold).copy(color = palette.rose))
        }
        Spacer(Modifier.weight(1f))
        Icon(Icons.Outlined.ChevronRight, contentDescription = null, tint = palette.inkMuted, modifier = Modifier.size(16.dp))
    }
    HorizontalDivider(thickness = 0.5.dp, color = palette.line)
}

/** Date + title picker for the next meet-up. */
@Composable
fun SetMeetupDialog(
    existing: Meetup?,
    onCreate: (dateIso: String, title: String) -> Unit,
    onCancelMeetup: (id: String) -> Unit,
    onClose: () -> Unit
) {
    val palette = LocalLoverColors.current
    val state = rememberDatePickerState()
    var title by remember { mutableStateOf("") }

    Box(
        modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.4f)).clickable(onClick = onClose),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(20.dp).clip(RoundedCornerShape(22.dp)).background(palette.nav).padding(16.dp)
                .clickable(interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, indication = null) {}
        ) {
            Text("下次幾時見面？", style = DSText.ui(17, FontWeight.SemiBold).copy(color = palette.ink))
            DatePicker(state = state, title = null, headline = null, showModeToggle = false)
            OutlinedTextField(
                value = title,
                onValueChange = { title = it },
                placeholder = { Text("做咩？(例如：睇戲、食飯)") },
                singleLine = true,
                modifier = Modifier.fillMaxWidth()
            )
            Spacer(Modifier.height(12.dp))
            Button(
                onClick = {
                    val millis = state.selectedDateMillis ?: System.currentTimeMillis()
                    val iso = Instant.ofEpochMilli(millis).atZone(ZoneId.of("Asia/Hong_Kong"))
                        .toLocalDate().format(DateTimeFormatter.ISO_LOCAL_DATE)
                    onCreate(iso, title)
                    onClose()
                },
                colors = ButtonDefaults.buttonColors(containerColor = palette.rose),
                modifier = Modifier.fillMaxWidth()
            ) { Text("確定") }

            existing?.let { m ->
                TextButton(onClick = { onCancelMeetup(m.id); onClose() }) {
                    Text("取消今次見面", style = DSText.mono(12).copy(color = palette.inkMuted))
                }
            }
        }
    }
}

/** Full-screen prompt shown on the meet-up day until the user submits a selfie. */
@Composable
fun SelfiePromptOverlay(onTake: () -> Unit, onLater: () -> Unit) {
    val palette = LocalLoverColors.current
    Box(
        modifier = Modifier.fillMaxSize().background(palette.paper),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("( ´ ▽ ` )ﾉ", style = DSText.mono(34).copy(color = palette.rose))
            Spacer(Modifier.height(18.dp))
            Text("今日見面喇！🎉", style = DSText.ui(22, FontWeight.SemiBold).copy(color = palette.ink))
            Spacer(Modifier.height(8.dp))
            Text("影張自拍留念，會自動加入紀念冊", style = DSText.ui(14).copy(color = palette.inkMuted))
            Spacer(Modifier.height(22.dp))
            Button(onClick = onTake, colors = ButtonDefaults.buttonColors(containerColor = palette.rose)) {
                Text("影自拍")
            }
            Spacer(Modifier.height(8.dp))
            TextButton(onClick = onLater) {
                Text("遲啲先", style = DSText.mono(12).copy(color = palette.inkMuted))
            }
        }
    }
}
