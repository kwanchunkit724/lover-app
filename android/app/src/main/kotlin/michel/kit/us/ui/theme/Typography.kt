package michel.kit.us.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import michel.kit.us.R

/**
 * Port of ios/LoverApp/DesignSystem/Typography.swift.
 *
 * Phase B Round 2: bundles the same three Google Fonts the iOS app uses —
 * Klee One (serif body / brand titles), Zen Maru Gothic (sans-serif UI),
 * DM Mono (monospace timestamps). All three are SIL OFL 1.1 — see
 * res/font/OFL.txt for the license.
 *
 * Use:
 *   Text(text, style = DSText.head(28))
 *   Text(text, style = DSText.ui(15, FontWeight.SemiBold))
 *   Text(text, style = DSText.mono(11))
 */
private val KleeOneFamily = FontFamily(
    Font(R.font.kleeone_regular, FontWeight.Normal),
    Font(R.font.kleeone_semibold, FontWeight.SemiBold)
)

private val ZenMaruGothicFamily = FontFamily(
    Font(R.font.zenmarugothic_regular, FontWeight.Normal),
    Font(R.font.zenmarugothic_medium, FontWeight.Medium)
)

private val DMMonoFamily = FontFamily(
    Font(R.font.dmmono_regular, FontWeight.Normal),
    Font(R.font.dmmono_medium, FontWeight.Medium)
)

object DSText {
    fun head(sizeSp: Int, weight: FontWeight = FontWeight.SemiBold): TextStyle =
        TextStyle(fontFamily = KleeOneFamily, fontWeight = weight, fontSize = sizeSp.sp)

    fun ui(sizeSp: Int, weight: FontWeight = FontWeight.Normal): TextStyle =
        TextStyle(fontFamily = ZenMaruGothicFamily, fontWeight = weight, fontSize = sizeSp.sp)

    fun mono(sizeSp: Int, weight: FontWeight = FontWeight.Medium): TextStyle =
        TextStyle(fontFamily = DMMonoFamily, fontWeight = weight, fontSize = sizeSp.sp)
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
