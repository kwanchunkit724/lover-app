import SwiftUI

// Initial-on-tinted-circle avatar — translation of the Avatar component in ui.jsx.
// Single-letter or single-CJK-glyph initial on a rose/sage/amber background.

struct DSAvatar: View {
    @Environment(\.theme) private var theme

    let person: Person
    var size: CGFloat = 36

    var body: some View {
        let tintColor: Color = {
            switch person.tint {
            case .rose: return theme.rose
            case .sage: return theme.sage
            case .amber: return theme.amber
            }
        }()

        Text(person.initial)
            .font(.system(size: size * 0.42, weight: .semibold, design: .serif))
            .foregroundStyle(theme.isDark ? theme.paper : Color.white)
            .frame(width: size, height: size)
            .background(tintColor)
            .clipShape(Circle())
    }
}

#Preview {
    HStack(spacing: 12) {
        DSAvatar(person: .mockMe, size: 36)
        DSAvatar(person: .mockPartner, size: 48)
        DSAvatar(person: .mockMe, size: 56)
    }
    .padding()
    .background(Theme.jbeam.paper)
    .theme(.jbeam)
}
