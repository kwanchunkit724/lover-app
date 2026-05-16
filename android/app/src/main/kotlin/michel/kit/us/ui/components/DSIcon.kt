package michel.kit.us.ui.components

import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * Tiny wrapper around Material Icons. The iOS app uses SF Symbols; the
 * closest Android parity is Material Symbols (already in
 * material-icons-extended).
 */
@Composable
fun DSIcon(
    icon: ImageVector,
    size: Dp = 18.dp,
    tint: Color = Color.Unspecified,
    contentDescription: String? = null,
    modifier: Modifier = Modifier
) {
    Icon(
        imageVector = icon,
        contentDescription = contentDescription,
        modifier = modifier.size(size),
        tint = tint
    )
}
