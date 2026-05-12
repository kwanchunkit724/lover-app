import SwiftUI

// v1.4.5 — Apple App Review 5.1.1(v) requires in-app account deletion for
// any app that supports account creation. The Profile → 帳戶 → 永久刪除帳戶
// row opens this sheet. Two-step confirm so users can't tap-through by
// accident; final tap calls AuthService.deleteAccount() which calls the
// Postgres RPC delete_my_account().

struct DeleteAccountSheet: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var auth: AuthService
    let onClose: () -> Void

    @State private var typedConfirm: String = ""
    @State private var isSubmitting: Bool = false
    @State private var errorMessage: String? = nil

    private let requiredConfirm = "刪除我嘅帳戶"

    private var canDelete: Bool {
        typedConfirm.trimmingCharacters(in: .whitespaces) == requiredConfirm && !isSubmitting
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navBar

                VStack(alignment: .leading, spacing: 22) {
                    Text("(´｡• ω •｡`)")
                        .font(DSText.mono(theme, 36))
                        .foregroundStyle(theme.rose)

                    Text("永久刪除你嘅帳戶？")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                        .foregroundStyle(theme.ink)

                    section(title: "呢個動作會") {
                        VStack(alignment: .leading, spacing: 8) {
                            bullet("刪除你嘅 profile（名、email、公鑰）")
                            bullet("刪除你嘅 Apple ID / Email 登入紀錄")
                            bullet("解除配對 — 對方會回到「未配對」狀態")
                            bullet("刪除你 send 過嘅所有訊息、相片、語音")
                            bullet("刪除你加過嘅紀念日、時間表 entry")
                            bullet("刪除你寫過嘅 18 區 / MTR / 玩樂卡記錄")
                        }
                        .padding(14)
                    }

                    section(title: "唔可以 undo") {
                        Text("呢個動作即時生效，冇辦法復原。對方部 phone 已 send 過嘅舊嘢仍會留低做 ciphertext，但因為 decryption key 同你嘅 keypair 一齊消失，所有人（包括你同對方）以後都讀唔到。")
                            .font(DSText.ui(theme, 13))
                            .foregroundStyle(theme.inkSoft)
                            .padding(14)
                    }

                    section(title: "確認") {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("輸入「\(requiredConfirm)」確認：")
                                .font(DSText.ui(theme, 12))
                                .foregroundStyle(theme.inkMuted)
                            TextField("", text: $typedConfirm)
                                .font(DSText.ui(theme, 15))
                                .foregroundStyle(theme.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(theme.paper)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .stroke(theme.line, lineWidth: 0.5)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                .autocorrectionDisabled(true)
                        }
                        .padding(14)
                    }

                    if let err = errorMessage {
                        Text(err)
                            .font(DSText.mono(theme, 11))
                            .foregroundStyle(theme.rose)
                            .padding(.horizontal, 4)
                    }

                    Button(action: submit) {
                        HStack {
                            if isSubmitting {
                                ProgressView().tint(.white)
                            } else {
                                Text("永久刪除帳戶")
                                    .font(DSText.ui(theme, 15, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(canDelete ? theme.rose : theme.inkMuted)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDelete)

                    Button(action: onClose) {
                        Text("取消")
                            .font(DSText.ui(theme, 14))
                            .foregroundStyle(theme.inkSoft)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 30)
            }
        }
        .background(theme.paper)
        .scrollDismissesKeyboard(.interactively)
    }

    private var navBar: some View {
        HStack {
            Button { onClose() } label: {
                DSIcon(name: .close, size: 22, color: theme.rose, strokeWidth: 2.2)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("刪除帳戶")
                .font(DSText.ui(theme, 16, weight: .semibold))
                .foregroundStyle(theme.ink)
            Spacer()
            Color.clear.frame(width: 30, height: 30)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func bullet(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.rose)
            Text(text)
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.ink)
        }
    }

    private func section<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(theme.inkMuted)
                .textCase(.uppercase)
                .padding(.leading, 4)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.line, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func submit() {
        guard canDelete else { return }
        isSubmitting = true
        errorMessage = nil
        Task {
            let ok = await auth.deleteAccount()
            await MainActor.run {
                isSubmitting = false
                if ok {
                    onClose()
                } else {
                    if case .error(let msg) = auth.state {
                        errorMessage = msg
                    } else {
                        errorMessage = "刪除帳戶失敗，請再試一次"
                    }
                }
            }
        }
    }
}
