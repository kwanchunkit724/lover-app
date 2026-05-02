import SwiftUI

// Top-level paired-state surface — translation of `App` in design-import/app.jsx.
// Hosts the 4 tabs and switches their content. Modal overlays (camera, photo viewer,
// add-event sheet) get presented from the active tab as needed.

struct MainTabView: View {
    @Environment(\.theme) private var theme

    @State private var selection: AppTab = .chat

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                switch selection {
                case .chat: ChatView()
                case .time: PlaceholderTab(label: "時間 tab — v0.3")
                case .play: PlaceholderTab(label: "玩樂 tab — v0.5")
                case .us:   PlaceholderTab(label: "我哋 tab — v0.4")
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            DSTabBar(selection: $selection)
        }
        .background(theme.paper.ignoresSafeArea())
    }
}

private struct PlaceholderTab: View {
    @Environment(\.theme) private var theme
    let label: String

    var body: some View {
        VStack(spacing: 12) {
            Text("(´｡• ω •｡`)")
                .font(DSText.mono(theme, 28))
                .foregroundStyle(theme.rose)
            Text(label)
                .font(DSText.ui(theme, 14))
                .foregroundStyle(theme.inkSoft)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.paper)
    }
}

#Preview {
    MainTabView().theme(.jbeam)
}
