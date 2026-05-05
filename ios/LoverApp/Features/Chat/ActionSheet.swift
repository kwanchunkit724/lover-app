import SwiftUI

// Bottom action sheet from `+` button — translation of ActionSheet in chat.jsx.
// Six tiles: 影相 / 相簿 / 位置 / 加入時間表 / 存到記憶 / 抽卡

struct ChatActionSheet: View {
    @Environment(\.theme) private var theme

    let onClose: () -> Void
    let onCamera: () -> Void
    let onAlbum: () -> Void

    private struct Item: Identifiable {
        let id: String
        let icon: DSIconName
        let label: String
        let action: () -> Void
    }

    var body: some View {
        let items: [Item] = [
            .init(id: "cam", icon: .cam, label: "影相", action: onCamera),
            .init(id: "img", icon: .image, label: "相簿", action: onAlbum),
            .init(id: "pin", icon: .pin2, label: "位置", action: onClose),
            .init(id: "cal", icon: .cal, label: "加入時間表", action: onClose),
            .init(id: "heart", icon: .heart, label: "存到記憶", action: onClose),
            .init(id: "spark", icon: .sparkle, label: "抽卡", action: onClose),
        ]

        return ZStack(alignment: .bottom) {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture(perform: onClose)

            VStack(spacing: 16) {
                Capsule()
                    .fill(theme.line)
                    .frame(width: 36, height: 4)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12),
                                    GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    ForEach(items) { item in
                        Button(action: item.action) {
                            VStack(spacing: 6) {
                                DSIcon(name: item.icon, size: 22, color: theme.rose)
                                Text(item.label)
                                    .font(DSText.ui(theme, 12))
                                    .foregroundStyle(theme.inkSoft)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 8)
                            .background(theme.paperAlt)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
            .padding(.top, 20)
            .padding(.bottom, 32)
            .background(theme.surface)
            .clipShape(UnevenRoundedRectangle(
                cornerRadii: .init(topLeading: 20, topTrailing: 20),
                style: .continuous
            ))
            .overlay(
                Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
                alignment: .top
            )
        }
    }
}
