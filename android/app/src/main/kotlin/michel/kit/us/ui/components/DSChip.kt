package michel.kit.us.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

@Composable
fun DSChip(
    text: String,
    tint: Color? = null,
    modifier: Modifier = Modifier
) {
    val palette = LocalLoverColors.current
    val borderColor = tint ?: palette.lineStrong
    val textColor = tint ?: palette.inkSoft
    Text(
        text = text,
        style = DSText.mono(10).copy(color = textColor),
        modifier = modifier
            .clip(CircleShape)
            .background(palette.surface)
            .border(1.dp, borderColor, CircleShape)
            .padding(horizontal = 10.dp, vertical = 3.dp)
    )
}
