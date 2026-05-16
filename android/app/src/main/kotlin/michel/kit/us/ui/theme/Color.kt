package michel.kit.us.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Color

/**
 * Color tokens — port of ios/LoverApp/DesignSystem/Theme.swift. We ship the
 * jbeam + cream variants for Phase A (cream is the default, matching the
 * iOS v1.2.1+ launch theme). notion + cozy live as commented-out Phase B
 * placeholders.
 */
@Immutable
data class LoverColors(
    val paper: Color,
    val paperAlt: Color,
    val surface: Color,
    val nav: Color,
    val ink: Color,
    val inkSoft: Color,
    val inkMuted: Color,
    val line: Color,
    val lineStrong: Color,
    val rose: Color,
    val roseSoft: Color,
    val sage: Color,
    val sageSoft: Color,
    val amber: Color,
    val amberSoft: Color,
    val bubbleMe: Color,
    val bubbleMeText: Color,
    val bubbleThem: Color,
    val bubbleThemText: Color,
    val bubbleThemBorder: Color,
    val isDark: Boolean
)

object LoverPalette {

    /** v1.2.1 — Cream × Ink. Matches the v1.1.1 app icon palette. Default theme. */
    val Cream = LoverColors(
        paper = Color(0xFFF2EBE0),
        paperAlt = Color(0xFFE8DECF),
        surface = Color(0xFFFBF6EE),
        nav = Color(0xFFF2EBE0).copy(alpha = 0.88f),
        ink = Color(0xFF3D2E27),
        inkSoft = Color(0xFF7A6259),
        inkMuted = Color(0xFFA89384),
        line = Color(0xFF3D2E27).copy(alpha = 0.10f),
        lineStrong = Color(0xFF3D2E27).copy(alpha = 0.18f),
        rose = Color(0xFFD08282),
        roseSoft = Color(0xFFF4DCD7),
        sage = Color(0xFF9CAB8B),
        sageSoft = Color(0xFFE1E8D6),
        amber = Color(0xFFD8A572),
        amberSoft = Color(0xFFF2DEC4),
        bubbleMe = Color(0xFF3D2E27),
        bubbleMeText = Color(0xFFF2EBE0),
        bubbleThem = Color(0xFFFBF6EE),
        bubbleThemText = Color(0xFF3D2E27),
        bubbleThemBorder = Color(0xFF3D2E27).copy(alpha = 0.10f),
        isDark = false
    )

    /** 日系奶油 — the original launch theme, slightly pinker than cream. */
    val Jbeam = LoverColors(
        paper = Color(0xFFFBF4EE),
        paperAlt = Color(0xFFF5E9DE),
        surface = Color(0xFFFFFFFF),
        nav = Color(0xFFFBF4EE).copy(alpha = 0.85f),
        ink = Color(0xFF3D2E27),
        inkSoft = Color(0xFF7A6259),
        inkMuted = Color(0xFFB0998F),
        line = Color(0xFF3D2E27).copy(alpha = 0.08f),
        lineStrong = Color(0xFF3D2E27).copy(alpha = 0.14f),
        rose = Color(0xFFD88B82),
        roseSoft = Color(0xFFF8DDD7),
        sage = Color(0xFF9CAB8B),
        sageSoft = Color(0xFFE5EBDB),
        amber = Color(0xFFD8A572),
        amberSoft = Color(0xFFF6E4CE),
        bubbleMe = Color(0xFFD88B82),
        bubbleMeText = Color.White,
        bubbleThem = Color.White,
        bubbleThemText = Color(0xFF3D2E27),
        bubbleThemBorder = Color(0xFF3D2E27).copy(alpha = 0.08f),
        isDark = false
    )
}
