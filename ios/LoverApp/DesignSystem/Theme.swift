import SwiftUI

// Translation of design-import/theme.js into SwiftUI.
// jbeam (日系奶油) is the launch theme; notion + cozy stay defined for the post-v1.0 multi-theme rollout.

struct Theme: Equatable {
    let id: String
    let name: String
    let isDark: Bool

    // Surfaces
    let paper: Color
    let paperAlt: Color
    let surface: Color
    let nav: Color

    // Text
    let ink: Color
    let inkSoft: Color
    let inkMuted: Color

    // Lines
    let line: Color
    let lineStrong: Color

    // Accents
    let rose: Color
    let roseSoft: Color
    let sage: Color
    let sageSoft: Color
    let amber: Color
    let amberSoft: Color

    // Bubbles
    let bubbleMe: Color
    let bubbleMeText: Color
    let bubbleThem: Color
    let bubbleThemText: Color
    let bubbleThemBorder: Color

    // Typography — name strings only; loading is handled in Typography.swift.
    let fontHeadName: String
    let fontUIName: String
    let fontMonoName: String

    static let jbeam = Theme(
        id: "jbeam",
        name: "日系奶油",
        isDark: false,
        paper: Color(hex: "#FBF4EE"),
        paperAlt: Color(hex: "#F5E9DE"),
        surface: Color(hex: "#FFFFFF"),
        nav: Color(hex: "#FBF4EE").opacity(0.85),
        ink: Color(hex: "#3D2E27"),
        inkSoft: Color(hex: "#7A6259"),
        inkMuted: Color(hex: "#B0998F"),
        line: Color(hex: "#3D2E27").opacity(0.08),
        lineStrong: Color(hex: "#3D2E27").opacity(0.14),
        rose: Color(hex: "#D88B82"),
        roseSoft: Color(hex: "#F8DDD7"),
        sage: Color(hex: "#9CAB8B"),
        sageSoft: Color(hex: "#E5EBDB"),
        amber: Color(hex: "#D8A572"),
        amberSoft: Color(hex: "#F6E4CE"),
        bubbleMe: Color(hex: "#D88B82"),
        bubbleMeText: Color.white,
        bubbleThem: Color.white,
        bubbleThemText: Color(hex: "#3D2E27"),
        bubbleThemBorder: Color(hex: "#3D2E27").opacity(0.08),
        fontHeadName: "KleeOne-SemiBold",
        fontUIName: "ZenMaruGothic-Medium",
        fontMonoName: "DMMono-Medium"
    )

    static let notion = Theme(
        id: "notion",
        name: "Notion 暖紙",
        isDark: false,
        paper: Color(hex: "#FAF8F4"),
        paperAlt: Color(hex: "#F2EFE8"),
        surface: Color(hex: "#FFFFFF"),
        nav: Color(hex: "#FAF8F4").opacity(0.85),
        ink: Color(hex: "#2A2724"),
        inkSoft: Color(hex: "#5A544D"),
        inkMuted: Color(hex: "#9A9389"),
        line: Color(hex: "#2A2724").opacity(0.08),
        lineStrong: Color(hex: "#2A2724").opacity(0.14),
        rose: Color(hex: "#C97064"),
        roseSoft: Color(hex: "#F4E4E0"),
        sage: Color(hex: "#7B8A6E"),
        sageSoft: Color(hex: "#E4E8DD"),
        amber: Color(hex: "#C99554"),
        amberSoft: Color(hex: "#F2E5D0"),
        bubbleMe: Color(hex: "#2A2724"),
        bubbleMeText: Color(hex: "#FAF8F4"),
        bubbleThem: Color(hex: "#FFFFFF"),
        bubbleThemText: Color(hex: "#2A2724"),
        bubbleThemBorder: Color(hex: "#2A2724").opacity(0.08),
        fontHeadName: "NotoSerifTC-SemiBold",
        fontUIName: "NotoSansTC-Medium",
        fontMonoName: "JetBrainsMono-Medium"
    )

    static let cozy = Theme(
        id: "cozy",
        name: "深夜暖色",
        isDark: true,
        paper: Color(hex: "#1C1916"),
        paperAlt: Color(hex: "#26221E"),
        surface: Color(hex: "#2A2622"),
        nav: Color(hex: "#1C1916").opacity(0.85),
        ink: Color(hex: "#F2EBE0"),
        inkSoft: Color(hex: "#B8AC9C"),
        inkMuted: Color(hex: "#7A6F62"),
        line: Color(hex: "#F2EBE0").opacity(0.08),
        lineStrong: Color(hex: "#F2EBE0").opacity(0.14),
        rose: Color(hex: "#E89E8E"),
        roseSoft: Color(hex: "#E89E8E").opacity(0.16),
        sage: Color(hex: "#A8B89A"),
        sageSoft: Color(hex: "#A8B89A").opacity(0.16),
        amber: Color(hex: "#E0B879"),
        amberSoft: Color(hex: "#E0B879").opacity(0.16),
        bubbleMe: Color(hex: "#E89E8E"),
        bubbleMeText: Color(hex: "#1C1916"),
        bubbleThem: Color(hex: "#332E29"),
        bubbleThemText: Color(hex: "#F2EBE0"),
        bubbleThemBorder: Color(hex: "#F2EBE0").opacity(0.06),
        fontHeadName: "NotoSerifTC-SemiBold",
        fontUIName: "NotoSansTC-Medium",
        fontMonoName: "JetBrainsMono-Medium"
    )

    /// v1.2.1 — Cream × Ink, matches the v1.1.1 app icon palette. Becomes
    /// the new default. Same warm brown ink as jbeam but with the cleaner
    /// cream paper (#F2EBE0) instead of jbeam's slightly pink #FBF4EE so
    /// the in-app vibe matches the icon.
    static let cream = Theme(
        id: "cream",
        name: "Cream × Ink",
        isDark: false,
        paper: Color(hex: "#F2EBE0"),
        paperAlt: Color(hex: "#E8DECF"),
        surface: Color(hex: "#FBF6EE"),
        nav: Color(hex: "#F2EBE0").opacity(0.88),
        ink: Color(hex: "#3D2E27"),
        inkSoft: Color(hex: "#7A6259"),
        inkMuted: Color(hex: "#A89384"),
        line: Color(hex: "#3D2E27").opacity(0.10),
        lineStrong: Color(hex: "#3D2E27").opacity(0.18),
        rose: Color(hex: "#D08282"),
        roseSoft: Color(hex: "#F4DCD7"),
        sage: Color(hex: "#9CAB8B"),
        sageSoft: Color(hex: "#E1E8D6"),
        amber: Color(hex: "#D8A572"),
        amberSoft: Color(hex: "#F2DEC4"),
        bubbleMe: Color(hex: "#3D2E27"),
        bubbleMeText: Color(hex: "#F2EBE0"),
        bubbleThem: Color(hex: "#FBF6EE"),
        bubbleThemText: Color(hex: "#3D2E27"),
        bubbleThemBorder: Color(hex: "#3D2E27").opacity(0.10),
        fontHeadName: "KleeOne-SemiBold",
        fontUIName: "ZenMaruGothic-Medium",
        fontMonoName: "DMMono-Medium"
    )

    static let allThemes: [Theme] = [.cream, .jbeam, .notion, .cozy]
}

// MARK: - Environment

private struct ThemeKey: EnvironmentKey {
    static let defaultValue: Theme = .cream
}

extension EnvironmentValues {
    var theme: Theme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

extension View {
    func theme(_ theme: Theme) -> some View {
        environment(\.theme, theme)
    }
}
