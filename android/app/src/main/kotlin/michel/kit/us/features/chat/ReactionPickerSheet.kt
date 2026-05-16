package michel.kit.us.features.chat

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.unit.dp
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

/**
 * IG-style emoji reaction picker. Port of ios/.../ReactionPickerSheet.swift.
 * Shown as a full-screen overlay; tap outside closes, tap an emoji picks.
 */
private val DEFAULT_EMOJIS = listOf("❤️", "😂", "😮", "😢", "🥰", "👍")

@Composable
fun ReactionPickerSheet(
    onPick: (String) -> Unit,
    onClose: () -> Unit
) {
    val palette = LocalLoverColors.current
    // No ripple: this overlay click is a "dismiss" gesture, not a button.
    val dismissInteraction = remember { MutableInteractionSource() }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(palette.ink.copy(alpha = 0.25f))
            .clickable(
                indication = null,
                interactionSource = dismissInteraction
            ) { onClose() },
        contentAlignment = Alignment.BottomCenter
    ) {
        Row(
            modifier = Modifier
                .padding(bottom = 36.dp, start = 18.dp, end = 18.dp)
                .shadow(elevation = 12.dp, shape = RoundedCornerShape(50))
                .clip(RoundedCornerShape(50))
                .background(palette.surface)
                .padding(horizontal = 18.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(14.dp)
        ) {
            DEFAULT_EMOJIS.forEach { e ->
                Box(
                    modifier = Modifier
                        .size(44.dp)
                        .clickable {
                            onPick(e)
                            onClose()
                        },
                    contentAlignment = Alignment.Center
                ) {
                    Text(e, style = DSText.head(30))
                }
            }
        }
    }
}
