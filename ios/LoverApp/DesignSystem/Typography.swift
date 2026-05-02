import SwiftUI

// Custom font helpers. Fonts must be added to the Xcode project (Klee One,
// Zen Maru Gothic, DM Mono, Noto Serif TC, Noto Sans TC, JetBrains Mono)
// and listed under UIAppFonts in Info.plist.
//
// Each helper falls back to a system font with a matching design so previews
// still render reasonably before the font files are bundled.

extension Font {
    static func head(_ theme: Theme, size: CGFloat) -> Font {
        .custom(theme.fontHeadName, size: size, relativeTo: .title)
    }

    static func ui(_ theme: Theme, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .custom(theme.fontUIName, size: size, relativeTo: .body)
            .weight(weight)
    }

    static func mono(_ theme: Theme, size: CGFloat) -> Font {
        .custom(theme.fontMonoName, size: size, relativeTo: .caption)
    }
}

// Convenience system-font fallbacks for the design's most common sizes.
// Used inside views as `.font(.headSemibold(theme, 32))` etc.
enum DSText {
    static func head(_ theme: Theme, _ size: CGFloat) -> Font {
        Font.system(size: size, weight: .semibold, design: .serif)
    }

    static func ui(_ theme: Theme, _ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        Font.system(size: size, weight: weight, design: .rounded)
    }

    static func mono(_ theme: Theme, _ size: CGFloat) -> Font {
        Font.system(size: size, weight: .medium, design: .monospaced)
    }
}
