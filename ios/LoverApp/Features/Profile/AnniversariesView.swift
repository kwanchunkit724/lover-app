import SwiftUI

// Anniversaries detail screen — translation of Anniversaries() in
// design-import/extra.jsx. Hero card for the soonest, then full list
// with each item's recurrence badge + countdown.
//
// v0.5.0: real E2EE data via AnniversaryService instead of MockData.
// Add via AddAnniversaryView sheet. Long-press / swipe to delete.

struct AnniversariesView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var anniversaryService: AnniversaryService

    let onClose: () -> Void

    @State private var showAdd = false

    /// Maps DecryptedAnniversary -> the legacy Anniversary view-model the
    /// row UI code expects, plus its computed countdown.
    private var items: [(anniversary: Anniversary, days: Int, ordinal: Int?, isoDate: String, sourceId: UUID)] {
        let today = Date()
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return anniversaryService.items
            .map { d in
                let a = Anniversary(
                    id: d.id.uuidString,
                    title: d.payload.title,
                    baseDate: d.payload.baseDateISO,
                    recur: d.payload.recur == .yearly ? .yearly : .monthly,
                    kaomoji: d.payload.kaomoji,
                    emoji: d.payload.emoji,
                    subtitle: d.payload.subtitle
                )
                let occ = a.nextOccurrence(today: today)
                return (anniversary: a,
                        days: occ.daysAway,
                        ordinal: occ.ordinal,
                        isoDate: f.string(from: occ.date),
                        sourceId: d.id)
            }
            .sorted { $0.days < $1.days }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navBar

                if items.isEmpty {
                    emptyState
                        .padding(.top, 60)
                } else {
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
                        AnniversaryRow(item: item) {
                            Task { await delete(sourceId: item.sourceId) }
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)
                    }

                    addButton
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 30)
                }
            }
        }
        .background(theme.paper)
        .sheet(isPresented: $showAdd) {
            AddAnniversaryView(onClose: { showAdd = false })
                .theme(theme)
                .environmentObject(anniversaryService)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("(´｡• ω •｡`)")
                .font(.system(size: 40, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.rose)
            Text("仲未有紀念日")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
            Text("加返你哋一齊嘅日子、生日、月誌\n兩個人都會見到")
                .font(DSText.ui(theme, 12))
                .foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)
            addButton
                .padding(.horizontal, 32)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
    }

    private var addButton: some View {
        Button { showAdd = true } label: {
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
    }

    // MARK: - Nav

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
            Button { showAdd = true } label: {
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

    // MARK: - Hero card

    private func heroCard(_ item: (anniversary: Anniversary, days: Int, ordinal: Int?, isoDate: String, sourceId: UUID)) -> some View {
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

    // MARK: - Delete

    private func delete(sourceId: UUID) async {
        guard let item = anniversaryService.items.first(where: { $0.id == sourceId }) else { return }
        await anniversaryService.delete(item)
    }
}

private struct AnniversaryRow: View {
    @Environment(\.theme) private var theme
    let item: (anniversary: Anniversary, days: Int, ordinal: Int?, isoDate: String, sourceId: UUID)
    let onDelete: () -> Void

    private var daysSinceBase: Int {
        let today = LocalDate.string(from: Date())
        return TimeFormatting.daysBetween(item.anniversary.baseDate, today)
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle().fill(theme.roseSoft)
                Text(item.anniversary.emoji ?? "♡")
                    .font(.system(size: 22))
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.anniversary.title)
                    .font(DSText.ui(theme, 14, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("\(item.isoDate) · \(item.anniversary.recur == .yearly ? "年" : "月") · \(daysSinceBase) 日前開始")
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.inkMuted)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.days)")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.rose)
                Text("日後")
                    .font(DSText.mono(theme, 10))
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
        .contextMenu {
            Button(role: .destructive, action: onDelete) {
                Label("刪除", systemImage: "trash")
            }
        }
    }
}
