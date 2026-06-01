import SwiftUI

// Top-level paired-state surface — translation of `App` in design-import/app.jsx.
// Hosts the 4 tabs and switches their content. Modal overlays (camera, photo viewer,
// add-event sheet) get presented from the active tab as needed.

struct MainTabView: View {
    @Environment(\.theme) private var theme

    @State private var selection: AppTab = .chat
    // v1.6.1 (problem 5) — chat reports whether its keyboard is up so we can
    // hide the bottom bar while typing (otherwise safeAreaInset would wedge
    // the bar between the keyboard and the composer).
    @State private var chatKeyboardActive = false

    private var showTabBar: Bool {
        !(selection == .chat && chatKeyboardActive)
    }

    var body: some View {
        ZStack {
            switch selection {
            case .chat: ChatView(keyboardActive: $chatKeyboardActive)
            case .time: TimeView()
            case .play: ActivitiesView()
            case .us:   ProfileView()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.paper.ignoresSafeArea())
        // v1.6.1 (problem 5) — the 4-tab bar is pinned to the real bottom
        // safe area on EVERY tab, Instagram-style. It slides away while the
        // chat keyboard is up so the composer sits flush on the keyboard.
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if showTabBar {
                DSTabBar(selection: $selection)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showTabBar)
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
