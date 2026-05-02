import SwiftUI

// 4-tab bottom bar — translation of TabBar in design-import/ui.jsx.
// Tabs: 對話 / 時間 / 玩樂 / 我哋

enum AppTab: String, CaseIterable, Identifiable {
    case chat, time, play, us

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chat: return "對話"
        case .time: return "時間"
        case .play: return "玩樂"
        case .us:   return "我哋"
        }
    }

    var icon: DSIconName {
        switch self {
        case .chat: return .chat
        case .time: return .cal
        case .play: return .play
        case .us:   return .us
        }
    }
}

struct DSTabBar: View {
    @Environment(\.theme) private var theme

    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let active = tab == selection
                Button {
                    selection = tab
                } label: {
                    VStack(spacing: 3) {
                        DSIcon(
                            name: tab.icon,
                            size: 22,
                            color: active ? theme.rose : theme.inkMuted,
                            strokeWidth: active ? 2.0 : 1.5
                        )
                        Text(tab.label)
                            .font(.system(size: 10,
                                          weight: active ? .semibold : .regular))
                            .foregroundStyle(active ? theme.rose : theme.inkMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, 8)
        .padding(.bottom, 24)
        .background(theme.nav)
        .background(.thinMaterial)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
            alignment: .top
        )
    }
}

#Preview {
    DSTabBar(selection: .constant(.chat)).theme(.jbeam)
}
