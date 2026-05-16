import SwiftUI

// v1.5 — IG-style emoji reaction picker. Long-press a bubble to show.
// Six default emoji + a tiny tap-target row. Tap to add (or remove if already
// reacted with that emoji from current user).

struct ReactionPickerSheet: View {
    @Environment(\.theme) private var theme
    let onPick: (String) -> Void
    let onClose: () -> Void

    private let emojis: [String] = ["❤️", "😂", "😮", "😢", "🥰", "👍"]

    var body: some View {
        ZStack {
            theme.ink.opacity(0.25)
                .ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack {
                Spacer()
                HStack(spacing: 14) {
                    ForEach(emojis, id: \.self) { e in
                        Button {
                            onPick(e)
                            onClose()
                        } label: {
                            Text(e)
                                .font(.system(size: 30))
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(theme.surface)
                .clipShape(Capsule())
                .shadow(color: theme.ink.opacity(0.18), radius: 12, x: 0, y: 4)
                .padding(.bottom, 36)
            }
        }
    }
}

#Preview {
    ReactionPickerSheet(onPick: { _ in }, onClose: {})
        .theme(.jbeam)
}
