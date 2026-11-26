import SwiftUI

// Optional couple day. Replaces the anniversary list. The live pair RPC
// still cross-checks this date until couples.anniversary_iso is nullable.

struct CoupleDaySettingsView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var profileStore: UserProfileStore
    let onClose: () -> Void

    @State private var enabled: Bool = false
    @State private var date: Date = Date()

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("(♡˙︶˙♡)")
                    .font(.system(size: 32, design: .monospaced))
                    .foregroundStyle(theme.rose)
                Text("你哋嘅日子")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.ink)
                Text("可選。可以留空。唔再有紀念日列表。")
                    .font(DSText.ui(theme, 13))
                    .foregroundStyle(theme.inkSoft)
                Toggle("設定日期", isOn: $enabled)
                    .font(DSText.ui(theme, 15))
                    .tint(theme.rose)
                if enabled {
                    DatePicker("", selection: $date, in: ...Date(), displayedComponents: .date)
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                }
                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.paper.ignoresSafeArea())
            .navigationTitle("你哋嘅日子")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存", action: save)
                }
            }
        }
        .onAppear {
            if let iso = profileStore.profile?.anniversaryISO,
               !iso.isEmpty,
               let parsed = LocalDate.date(from: iso) {
                enabled = true
                date = parsed
            }
        }
    }

    private func save() {
        guard var profile = profileStore.profile else { onClose(); return }
        profile.anniversaryISO = enabled ? LocalDate.string(from: date) : ""
        profileStore.save(profile)
        onClose()
    }
}

struct KKInfoSheet: View {
    @Environment(\.theme) private var theme
    let title: String
    let bodyText: String
    let kao: String
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(kao)
                .font(.system(size: 36, design: .monospaced))
                .foregroundStyle(theme.rose)
            Text(title)
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
            Text(bodyText)
                .font(DSText.ui(theme, 15))
                .foregroundStyle(theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action: onClose) {
                Text("關閉")
                    .font(DSText.ui(theme, 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(theme.rose)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.paper.ignoresSafeArea())
    }
}
