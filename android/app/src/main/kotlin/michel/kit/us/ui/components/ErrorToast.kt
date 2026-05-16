package michel.kit.us.ui.components

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import kotlinx.coroutines.delay
import michel.kit.us.ui.theme.DSText
import michel.kit.us.ui.theme.LocalLoverColors

/**
 * Thin error banner that fades in for a few seconds when an error string is
 * surfaced from a repository / view-model. Use:
 *
 *   ErrorToast(message = vm.error)
 */
@Composable
fun ErrorToast(message: String?, modifier: Modifier = Modifier) {
    val palette = LocalLoverColors.current
    var visible by remember(message) { mutableStateOf(message != null) }
    LaunchedEffect(message) {
        if (message != null) {
            visible = true
            delay(3500)
            visible = false
        }
    }
    AnimatedVisibility(
        visible = visible && message != null,
        enter = fadeIn(),
        exit = fadeOut(),
        modifier = modifier
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 14.dp, vertical = 8.dp)
                .clip(RoundedCornerShape(10.dp))
                .background(palette.rose)
                .padding(horizontal = 14.dp, vertical = 10.dp),
            contentAlignment = Alignment.CenterStart
        ) {
            Text(text = message.orEmpty(), style = DSText.ui(13).copy(color = palette.surface))
        }
    }
}
