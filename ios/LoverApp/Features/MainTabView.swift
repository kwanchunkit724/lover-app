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
                // v1.6.0 — Chat tab owns its own top-positioned tab bar so
                // the keyboard doesn't squash the chat history. Pass the
                // selection binding through so taps in the in-chat tab bar
                // can switch tabs just like the global one.
                case .chat: ChatView(tabSelection: $selection)
                case .time: TimeView()
                case .play: ActivitiesView()
                case .us:   ProfileView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Hide the global bottom tab bar while on Chat — Chat renders
            // its own copy at the top of its own view to keep it clear of
            // the keyboard.
            if selection != .chat {
                DSTabBar(selection: $selection)
            }
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
