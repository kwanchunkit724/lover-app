import SwiftUI

// Phase 9 v0.9.0 — empty-state shown by tabs that REQUIRE a paired partner
// (chat, time, anniversary, play). Each tab swaps in this view when
// `pairing.isPaired == false`. Tapping the button presents PairingView as
// a sheet; when pairing succeeds, `pairing.isPaired` flips → parent
// re-renders the real content and the sheet auto-dismisses with the
// underlying view.

struct UnpairedPrompt: View {
    @Environment(\.theme) private var theme

    let title: String
    let subtitle: String
    let kaomoji: String

    @State private var showPairing = false

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()

            VStack(spacing: 18) {
                Spacer()

                Text(kaomoji)
                    .font(.system(size: 44, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.rose)

                Text(title)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.ink)

                Text(subtitle)
                    .font(DSText.ui(theme, 13))
                    .foregroundStyle(theme.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Button { showPairing = true } label: {
                    Text("去配對 →")
                        .font(DSText.ui(theme, 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: 220)
                        .frame(height: 48)
                        .background(theme.rose)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 6)

                Spacer()
            }
        }
        .sheet(isPresented: $showPairing) {
            PairingView()
                .theme(theme)
        }
    }
}

#Preview {
    UnpairedPrompt(
        title: "仲未配對",
        subtitle: "配對之後就可以同對方傾偈，記低你哋嘅日子。",
        kaomoji: "(´｡• ω •｡`)"
    )
    .environmentObject(UserProfileStore())
    .environmentObject(AuthService())
    .environmentObject(PairingService())
    .theme(.jbeam)
}
