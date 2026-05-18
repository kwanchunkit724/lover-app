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

    /**
     * Look up a palette by the `theme_id` string stored on the partner's user
     * row (mirror of iOS Theme.allThemes). Unknown ids fall back to Cream so
     * a future iOS-side theme rollout doesn't crash older Android clients.
     */
    fun forId(themeId: String?): LoverColors = when (themeId) {
        "jbeam" -> Jbeam
        "notion" -> Notion
        "cozy" -> Cozy
        "cream" -> Cream
        else -> Cream
    }

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

    /** Notion 暖紙 — paper-like neutral, mirrors iOS Theme.notion. */
    val Notion = LoverColors(
        paper = Color(0xFFFAF8F4),
        paperAlt = Color(0xFFF2EFE8),
        surface = Color(0xFFFFFFFF),
        nav = Color(0xFFFAF8F4).copy(alpha = 0.85f),
        ink = Color(0xFF2A2724),
        inkSoft = Color(0xFF5A544D),
        inkMuted = Color(0xFF9A9389),
        line = Color(0xFF2A2724).copy(alpha = 0.08f),
        lineStrong = Color(0xFF2A2724).copy(alpha = 0.14f),
        rose = Color(0xFFC97064),
        roseSoft = Color(0xFFF4E4E0),
        sage = Color(0xFF7B8A6E),
        sageSoft = Color(0xFFE4E8DD),
        amber = Color(0xFFC99554),
        amberSoft = Color(0xFFF2E5D0),
        bubbleMe = Color(0xFF2A2724),
        bubbleMeText = Color(0xFFFAF8F4),
        bubbleThem = Color(0xFFFFFFFF),
        bubbleThemText = Color(0xFF2A2724),
        bubbleThemBorder = Color(0xFF2A2724).copy(alpha = 0.08f),
        isDark = false
    )

    /** 深夜暖色 — dark mode, mirrors iOS Theme.cozy. */
    val Cozy = LoverColors(
        paper = Color(0xFF1C1916),
        paperAlt = Color(0xFF26221E),
        surface = Color(0xFF2A2622),
        nav = Color(0xFF1C1916).copy(alpha = 0.85f),
        ink = Color(0xFFF2EBE0),
        inkSoft = Color(0xFFB8AC9C),
        inkMuted = Color(0xFF7A6F62),
        line = Color(0xFFF2EBE0).copy(alpha = 0.08f),
        lineStrong = Color(0xFFF2EBE0).copy(alpha = 0.14f),
        rose = Color(0xFFE89E8E),
        roseSoft = Color(0xFFE89E8E).copy(alpha = 0.16f),
        sage = Color(0xFFA8B89A),
        sageSoft = Color(0xFFA8B89A).copy(alpha = 0.16f),
        amber = Color(0xFFE0B879),
        amberSoft = Color(0xFFE0B879).copy(alpha = 0.16f),
        bubbleMe = Color(0xFFE89E8E),
        bubbleMeText = Color(0xFF1C1916),
        bubbleThem = Color(0xFF332E29),
        bubbleThemText = Color(0xFFF2EBE0),
        bubbleThemBorder = Color(0xFFF2EBE0).copy(alpha = 0.06f),
        isDark = true
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
