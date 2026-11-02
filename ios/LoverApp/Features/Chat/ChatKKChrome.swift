import SwiftUI

struct ChatPolicyBanner: View {
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("傾計訊息 48 小時後自動刪除")
                .font(DSText.ui(theme, 12, weight: .semibold))
                .foregroundStyle(theme.ink)
            Text("傾計端對端加密，伺服器讀唔到；記憶空間儲存在伺服器以便雙方共享同提醒；AI 只處理你提交嘅內容。")
                .font(DSText.ui(theme, 11))
                .foregroundStyle(theme.inkSoft)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.paperAlt)
    }
}

struct ChatQuickKaomojiBar: View {
    @Environment(\.theme) private var theme
    let items: [String]
    let onPick: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(items, id: \.self) { kao in
                    Button { onPick(kao) } label: {
                        Text(kao)
                            .font(DSText.mono(theme, 13))
                            .foregroundStyle(theme.ink)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 6)
                            .background(theme.paperAlt)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}

struct ChatMultiSelectBar: View {
    @Environment(\.theme) private var theme
    let count: Int
    let onMemory: () -> Void
    let onAI: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            Text("已揀 \(count)")
                .font(DSText.mono(theme, 11))
                .foregroundStyle(theme.inkMuted)
            HStack(spacing: 8) {
                barButton("加入記憶空間", action: onMemory)
                barButton("AI 展開", action: onAI)
                Button("取消", action: onCancel)
                    .font(DSText.ui(theme, 13))
                    .foregroundStyle(theme.inkSoft)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(theme.surface)
    }

    private func barButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(DSText.ui(theme, 13, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(theme.rose)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(count == 0)
        .opacity(count == 0 ? 0.45 : 1)
    }
}
