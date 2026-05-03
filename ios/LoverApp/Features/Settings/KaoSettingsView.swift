import SwiftUI

// Kaomoji preference settings screen — translation of KaoSettings() in
// design-import/extra.jsx. Style picker (4 options) + smart-suggest toggle
// + live preview.

struct KaoSettingsView: View {
    @Environment(\.theme) private var theme
    let onClose: () -> Void

    @State private var selectedStyle: String = "jp"
    @State private var smartSuggest: Bool = true

    private struct Style: Identifiable {
        let id: String
        let label: String
        let sample: String
        let desc: String
    }

    private let styles: [Style] = [
        .init(id: "jp", label: "日系", sample: "(´｡• ω •｡`)", desc: "圓潤可愛，最常見"),
        .init(id: "classic", label: "經典", sample: "(◕‿◕)", desc: "簡潔易讀"),
        .init(id: "expressive", label: "誇張", sample: "＼(º □ º l|l)/", desc: "表情豐富"),
        .init(id: "mixed", label: "混合", sample: "ʕ•ᴥ•ʔ", desc: "咩都有"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navBar

                VStack(alignment: .leading, spacing: 24) {
                    stylesSection
                    optionsSection
                    previewBox
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .background(theme.paper)
    }

    private var navBar: some View {
        HStack(spacing: 8) {
            Button(action: onClose) {
                DSIcon(name: .back, size: 22, color: theme.rose, strokeWidth: 2.2).padding(6)
            }
            .buttonStyle(.plain)
            Text("顏文字偏好")
                .font(DSText.ui(theme, 17, weight: .semibold))
                .foregroundStyle(theme.ink)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .padding(.bottom, 12)
    }

    private var stylesSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("風格")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(theme.inkMuted)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                ForEach(styles.indices, id: \.self) { i in
                    let s = styles[i]
                    Button {
                        selectedStyle = s.id
                    } label: {
                        HStack(spacing: 14) {
                            Text(s.sample)
                                .font(DSText.mono(theme, 16))
                                .foregroundStyle(theme.ink)
                                .frame(minWidth: 80, alignment: .leading)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(s.label)
                                    .font(DSText.ui(theme, 14, weight: .medium))
                                    .foregroundStyle(theme.ink)
                                Text(s.desc)
                                    .font(DSText.mono(theme, 10))
                                    .foregroundStyle(theme.inkMuted)
                            }

                            Spacer()

                            if selectedStyle == s.id {
                                DSIcon(name: .check, size: 18, color: theme.rose, strokeWidth: 2.4)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .background(selectedStyle == s.id ? theme.roseSoft : .clear)
                        .overlay(
                            Rectangle().frame(height: i == 0 ? 0 : 0.5).foregroundStyle(theme.line),
                            alignment: .top
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("選項")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(theme.inkMuted)
                .textCase(.uppercase)

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("智能建議")
                        .font(DSText.ui(theme, 14))
                        .foregroundStyle(theme.ink)
                    Text("根據對話情緒推薦顏文字")
                        .font(DSText.mono(theme, 10))
                        .foregroundStyle(theme.inkMuted)
                }
                Spacer()
                Toggle("", isOn: $smartSuggest)
                    .labelsHidden()
                    .tint(theme.rose)
            }
            .padding(14)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var previewBox: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("預覽")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.rose)
            Text("早安 \(currentSample) 今日好天 ☀")
                .font(DSText.ui(theme, 14))
                .foregroundStyle(theme.ink)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.roseSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var currentSample: String {
        styles.first(where: { $0.id == selectedStyle })?.sample ?? "(´｡• ω •｡`)"
    }
}

#Preview {
    KaoSettingsView(onClose: {}).theme(.jbeam)
}
