package michel.kit.us.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp

/**
 * Port of ios/LoverApp/DesignSystem/Typography.swift. The iOS app bundles
 * Klee One + Zen Maru Gothic + DM Mono + Noto Serif/Sans TC. Phase A uses
 * Android system families as fallbacks (serif / sans / monospace) so the app
 * builds without font asset wiring — Phase B can swap in the same TTFs under
 * res/font/ and switch [FontFamily] references here.
 *
 * Use:
 *   Text(text, style = DSText.head(28))
 *   Text(text, style = DSText.ui(15, FontWeight.SemiBold))
 *   Text(text, style = DSText.mono(11))
 */
object DSText {
    fun head(sizeSp: Int, weight: FontWeight = FontWeight.SemiBold): TextStyle =
        TextStyle(fontFamily = FontFamily.Serif, fontWeight = weight, fontSize = sizeSp.sp)

    fun ui(sizeSp: Int, weight: FontWeight = FontWeight.Normal): TextStyle =
        TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = weight, fontSize = sizeSp.sp)

    fun mono(sizeSp: Int, weight: FontWeight = FontWeight.Medium): TextStyle =
        TextStyle(fontFamily = FontFamily.Monospace, fontWeight = weight, fontSize = sizeSp.sp)
}

@Composable
internal fun loverTypography(): Typography = Typography(
    bodyLarge  = DSText.ui(16),
    bodyMedium = DSText.ui(14),
    bodySmall  = DSText.ui(12),
    titleLarge = DSText.head(28),
    titleMedium = DSText.head(20),
    labelLarge = DSText.ui(14, FontWeight.SemiBold),
    labelMedium = DSText.mono(11),
    labelSmall = DSText.mono(10)
)
