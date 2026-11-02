import SwiftUI

// Hard gate after 06:00 HKT. Six moods, labels from DailyMoodLock.
// Cheer is optional and does not change the stored mood.

struct DailyMoodGateView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var kk: KKAppModel

    @State private var showCheer = false
    @State private var cheerMood: DailyMood?

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 12)
            Text("(｡•̀ᴗ-)✧")
                .font(.system(size: 40, design: .monospaced))
                .foregroundStyle(theme.rose)
            Text("今日心情")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
            Text("香港時間 06:00 之後要揀一次。")
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.inkSoft)

            VStack(spacing: 8) {
                ForEach(DailyMood.allCases) { mood in
                    Button {
                        Task { await kk.dailyMood.set(mood) }
                    } label: {
                        HStack(spacing: 12) {
                            Text(mood.kao)
                                .font(.system(size: 16, design: .monospaced))
                                .frame(width: 92, alignment: .leading)
                            Text(mood.label)
                                .font(DSText.ui(theme, 16, weight: .medium))
                            Spacer()
                        }
                        .foregroundStyle(theme.ink)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
                        .background(theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(theme.line, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("kk-mood-\(mood.rawValue)")
                }
            }
            .padding(.horizontal, 20)

            Button {
                cheerMood = nil
                showCheer = true
            } label: {
                Text("打氣（可選，唔使而家）")
                    .font(DSText.mono(theme, 12))
                    .foregroundStyle(theme.inkMuted)
            }
            .buttonStyle(.plain)

            if let error = kk.dailyMood.lastError {
                Text(error)
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.rose)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.paper.ignoresSafeArea())
        .sheet(isPresented: $showCheer) {
            CheerSheet(mood: cheerMood, onClose: { showCheer = false })
                .theme(theme)
        }
    }
}

struct CheerSheet: View {
    @Environment(\.theme) private var theme
    let mood: DailyMood?
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text(mood?.kao ?? "(ﾉ◕ヮ◕)ﾉ*:･ﾟ✧")
                .font(.system(size: 48, design: .monospaced))
                .foregroundStyle(theme.rose)
                .padding(.top, 28)
            Text("打氣")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
            Text("可選。唔會改今日心情，亦唔會當 AI 次數。")
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button(action: onClose) {
                Text("完成")
                    .font(DSText.ui(theme, 16, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(theme.rose)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(theme.paper.ignoresSafeArea())
    }
}
