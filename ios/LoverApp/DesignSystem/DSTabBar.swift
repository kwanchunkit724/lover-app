import SwiftUI

// KK tabs. Kaomoji is the icon. Time / Activities are not in the shell.

enum AppTab: String, CaseIterable, Identifiable {
    case chat, memory, want, us

    var id: String { rawValue }

    var label: String {
        switch self {
        case .chat:   return "對話"
        case .memory: return "記憶空間"
        case .want:   return "想你知道"
        case .us:     return "我哋"
        }
    }

    var kao: String {
        switch self {
        case .chat:   return "(｡•̀ᴗ-)✧"
        case .memory: return "(´∀｀)♡"
        case .want:   return "(´ε｀ )♡"
        case .us:     return "(♡˙︶˙♡)"
        }
    }
}

struct DSTabBar: View {
    @Environment(\.theme) private var theme

    @Binding var selection: AppTab
    // v1.6.0 — `top` placement is used by ChatView so the 4-tab nav doesn't
    // sit at the bottom (where the keyboard pushes it up + eats chat area).
    // Same labels + active-tint visual; trimmed paddings + divider flipped
    // to the bottom edge.
    var placement: Placement = .bottom

    enum Placement { case top, bottom }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                let active = tab == selection
                Button {
                    selection = tab
                } label: {
                    // v1.6.1 (problem 5) — Instagram-style: icon-forward, the
                    // label only shows on the ACTIVE tab inside a soft rose
                    // pill. Smaller footprint than the old always-on label.
                    HStack(spacing: 5) {
                        Text(tab.kao)
                            .font(.system(size: active ? 13 : 12, design: .monospaced))
                            .foregroundStyle(active ? theme.rose : theme.inkMuted)
                            .lineLimit(1)
                            .minimumScaleFactor(0.6)
                        if active {
                            Text(tab.label)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(theme.rose)
                                .fixedSize()
                                .transition(.opacity.combined(with: .scale))
                        }
                    }
                    .padding(.horizontal, active ? 12 : 8)
                    .padding(.vertical, 6)
                    .background {
                        if active {
                            Capsule(style: .continuous).fill(theme.roseSoft)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // Combine the kaomoji and the optional title into one button.
                // A container identifier on the bar hid these from XCUITest,
                // so the id lives on the button itself. Inactive tabs still
                // hide the visible title.
                .accessibilityElement(children: .combine)
                .accessibilityLabel(tab.label)
                .accessibilityIdentifier("tab-\(tab.rawValue)")
                .accessibilityAddTraits(.isButton)
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, placement == .top ? 5 : 6)
        // v1.6.1 — no more hardcoded 24pt bottom fake-inset; the caller pins
        // this via .safeAreaInset(edge: .bottom), which adds the real
        // home-indicator inset on every device.
        .padding(.bottom, placement == .top ? 5 : 6)
        .background(theme.nav)
        .background(.thinMaterial)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
            alignment: placement == .top ? .bottom : .top
        )
        .animation(.easeInOut(duration: 0.18), value: selection)
    }
}

#Preview {
    DSTabBar(selection: .constant(.chat)).theme(.jbeam)
}
