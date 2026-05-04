import SwiftUI

// 我哋 tab top-level — translation of Profile() in design-import/screens.jsx.
// Sections from top: couple identity card, anniversaries, settings, account.

struct ProfileView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var pairing: PairingService

    @State private var presented: SettingsRoute? = nil
    @State private var confirmReset = false
    @State private var confirmUnpair = false
    @State private var confirmSignOut = false
    @State private var showPairing = false
    @EnvironmentObject private var anniversaryService: AnniversaryService

    /// Build version pulled from the bundle so the "關於" row isn't a stale
    /// hardcoded string. Phase 9: was hardcoded to "v0.3" — masked the fact
    /// that the user was running outdated builds during testing.
    private var bundleVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        return "v\(v)"
    }

    /// v0.5.0: real anniversaries from backend (E2EE). When unsigned-in or
    /// before the service has fetched, fall back to MockData so the
    /// anniversaries section isn't empty in previews.
    private var anniversaries: [Anniversary] {
        let real = anniversaryService.items.map { d in
            Anniversary(
                id: d.id.uuidString,
                title: d.payload.title,
                baseDate: d.payload.baseDateISO,
                recur: d.payload.recur == .yearly ? .yearly : .monthly,
                kaomoji: d.payload.kaomoji,
                emoji: d.payload.emoji,
                subtitle: d.payload.subtitle
            )
        }
        return real.isEmpty ? MockData.anniversaries : real
    }

    // Avatar tints stay from MockData (same kawaii palette); name/initial
    // resolve from the freshest source: real partner row (Phase 3c) → local
    // onboarding profile (Phase 2) → mock data (no auth, no profile).
    private var me: Person {
        let name = profileStore.profile?.myName ?? MockData.me.name
        return Person(id: "me", name: name, initial: String(name.prefix(1)), tint: .rose)
    }
    private var partner: Person {
        // pairing.partner.myName is what the partner typed for THEMSELVES on
        // their device — preferred over our local "what I think they're called".
        let name = pairing.partner?.myName
                ?? profileStore.profile?.partnerName
                ?? MockData.partner.name
        return Person(id: "partner", name: name, initial: String(name.prefix(1)), tint: .sage)
    }

    private var anniversaryISO: String {
        // Both sides cross-checked the same anniversary at pairing time, so
        // the partner row's value is canonical when paired.
        pairing.partner?.anniversaryISO
            ?? profileStore.profile?.anniversaryISO
            ?? MockData.togetherSinceISO
    }

    private var daysTogether: Int {
        let todayISO = LocalDate.string(from: Date())
        return TimeFormatting.daysBetween(anniversaryISO, todayISO)
    }

    private var nextAnniv: (anniversary: Anniversary, days: Int, ordinal: Int?)? {
        let today = Date()
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

                if pairing.isPaired {
                    identityCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                } else {
                    soloPairCard
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                VStack(alignment: .leading, spacing: 22) {
                    if pairing.isPaired {
                        anniversariesSection
                    }
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
        .sheet(isPresented: $showPairing) {
            PairingView()
                .theme(theme)
        }
        .alert("重設個人資料？", isPresented: $confirmReset) {
            Button("取消", role: .cancel) {}
            Button("重設", role: .destructive) {
                profileStore.reset()
                Task { await auth.signOut() }
            }
        } message: {
            Text("會清除你輸入嘅名同紀念日，登出 App，回到歡迎畫面。")
        }
        .alert("解除配對？", isPresented: $confirmUnpair) {
            Button("取消", role: .cancel) {}
            Button("解除", role: .destructive) {
                Task { await pairing.unpair() }
            }
        } message: {
            Text("會刪除你哋嘅配對。對方下次開 App 會見到要重新配對。")
        }
        .alert("登出？", isPresented: $confirmSignOut) {
            Button("取消", role: .cancel) {}
            Button("登出", role: .destructive) {
                Task { await auth.signOut() }
            }
        } message: {
            Text("配對唔會解除，下次用同一個 Apple ID 登入返就見返一切。")
        }
        .task {
            // Refresh partner data when this tab opens — picks up theme /
            // name changes the partner made on their device.
            if case .signedIn(let id) = auth.state {
                await pairing.refresh(meId: id)
            }
        }
    }

    // MARK: - Solo (unpaired) pair card

    private var soloPairCard: some View {
        VStack(spacing: 12) {
            Text("(´｡• ω •｡`)")
                .font(.system(size: 36, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.rose)

            Text(me.name)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)

            Text("仲未配對 — Profile / 設定 / 主題照用，配對之後就解鎖對話、紀念日、玩樂。")
                .font(DSText.ui(theme, 12))
                .foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)

            Button { showPairing = true } label: {
                Text("去配對 →")
                    .font(DSText.ui(theme, 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: 200)
                    .frame(height: 42)
                    .background(theme.rose)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 4)
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

            Text("一齊 \(daysTogether) 日 · 自 \(DisplayDate.from(iso: anniversaryISO))")
                .font(DSText.mono(theme, 11))
                .foregroundStyle(theme.inkMuted)
                .padding(.top, 4)

            // Phase 3c — show pairing status. When paired, sage-tinted "已配對 ♡"
            // badge confirms backend round-trip; when unpaired, amber warning
            // hints that real chat won't work until pairing.
            if pairing.isPaired {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text("已配對 ♡")
                        .font(DSText.mono(theme, 11))
                }
                .foregroundStyle(theme.sage)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(theme.sageSoft)
                .clipShape(Capsule())
                .padding(.top, 10)
            } else {
                Text("(♡˙︶˙♡)")
                    .font(DSText.mono(theme, 14))
                    .foregroundStyle(theme.rose)
                    .padding(.top, 10)
            }
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
            ProfileRow(icon: .us, label: "主題", value: "\(theme.name) →",
                       onTap: { presented = .theme }, isLast: true)
        }
    }

    private var accountSection: some View {
        ProfileSection(title: "帳戶") {
            if pairing.isPaired {
                ProfileRow(icon: .more, label: "解除配對", value: "→", subtle: true,
                           onTap: { confirmUnpair = true })
            }
            ProfileRow(icon: .more, label: "登出", value: "→", subtle: true,
                       onTap: { confirmSignOut = true })
            ProfileRow(icon: .more, label: "重設個人資料", value: "→", subtle: true,
                       onTap: { confirmReset = true })
            ProfileRow(icon: .more, label: "關於", value: bundleVersion, onTap: nil, isLast: true)
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
    let crypto = CryptoService()
    return ProfileView()
        .environmentObject(UserProfileStore())
        .environmentObject(AuthService())
        .environmentObject(PairingService())
        .environmentObject(AnniversaryService(crypto: crypto))
        .theme(.jbeam)
}
