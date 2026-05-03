import SwiftUI

// 我哋 tab top-level — translation of Profile() in design-import/screens.jsx.
// Sections from top: couple identity card, anniversaries, settings, account.

struct ProfileView: View {
    @Environment(\.theme) private var theme

    @State private var presented: SettingsRoute? = nil

    private let me = MockData.me
    private let partner = MockData.partner
    private let anniversaries = MockData.anniversaries

    private var daysTogether: Int {
        TimeFormatting.daysBetween(MockData.togetherSinceISO, MockData.todayISO)
    }

    private var nextAnniv: (anniversary: Anniversary, days: Int, ordinal: Int?)? {
        guard let today = TimeFormatting.parseDate(MockData.todayISO) else { return nil }
        return anniversaries
            .map { a in
                let occ = a.nextOccurrence(today: today)
                return (anniversary: a, days: occ.daysAway, ordinal: occ.ordinal)
            }
            .min(by: { $0.days < $1.days })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("我哋")
                    .font(.system(size: 32, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                identityCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)

                VStack(alignment: .leading, spacing: 22) {
                    anniversariesSection
                    settingsSection
                    accountSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
            }
        }
        .background(theme.paper)
        .sheet(item: $presented) { route in
            sheetContent(for: route)
                .theme(theme)
        }
    }

    // MARK: - Identity card

    private var identityCard: some View {
        VStack(spacing: 0) {
            HStack(spacing: -10) {
                DSAvatar(person: partner, size: 56)
                Text("♡")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.rose)
                    .offset(y: 2)
                    .zIndex(1)
                    .padding(.horizontal, 4)
                DSAvatar(person: me, size: 56)
            }
            .padding(.bottom, 14)

            Text("\(me.name) & \(partner.name)")
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)

            Text("一齊 \(daysTogether) 日 · 自 \(MockData.togetherSinceISO.replacingOccurrences(of: "-", with: "."))")
                .font(DSText.mono(theme, 11))
                .foregroundStyle(theme.inkMuted)
                .padding(.top, 4)

            Text("(♡˙︶˙♡)")
                .font(DSText.mono(theme, 14))
                .foregroundStyle(theme.rose)
                .padding(.top, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(theme.line, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Sections

    private var anniversariesSection: some View {
        ProfileSection(title: "紀念日") {
            if let next = nextAnniv {
                ProfileRow(
                    icon: .heart,
                    label: "下一個：\(next.anniversary.title)",
                    value: "\(next.days) 日後 →",
                    onTap: { presented = .anniversaries }
                )
            }
            ProfileRow(
                icon: .cal,
                label: "所有紀念日 (\(anniversaries.count))",
                value: "→",
                onTap: { presented = .anniversaries },
                isLast: true
            )
        }
    }

    private var settingsSection: some View {
        ProfileSection(title: "設定") {
            ProfileRow(icon: .kao, label: "顏文字偏好", value: "日系 →",
                       onTap: { presented = .kao })
            ProfileRow(icon: .image, label: "共用相簿", value: "247", onTap: nil)
            ProfileRow(icon: .clock, label: "提醒時間", value: "08:00", onTap: nil)
            ProfileRow(icon: .us, label: "主題", value: "日系奶油 →",
                       onTap: { presented = .theme }, isLast: true)
        }
    }

    private var accountSection: some View {
        ProfileSection(title: "帳戶") {
            ProfileRow(icon: .more, label: "解除配對", value: "", subtle: true, onTap: nil)
            ProfileRow(icon: .more, label: "關於", value: "v0.1", onTap: nil, isLast: true)
        }
    }

    // MARK: - Sheet routing

    @ViewBuilder
    private func sheetContent(for route: SettingsRoute) -> some View {
        switch route {
        case .anniversaries:
            AnniversariesView(onClose: { presented = nil })
        case .kao:
            KaoSettingsView(onClose: { presented = nil })
        case .theme:
            ThemeSettingsView(onClose: { presented = nil })
        }
    }
}

enum SettingsRoute: String, Identifiable {
    case anniversaries, kao, theme
    var id: String { rawValue }
}

// MARK: - Section + Row primitives

private struct ProfileSection<Content: View>: View {
    @Environment(\.theme) private var theme
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(theme.inkMuted)
                .textCase(.uppercase)
                .padding(.leading, 4)
            VStack(spacing: 0) { content() }
                .background(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.line, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }
}

private struct ProfileRow: View {
    @Environment(\.theme) private var theme
    let icon: DSIconName
    let label: String
    let value: String
    var subtle: Bool = false
    var onTap: (() -> Void)? = nil
    var isLast: Bool = false

    var body: some View {
        let body = HStack(spacing: 12) {
            DSIcon(name: icon, size: 16, color: theme.inkMuted)
            Text(label)
                .font(DSText.ui(theme, 14))
                .foregroundStyle(theme.ink)
            Spacer()
            Text(value)
                .font(DSText.mono(theme, 13))
                .foregroundStyle(subtle ? theme.inkMuted : theme.inkSoft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(
            Rectangle().frame(height: isLast ? 0 : 0.5).foregroundStyle(theme.line),
            alignment: .bottom
        )

        if let onTap {
            Button(action: onTap) { body }
                .buttonStyle(.plain)
        } else {
            body
        }
    }
}

#Preview {
    ProfileView().theme(.jbeam)
}
