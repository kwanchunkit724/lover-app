package michel.kit.us.features.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.hapticfeedback.HapticFeedbackType
import androidx.compose.ui.platform.LocalHapticFeedback
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import michel.kit.us.data.Mood
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

/** Compact mood picker (kaomoji). Tap a mood to set; tap current to clear. */
@Composable
fun MoodPickerDialog(current: Mood?, onPick: (Mood?) -> Unit, onClose: () -> Unit) {
    val palette = LocalLoverColors.current
    Box(
        modifier = Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.35f)).clickable(onClick = onClose),
        contentAlignment = Alignment.Center
    ) {
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier.padding(horizontal = 28.dp).clip(RoundedCornerShape(24.dp))
                .background(palette.nav).padding(20.dp)
                .clickable(interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, indication = null) {}
        ) {
            Text("而家心情點呀？", style = DSText.ui(16, FontWeight.SemiBold).copy(color = palette.ink))
            Spacer(Modifier.height(16.dp))
            Row {
                Mood.entries.forEach { mood ->
                    val active = mood == current
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier.weight(1f)
                            .clip(RoundedCornerShape(14.dp))
                            .clickable { onPick(if (active) null else mood); onClose() }
                            .padding(vertical = 10.dp, horizontal = 2.dp)
                    ) {
                        Text(mood.kao, style = DSText.mono(15).copy(color = if (active) palette.rose else palette.ink))
                        Spacer(Modifier.height(4.dp))
                        Text(mood.label, style = DSText.mono(10).copy(color = if (active) palette.rose else palette.inkMuted))
                    }
                }
            }
        }
    }
}

/** Full-screen tap-to-cheer interaction. */
@Composable
fun CheerOverlay(partnerName: String, mood: Mood, onComplete: () -> Unit, onClose: () -> Unit) {
    val palette = LocalLoverColors.current
    val haptic = LocalHapticFeedback.current
    var count by remember { mutableStateOf(0) }
    var done by remember { mutableStateOf(false) }
    val target = mood.targetTaps

    LaunchedEffect(done) {
        if (done) { onComplete(); delay(1600); onClose() }
    }

    Box(
        modifier = Modifier.fillMaxSize().background(palette.paper)
            .clickable(interactionSource = remember { androidx.compose.foundation.interaction.MutableInteractionSource() }, indication = null) {
                if (!done) {
                    count += 1
                    haptic.performHapticFeedback(HapticFeedbackType.LongPress)
                    if (count >= target) done = true
                }
            },
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(if (done) mood.doneKao else mood.cheerKao, style = DSText.mono(34).copy(color = palette.ink))
            Spacer(Modifier.height(20.dp))
            Text(
                if (done) "搞掂！$partnerName ♡" else "撳爆個畫面${mood.cheerVerb}",
                style = DSText.ui(16, FontWeight.SemiBold).copy(color = palette.ink),
                textAlign = TextAlign.Center
            )
            Spacer(Modifier.height(22.dp))
            if (!done) {
                Box(contentAlignment = Alignment.Center) {
                    CircularProgressIndicator(
                        progress = { (count.toFloat() / target).coerceIn(0f, 1f) },
                        modifier = Modifier.size(120.dp),
                        color = palette.rose,
                        trackColor = palette.line,
                        strokeWidth = 8.dp
                    )
                    Text(
                        if (target == 1) "👏" else "$count/$target",
                        style = DSText.mono(18, FontWeight.Bold).copy(color = palette.rose)
                    )
                }
            }
        }
    }
}

/** Celebration shown to the partner who was cheered. */
@Composable
fun CheerReceivedOverlay(partnerName: String, mood: Mood, onClose: () -> Unit) {
    val palette = LocalLoverColors.current
    LaunchedEffect(Unit) { delay(2400); onClose() }
    Box(
        modifier = Modifier.fillMaxSize().background(palette.paper.copy(alpha = 0.98f)).clickable(onClick = onClose),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(mood.doneKao, style = DSText.mono(40).copy(color = palette.rose))
            Spacer(Modifier.height(16.dp))
            Text("$partnerName 氹返你開心喇 ♡", style = DSText.ui(17, FontWeight.SemiBold).copy(color = palette.ink))
            Spacer(Modifier.height(6.dp))
            Text("撳一下繼續", style = DSText.mono(11).copy(color = palette.inkMuted))
        }
    }
}

/** Small mood chip used in the chat header. */
@Composable
fun MoodChip(kao: String, tint: Color, faded: Boolean, bg: Color, onClick: () -> Unit) {
    Box(
        modifier = Modifier
            .clip(CircleShape)
            .background(bg)
            .clickable(onClick = onClick)
            .padding(horizontal = 8.dp, vertical = 5.dp)
    ) {
        Text(kao, style = DSText.mono(12).copy(color = tint.copy(alpha = if (faded) 0.45f else 1f)))
    }
}
