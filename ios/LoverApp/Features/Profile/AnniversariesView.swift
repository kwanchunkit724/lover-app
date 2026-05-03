import SwiftUI

// Anniversaries detail screen — translation of Anniversaries() in
// design-import/extra.jsx. Hero card for the soonest, then full list
// with each item's recurrence badge + countdown.

struct AnniversariesView: View {
    @Environment(\.theme) private var theme
    let onClose: () -> Void

    private var items: [(anniversary: Anniversary, days: Int, ordinal: Int?, isoDate: String)] {
        let today = TimeFormatting.parseDate(MockData.todayISO) ?? Date()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = TimeZone(identifier: "Asia/Hong_Kong")
        return MockData.anniversaries
            .map { a in
                let occ = a.nextOccurrence(today: today)
                return (anniversary: a, days: occ.daysAway, ordinal: occ.ordinal, isoDate: f.string(from: occ.date))
            }
            .sorted { $0.days < $1.days }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navBar

                if let hero = items.first {
                    heroCard(hero)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }

                Text("所有 · \(items.count) 個")
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(theme.inkMuted)
                    .textCase(.uppercase)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                ForEach(items.dropFirst(), id: \.anniversary.id) { item in
                    AnniversaryRow(item: item)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                }

                Button {} label: {
                    Text("＋ 加新紀念日")
                        .font(DSText.ui(theme, 13))
                        .foregroundStyle(theme.inkMuted)
                        .frame(maxWidth: .infinity)
                        .padding(14)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(theme.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                        )
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 30)
            }
        }
        .background(theme.paper)
    }

    private var navBar: some View {
        HStack {
            Button(action: onClose) {
                DSIcon(name: .back, size: 22, color: theme.rose, strokeWidth: 2.2).padding(6)
            }
            .buttonStyle(.plain)
            Text("紀念日")
                .font(DSText.ui(theme, 17, weight: .semibold))
                .foregroundStyle(theme.ink)
            Spacer()
            Button {} label: {
                Text("＋")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(theme.rose)
                    .padding(6)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
    }

    private func heroCard(_ item: (anniversary: Anniversary, days: Int, ordinal: Int?, isoDate: String)) -> some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("下一個 · 倒數中")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(.white.opacity(0.8))

                Text(item.anniversary.title)
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .padding(.top, 4)

                Text("\(item.isoDate) · 星期\(TimeFormatting.weekday(item.isoDate))" +
                     ((item.ordinal ?? 0) > 0 ? " · 第 \(item.ordinal!) 年" : ""))
                    .font(DSText.mono(theme, 12))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 4)

                HStack(alignment: .lastTextBaseline, spacing: 8) {
                    Text("\(item.days)")
                        .font(.system(size: 56, weight: .bold, design: .serif))
                        .foregroundStyle(.white)
                    Text("日後 ♡")
                        .font(DSText.mono(theme, 14))
                        .foregroundStyle(.white.opacity(0.9))
                }
                .padding(.top, 18)
            }
            .padding(20)

            Text(item.anniversary.emoji ?? "♡")
                .font(.system(size: 120))
                .foregroundStyle(.white.opacity(0.12))
                .offset(x: 20, y: 30)
                .clipped()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.rose)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct AnniversaryRow: View {
    @Environment(\.theme) private var theme
    let item: (anniversary: Anniversary, days: Int, ordinal: Int?, isoDate: String)

    private var daysSinceBase: Int {
        TimeFormatting.daysBetween(item.anniversary.baseDate, MockData.todayISO)
    }

    var body: some View {
        HStack(spacing: 14) {
            Text(item.anniversary.emoji ?? "♡")
                .font(.system(size: 22))
                .frame(width: 48, height: 48)
                .background(theme.roseSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(item.anniversary.title)
                        .font(DSText.ui(theme, 14, weight: .semibold))
                        .foregroundStyle(theme.ink)
                    Text(item.anniversary.recur == .yearly ? "每年" : "每月")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(item.anniversary.recur == .yearly ? theme.sage : theme.amber)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.anniversary.recur == .yearly ? theme.sageSoft : theme.amberSoft)
                        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                }
                Text("從 \(item.anniversary.baseDate) · 一齊 \(daysSinceBase) 日")
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.inkMuted)
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.days)")
                    .font(.system(size: 20, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.rose)
                Text("日後")
                    .font(DSText.mono(theme, 9))
                    .foregroundStyle(theme.inkMuted)
            }
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

#Preview {
    AnniversariesView(onClose: {}).theme(.jbeam)
}
