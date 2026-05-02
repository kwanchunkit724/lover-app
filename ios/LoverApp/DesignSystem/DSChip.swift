import SwiftUI

// Pill chip — translation of the Chip component in design-import/ui.jsx.

struct DSChip: View {
    @Environment(\.theme) private var theme

    let label: String
    var active: Bool = false
    var color: Color? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        let content = Text(label)
            .font(DSText.ui(theme, 12, weight: .medium))
            .foregroundStyle(active ? Color.white : theme.inkSoft)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(active ? (color ?? theme.ink) : theme.paperAlt)
            .clipShape(Capsule())
            .lineLimit(1)

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

#Preview {
    HStack {
        DSChip(label: "全部", active: true)
        DSChip(label: "出遊")
        DSChip(label: "屋企")
    }
    .padding()
    .background(Theme.jbeam.paper)
    .theme(.jbeam)
}
