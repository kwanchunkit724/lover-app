package michel.kit.us.features.activities

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import michel.kit.us.data.DateCard
import michel.kit.us.data.DateCardCatalog
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

/**
 * 抽卡 — Android port of ios/.../Activities/CardDeckView.swift.
 *
 * Tap "抽張卡" to flip the card and reveal a date idea; "再抽" advances to the
 * next card the couple hasn't marked done; "我哋做過 ♡" records it locally so it
 * is excluded from future draws. The iOS version persists done cards via
 * PlayHistoryService (encrypted DB rows); Android tracks them in-memory for now
 * (DB-backed history is a follow-up) so the draw/reveal loop matches.
 */
@Composable
fun CardDeckScreen(onClose: () -> Unit) {
    val palette = LocalLoverColors.current
    val cards = DateCardCatalog.all

    var index by remember { mutableStateOf(0) }
    var flipped by remember { mutableStateOf(false) }
    val drawn = remember { mutableStateListOf<Int>() }
    val doneIds = remember { mutableStateListOf<Int>() }
    var lastSavedId by remember { mutableStateOf<Int?>(null) }

    val card = cards[index % cards.size.coerceAtLeast(1)]

    fun advanceToNextUndone() {
        val n = cards.size
        if (n == 0) return
        var next = (index + 1) % n
        var attempts = 0
        while (doneIds.contains(cards[next].id) && attempts < n) {
            next = (next + 1) % n
            attempts++
        }
        index = next
    }

    val rotation by animateFloatAsState(
        targetValue = if (flipped) 180f else 0f,
        animationSpec = tween(durationMillis = 500),
        label = "cardFlip"
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.paper)
    ) {
        // Top bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 8.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                "‹ 返",
                style = DSText.ui(16, FontWeight.SemiBold).copy(color = palette.rose),
                modifier = Modifier
                    .clip(RoundedCornerShape(8.dp))
                    .clickable(onClick = onClose)
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            )
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text("盲盒約會", style = DSText.ui(15, FontWeight.SemiBold).copy(color = palette.ink))
                Text(
                    "${drawn.size}/${cards.size} 張已抽 · 做過 ${doneIds.size} 種",
                    style = DSText.mono(10).copy(color = palette.inkMuted)
                )
            }
            Spacer(Modifier.weight(1f))
            Spacer(Modifier.width(40.dp))
        }

        Spacer(Modifier.weight(1f))

        // Card (flips around Y axis; back shown < 90°, front shown ≥ 90°)
        Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) {
            Box(
                modifier = Modifier
                    .size(width = 250.dp, height = 350.dp)
                    .graphicsLayer {
                        rotationY = rotation
                        cameraDistance = 12f * density
                    }
            ) {
                if (rotation <= 90f) {
                    CardBack(palette)
                } else {
                    // Counter-rotate so the front text isn't mirrored.
                    Box(Modifier.fillMaxSize().graphicsLayer { rotationY = 180f }) {
                        CardFront(card, palette)
                    }
                }
            }
        }

        Spacer(Modifier.weight(1f))

        // Buttons
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 20.dp, vertical = 24.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp)
        ) {
            if (!flipped) {
                DeckButton(
                    label = "抽張卡 (◕‿◕)",
                    bg = palette.rose,
                    fg = palette.bubbleMeText,
                    modifier = Modifier.weight(1f)
                ) {
                    flipped = true
                    if (!drawn.contains(card.id)) drawn.add(card.id)
                }
            } else {
                DeckButton(
                    label = "再抽",
                    bg = palette.surface,
                    fg = palette.ink,
                    border = true,
                    modifier = Modifier.weight(1f)
                ) {
                    flipped = false
                    lastSavedId = null
                    advanceToNextUndone()
                }
                val justSaved = lastSavedId == card.id
                DeckButton(
                    label = if (justSaved) "已記錄 ♡" else "我哋做過 ♡",
                    bg = if (justSaved) palette.sage else palette.rose,
                    fg = palette.bubbleMeText,
                    enabled = !justSaved,
                    modifier = Modifier.weight(1f)
                ) {
                    if (!doneIds.contains(card.id)) doneIds.add(card.id)
                    lastSavedId = card.id
                }
            }
        }
    }
}

@Composable
private fun CardBack(palette: michel.kit.us.ui.theme.LoverColors) {
    Box(
        modifier = Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(22.dp))
            .background(
                Brush.linearGradient(listOf(palette.rose, palette.amber))
            ),
        contentAlignment = Alignment.Center
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text("(♡˙︶˙♡)", style = DSText.mono(28).copy(color = Color.White))
            Spacer(Modifier.height(8.dp))
            Text("抽卡", style = DSText.head(20).copy(color = Color.White))
            Spacer(Modifier.height(8.dp))
            Text("TAP TO REVEAL", style = DSText.mono(10).copy(color = Color.White.copy(alpha = 0.7f)))
        }
    }
}

@Composable
private fun CardFront(card: DateCard, palette: michel.kit.us.ui.theme.LoverColors) {
    val tint = when (card.tint) {
        DateCard.Tint.rose -> palette.rose
        DateCard.Tint.sage -> palette.sage
        DateCard.Tint.amber -> palette.amber
    }
    val tintSoft = when (card.tint) {
        DateCard.Tint.rose -> palette.roseSoft
        DateCard.Tint.sage -> palette.sageSoft
        DateCard.Tint.amber -> palette.amberSoft
    }
    Column(
        modifier = Modifier
            .fillMaxSize()
            .clip(RoundedCornerShape(22.dp))
            .background(palette.surface)
            .border(0.5.dp, palette.line, RoundedCornerShape(22.dp))
            .padding(22.dp)
    ) {
        Text(
            "#${card.id.toString().padStart(3, '0')} · ${card.mood}",
            style = DSText.mono(9, FontWeight.SemiBold).copy(color = tint)
        )
        Spacer(Modifier.height(8.dp))
        Text(card.title, style = DSText.head(22).copy(color = palette.ink))
        Spacer(Modifier.height(10.dp))
        Text(card.detail, style = DSText.ui(13).copy(color = palette.inkSoft))
        Spacer(Modifier.weight(1f))
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Text(
                card.cost,
                style = DSText.mono(10, FontWeight.SemiBold).copy(color = tint),
                modifier = Modifier
                    .clip(RoundedCornerShape(6.dp))
                    .background(tintSoft)
                    .padding(horizontal = 8.dp, vertical = 4.dp)
            )
            Text(card.kaomoji, style = DSText.mono(16).copy(color = tint))
        }
    }
}

@Composable
private fun DeckButton(
    label: String,
    bg: Color,
    fg: Color,
    modifier: Modifier = Modifier,
    border: Boolean = false,
    enabled: Boolean = true,
    onClick: () -> Unit
) {
    val palette = LocalLoverColors.current
    Box(
        modifier = modifier
            .clip(RoundedCornerShape(14.dp))
            .background(bg)
            .then(if (border) Modifier.border(0.5.dp, palette.line, RoundedCornerShape(14.dp)) else Modifier)
            .clickable(
                enabled = enabled,
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick
            )
            .padding(vertical = 14.dp),
        contentAlignment = Alignment.Center
    ) {
        Text(label, style = DSText.ui(15, FontWeight.SemiBold).copy(color = fg))
    }
}
