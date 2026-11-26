import SwiftUI

// Each person writes the name their partner should see. The value is stored
// on this phone and UPDATE'd onto users.my_name (the row owner). The other
// phone picks it up from pairing.partner.myName on refresh.

struct MyNameSettingsView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var auth: AuthService
    let onClose: () -> Void

    @State private var name: String = ""
    @State private var error: String?
    @State private var saving = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text("(◕‿◕)")
                    .font(.system(size: 32, design: .monospaced))
                    .foregroundStyle(theme.rose)
                Text("我嘅名")
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.ink)
                Text("對方會見到呢個名。唔好用「我」或者「對方」。")
                    .font(DSText.ui(theme, 13))
                    .foregroundStyle(theme.inkSoft)

                TextField("你嘅名", text: $name)
                    .font(DSText.ui(theme, 18))
                    .foregroundStyle(theme.ink)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(theme.line, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onChange(of: name) { _, _ in error = nil }

                if let message = liveMessage {
                    Text(message)
                        .font(DSText.ui(theme, 13))
                        .foregroundStyle(theme.rose)
                }

                Spacer()
            }
            .padding(20)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(theme.paper.ignoresSafeArea())
            .navigationTitle("我嘅名")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存", action: save)
                        .disabled(!canSave)
                }
            }
        }
        .onAppear {
            if let existing = CoupleNames.persistable(profileStore.profile?.myName) {
                name = existing
            }
        }
    }

    private var canSave: Bool {
        CoupleNames.persistable(name) != nil && !saving
    }

    private var liveMessage: String? {
        if let error { return error }
        if let rejection = CoupleNames.rejection(of: name), rejection != .empty {
            return CoupleNames.message(for: rejection)
        }
        return nil
    }

    private func save() {
        guard let persist = CoupleNames.persistable(name) else {
            if let rejection = CoupleNames.rejection(of: name) {
                error = CoupleNames.message(for: rejection)
            }
            return
        }
        guard var profile = profileStore.profile else {
            error = "未有個人資料。先完成註冊再試。"
            return
        }
        profile.myName = persist
        profileStore.save(profile)
        saving = true
        Task {
            let wrote = await auth.publishMyName(persist)
            saving = false
            if wrote {
                onClose()
            } else {
                error = "名已存在呢部手機，但寫唔上伺服器。再開 App 會再試。"
            }
        }
    }
}
