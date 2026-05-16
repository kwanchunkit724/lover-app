package michel.kit.us.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

/**
 * Placeholder rendered when the photo media handle is missing or hasn't
 * downloaded yet. Real encrypted-photo download/decrypt is a Phase B feature
 * (parity with iOS EncryptedAsyncImage).
 */
@Composable
fun DSPhotoPlaceholder(
    id: String,
    height: Dp = 240.dp,
    cornerRadius: Dp = 0.dp,
    modifier: Modifier = Modifier
) {
    val palette = LocalLoverColors.current
    Box(
        modifier = modifier
            .fillMaxWidth()
            .height(height)
            .clip(RoundedCornerShape(cornerRadius))
            .background(palette.paperAlt),
        contentAlignment = Alignment.Center
    ) {
        androidx.compose.material3.Text(
            text = "📷",
            style = DSText.head(36).copy(color = palette.inkMuted)
        )
    }
}
