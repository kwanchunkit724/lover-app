import SwiftUI

// Theme picker screen — translation of ThemeSettings() in
// design-import/extra.jsx. Lists 3 themes with swatch + radio selection.
// At launch only jbeam is enabled; the other two are post-v1.0.

struct ThemeSettingsView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var profileStore: UserProfileStore
    let onClose: () -> Void

    @State private var selectedID: String = Theme.jbeam.id

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navBar

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Theme.allThemes, id: \.id) { t in
                        themeRow(t)
                    }

                    syncWarning
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .background(theme.paper)
        .onAppear {
            if let saved = profileStore.profile?.themeId { selectedID = saved }
        }
        .onChange(of: selectedID) { _, newID in
            guard var p = profileStore.profile, p.themeId != newID else { return }
            p.themeId = newID
            profileStore.save(p)
        }
    }

    private var navBar: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                DSIcon(name: .back, size: 22, color: theme.rose, strokeWidth: 2.2).padding(6)
            }
            .buttonStyle(.plain)
            Text("主題")
                .font(DSText.ui(theme, 17, weight: .semibold))
                .foregroundStyle(theme.ink)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .padding(.bottom, 12)
    }

    private func themeRow(_ t: Theme) -> some View {
        let active = t.id == selectedID
        return Button {
            selectedID = t.id
        } label: {
            HStack(spacing: 14) {
                swatch(for: t)
                VStack(alignment: .leading, spacing: 3) {
                    Text(t.name)
                        .font(DSText.ui(theme, 15, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text(themeDesc(t))
                        .font(DSText.ui(theme, 12))
                        .foregroundStyle(theme.inkSoft)
                }
                Spacer()
                if active {
                    DSIcon(name: .check, size: 14, color: .white, strokeWidth: 3)
                        .frame(width: 24, height: 24)
                        .background(theme.rose)
                        .clipShape(Circle())
                }
            }
            .padding(16)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(active ? theme.rose : theme.line, lineWidth: active ? 1.5 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func swatch(for t: Theme) -> some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(t.paper)
                .frame(width: 36, height: 26)
                .overlay(
                    Rectangle()
                        .stroke(t.paper == .white ? theme.line : .clear, lineWidth: 0.5)
                )
                .clipShape(UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 8, bottomLeading: 0, bottomTrailing: 0, topTrailing: 8),
                    style: .continuous
                ))
            Rectangle()
                .fill(t.rose)
                .frame(width: 36, height: 13)
            Rectangle()
                .fill(t.sage)
                .frame(width: 36, height: 13)
                .clipShape(UnevenRoundedRectangle(
                    cornerRadii: .init(topLeading: 0, bottomLeading: 8, bottomTrailing: 8, topTrailing: 0),
                    style: .continuous
                ))
        }
    }

    private func themeDesc(_ t: Theme) -> String {
        switch t.id {
        case "jbeam":  return "柔和玫瑰、圓潤字體"
        case "notion": return "暖白底配黑墨字"
        case "cozy":   return "深色模式，陶土橙"
        default:       return ""
        }
    }

    private var syncWarning: some View {
        // Phase 2: theme is local-only. Phase 3 will sync the chosen theme so
        // both phones in the couple display the same surface.
        let partnerName = profileStore.profile?.partnerName ?? "對方"
        return Text("⚠ Phase 3 之後主題會同步到 \(partnerName) 嘅手機")
            .font(.system(size: 11, weight: .regular, design: .monospaced))
            .foregroundStyle(theme.amber)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.amberSoft)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .padding(.top, 14)
    }
}

#Preview {
    ThemeSettingsView(onClose: {})
        .environmentObject(UserProfileStore())
        .theme(.jbeam)
}
