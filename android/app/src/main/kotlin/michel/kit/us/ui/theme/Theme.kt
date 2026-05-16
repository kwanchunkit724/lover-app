package michel.kit.us.ui.theme

import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.staticCompositionLocalOf

/**
 * Per-couple theme variant. The iOS app stores `theme_id` on the user row and
 * both partners see the same theme. Phase A defaults to "cream" — Phase B
 * will read the actual theme_id from the partner row.
 */
val LocalLoverColors = staticCompositionLocalOf { LoverPalette.Cream }

@Composable
fun LoverAppTheme(
    variant: LoverColors = LoverPalette.Cream,
    content: @Composable () -> Unit
) {
    // Build a minimal Material3 ColorScheme from our palette so default
    // Material widgets (TextField, Button) look right. Our hand-rolled
    // components read straight from LocalLoverColors.
    val scheme = if (variant.isDark) {
        darkColorScheme(
            background = variant.paper,
            surface = variant.surface,
            primary = variant.rose,
            onPrimary = variant.bubbleMeText,
            onBackground = variant.ink,
            onSurface = variant.ink,
            secondary = variant.sage,
            outline = variant.lineStrong
        )
    } else {
        lightColorScheme(
            background = variant.paper,
            surface = variant.surface,
            primary = variant.rose,
            onPrimary = variant.bubbleMeText,
            onBackground = variant.ink,
            onSurface = variant.ink,
            secondary = variant.sage,
            outline = variant.lineStrong
        )
    }

    CompositionLocalProvider(LocalLoverColors provides variant) {
        MaterialTheme(
            colorScheme = scheme,
            typography = loverTypography(),
            content = content
        )
    }
}
