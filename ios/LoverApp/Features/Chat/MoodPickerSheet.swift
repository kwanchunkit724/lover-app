import SwiftUI

// v1.6.1 Feature 7 — compact mood picker shown from the chat header.
struct MoodPickerSheet: View {
    @Environment(\.theme) private var theme
    let current: Mood?
    let onPick: (Mood?) -> Void
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 16) {
                Text("而家心情點呀？")
                    .font(DSText.ui(theme, 16, weight: .semibold))
                    .foregroundStyle(theme.ink)

                HStack(spacing: 14) {
                    ForEach(Mood.allCases) { mood in
                        let active = mood == current
                        Button {
                            onPick(active ? nil : mood)   // tap current to clear
                            onClose()
                        } label: {
                            VStack(spacing: 6) {
                                Text(mood.emoji).font(.system(size: 34))
                                Text(mood.label)
                                    .font(DSText.mono(theme, 10))
                                    .foregroundStyle(active ? theme.rose : theme.inkMuted)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 8)
                            .background {
                                if active {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(theme.roseSoft)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                if current != nil {
                    Button { onPick(nil); onClose() } label: {
                        Text("清除心情")
                            .font(DSText.mono(theme, 11))
                            .foregroundStyle(theme.inkMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(22)
            .background(
                RoundedRectangle(cornerRadius: 26, style: .continuous).fill(theme.nav)
            )
            .padding(.horizontal, 28)
        }
    }
}
