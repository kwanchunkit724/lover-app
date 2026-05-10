import SwiftUI

// 時間 tab top-level — translation of the Timetable function in
// design-import/screens.jsx. Sections from top to bottom:
//   1. Anniversary ribbon (only on current month)
//   2. Month switcher + counts
//   3. 7-column MonthGrid
//   4. Selected-day detail (today / upcoming / past row variants)
//   5. 一年前嘅今日 panel (only when today is selected)

struct TimeView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var entryService: EntryService
    @EnvironmentObject private var anniversaryService: AnniversaryService

    // Default the calendar header to the current month so freshly-paired
    // couples see "today" highlighted on first launch.
    @State private var viewYear: Int = Calendar.current.component(.year, from: Date())
    @State private var viewMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedISO: String = LocalDate.string(from: Date())
    @State private var presentedEntryID: String? = nil
    @State private var addingEntry = false

    private var todayISO: String { LocalDate.string(from: Date()) }

    /// v0.5.1: real entries from EntryService when paired (E2EE). Fall back
    /// to MockData when service is empty so previews still render.
    private var entries: [Entry] {
        let real = entryService.asEntries
        return real.isEmpty ? MockData.entries : real
    }

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

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                if isCurrentMonth, let next = nextAnniversary {
                    anniversaryRibbon(next)
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                }

                monthHeader
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                MonthGrid(
                    year: viewYear,
                    month: viewMonth,
                    todayISO: todayISO,
                    entries: entries,
                    selectedISO: $selectedISO
                )

                selectedDaySection
                    .padding(.horizontal, 16)
                    .padding(.top, 20)

                if selectedISO == todayISO {
                    lookbackSection
                        .padding(.horizontal, 16)
                        .padding(.top, 24)
                }

                Color.clear.frame(height: 28)
            }
        }
        .background(theme.paper)
        // v1.4.1 — surface entries / play-history backend errors so user
        // can screenshot when something fails silently.
        .errorToast(Binding(
            get: { entryService.lastError },
            set: { entryService.lastError = $0 }
        ))
        .sheet(isPresented: $addingEntry) {
            AddEntryView(onClose: { addingEntry = false })
                .theme(theme)
        }
        .sheet(item: Binding(
            get: { presentedEntryID.flatMap { id in entries.first(where: { $0.id == id }) } },
            set: { presentedEntryID = $0?.id }
        )) { entry in
            EntryDetailView(
                entry: entry,
                onClose: { presentedEntryID = nil }
            )
            .theme(theme)
        }
    }

    // MARK: - Anniversary ribbon

    private func anniversaryRibbon(_ pair: (anniversary: Anniversary, days: Int, ordinal: Int?)) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("下一個紀念日")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(.white.opacity(0.85))
                HStack(spacing: 4) {
                    Text(pair.anniversary.title)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                    if let ord = pair.ordinal, ord > 0 {
                        Text("· 第 \(ord) 年")
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(pair.days)")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("日後")
                    .font(DSText.mono(theme, 9))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(theme.rose)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Month header

    private var monthHeader: some View {
        HStack(alignment: .firstTextBaseline) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Button(action: prevMonth) {
                    Text("‹")
                        .font(DSText.mono(theme, 16))
                        .foregroundStyle(theme.inkSoft)
                        .padding(4)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 3) {
                    Text(verbatim: "\(viewYear) \(TimeFormatting.monthsTC[viewMonth - 1])")
                        .font(.system(size: 24, weight: .semibold, design: .serif))
                        .foregroundStyle(theme.ink)
                    Text(monthCountsLabel)
                        .font(DSText.mono(theme, 10))
                        .foregroundStyle(theme.inkMuted)
                }

                Button(action: nextMonth) {
                    Text("›")
                        .font(DSText.mono(theme, 16))
                        .foregroundStyle(theme.inkSoft)
                        .padding(4)
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button { addingEntry = true } label: {
                DSIcon(name: .plus, size: 18, color: .white, strokeWidth: 2.4)
                    .frame(width: 34, height: 34)
                    .background(theme.rose)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Selected day section

    private var selectedDaySection: some View {
        let dayEntries = entries.filter { $0.date == selectedISO }
        let isPast = selectedISO < todayISO
        let isToday = selectedISO == todayISO

        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(isToday ? "今日" : (isPast ? "回望" : "將至"))
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.ink)
                Text("\(TimeFormatting.mdString(selectedISO)) · 星期\(TimeFormatting.weekday(selectedISO))" +
                     (dayEntries.isEmpty ? "" : " · \(dayEntries.count) 件事"))
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(.leading, 4)

            if dayEntries.isEmpty {
                emptyDayBox(isPast: isPast, isToday: isToday)
            } else {
                ForEach(dayEntries) { entry in
                    if entry.isPast(today: todayISO) {
                        PastEntryRow(entry: entry) { presentedEntryID = entry.id }
                    } else {
                        UpcomingCardRow(entry: entry, hero: isToday) { presentedEntryID = entry.id }
                    }
                }
            }
        }
    }

    private func emptyDayBox(isPast: Bool, isToday: Bool) -> some View {
        VStack(spacing: 8) {
            Text(isPast ? "呢日冇記低嘢" : (isToday ? "tap \"+\" 加件事" : "冇活動"))
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.inkMuted)
            Text(isPast ? "(´｡• ω •｡`)" : "＿(:3 」∠)＿")
                .font(DSText.mono(theme, 16))
                .foregroundStyle(theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        )
    }

    // MARK: - 一年前嘅今日

    private var lookbackSection: some View {
        let lookbacks = entries.filter { entry in
            guard entry.isPast(today: todayISO),
                  let entryDate = TimeFormatting.parseDate(entry.date),
                  let today = TimeFormatting.parseDate(todayISO)
            else { return false }
            let cal = Calendar(identifier: .gregorian)
            let entryComponents = cal.dateComponents([.month, .day, .year], from: entryDate)
            let todayComponents = cal.dateComponents([.month, .day, .year], from: today)
            return entryComponents.month == todayComponents.month
                && entryComponents.day == todayComponents.day
                && (entryComponents.year ?? 0) < (todayComponents.year ?? 0)
        }

        if lookbacks.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            VStack(alignment: .leading, spacing: 10) {
                Text("⌛ 一年前嘅今日")
                    .font(DSText.mono(theme, 10).weight(.semibold))
                    .foregroundStyle(theme.rose)
                    .padding(.leading, 4)

                ForEach(lookbacks) { m in
                    LookbackRow(entry: m, todayISO: todayISO) {
                        presentedEntryID = m.id
                    }
                }
            }
        )
    }

    // MARK: - Helpers

    private var isCurrentMonth: Bool {
        guard let today = TimeFormatting.parseDate(todayISO) else { return false }
        let cal = Calendar(identifier: .gregorian)
        return viewYear == cal.component(.year, from: today)
            && viewMonth == cal.component(.month, from: today)
    }

    private var nextAnniversary: (anniversary: Anniversary, days: Int, ordinal: Int?)? {
        guard let today = TimeFormatting.parseDate(todayISO) else { return nil }
        let entries = anniversaries.map { a in
            let occ = a.nextOccurrence(today: today)
            return (anniversary: a, days: occ.daysAway, ordinal: occ.ordinal)
        }
        return entries.min(by: { $0.days < $1.days })
    }

    private var monthCountsLabel: String {
        let monthPrefix = String(format: "%04d-%02d", viewYear, viewMonth)
        let monthEntries = entries.filter { $0.date.hasPrefix(monthPrefix) }
        let memories = monthEntries.filter { $0.isPast(today: todayISO) }.count
        let upcoming = monthEntries.count - memories
        return "\(memories) 個記憶 · \(upcoming) 個提醒"
    }

    private func prevMonth() {
        if viewMonth == 1 { viewMonth = 12; viewYear -= 1 }
        else { viewMonth -= 1 }
    }

    private func nextMonth() {
        if viewMonth == 12 { viewMonth = 1; viewYear += 1 }
        else { viewMonth += 1 }
    }
}

// MARK: - Row components

private struct PastEntryRow: View {
    @Environment(\.theme) private var theme
    let entry: Entry
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // v1.2.0 — real encrypted cover when available.
                Group {
                    if let cover = entry.cover, cover.hasPrefix("couple-") {
                        EncryptedAsyncImage(mediaHandle: cover, maxHeight: 64, cornerRadius: 10)
                    } else {
                        DSPhotoPlaceholder(id: entry.cover ?? entry.id, height: 64, cornerRadius: 10)
                    }
                }
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("已發生")
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                            .foregroundStyle(theme.sage)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(theme.sageSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                        if let time = entry.time {
                            Text(time)
                                .font(DSText.mono(theme, 11))
                                .foregroundStyle(theme.inkMuted)
                        }
                    }
                    Text(entry.title)
                        .font(.system(size: 15, weight: .semibold, design: .serif))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    HStack(spacing: 10) {
                        Text("📷 \(entry.photos)")
                        if entry.voiceClips > 0 { Text("🎙 \(entry.voiceClips)") }
                        Text("💬 \(entry.messages)")
                    }
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.inkMuted)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }
}

private struct UpcomingCardRow: View {
    @Environment(\.theme) private var theme
    let entry: Entry
    let hero: Bool
    let onTap: () -> Void

    var body: some View {
        let tagC = tagColor(for: entry.tag)
        Button(action: onTap) {
            HStack(spacing: 12) {
                Capsule().fill(tagC).frame(width: 4)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(entry.title + (entry.isSpecial ? " ♡" : ""))
                            .font(.system(size: hero ? 17 : 15, weight: .semibold))
                            .foregroundStyle(theme.ink)
                        Spacer()
                        if let time = entry.time {
                            Text(time)
                                .font(DSText.mono(theme, 12))
                                .foregroundStyle(theme.inkSoft)
                        }
                    }

                    if let loc = entry.location {
                        HStack(spacing: 4) {
                            DSIcon(name: .pin2, size: 10, color: theme.inkMuted)
                            Text(loc)
                                .font(DSText.ui(theme, 12))
                                .foregroundStyle(theme.inkSoft)
                        }
                    }

                    if let notes = entry.notes, hero {
                        Text("📝 \(notes)")
                            .font(DSText.ui(theme, 12))
                            .foregroundStyle(theme.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(theme.roseSoft)
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .padding(.top, 4)
                    }

                    HStack(spacing: 8) {
                        whoCluster
                    }
                    .padding(.top, hero ? 6 : 2)
                }
                .padding(.vertical, hero ? 16 : 12)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .padding(.bottom, 8)
    }

    private var whoCluster: some View {
        HStack(spacing: 8) {
            switch entry.who {
            case .both:
                ZStack(alignment: .leading) {
                    DSAvatar(person: MockData.partner, size: 18)
                    DSAvatar(person: MockData.me, size: 18).offset(x: 12)
                }
                .frame(width: 30)
                Text("我哋兩個")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.inkMuted)
            case .mine:
                DSAvatar(person: MockData.me, size: 18)
                Text("只係 Kit")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.inkMuted)
            case .theirs:
                DSAvatar(person: MockData.partner, size: 18)
                Text("只係 Michel")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.inkMuted)
            }
        }
    }

    private func tagColor(for tag: Entry.Tag) -> Color {
        switch tag {
        case .special, .food: return theme.rose
        case .outing, .walk:  return theme.sage
        case .home:           return theme.amber
        case .solo:           return theme.inkMuted
        }
    }
}

private struct LookbackRow: View {
    @Environment(\.theme) private var theme
    let entry: Entry
    let todayISO: String
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 10) {
                DSPhotoPlaceholder(id: entry.cover ?? entry.id, height: 72, cornerRadius: 10)
                    .frame(width: 72)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(yearsAgo) 年前")
                        .font(DSText.mono(theme, 10).weight(.semibold))
                        .foregroundStyle(theme.rose)
                    Text(entry.title)
                        .font(.system(size: 16, weight: .semibold, design: .serif))
                        .foregroundStyle(theme.ink)
                        .lineLimit(1)
                    if let r = entry.reflection {
                        Text("\u{201C}\(r.text)\u{201D}")
                            .font(DSText.ui(theme, 12))
                            .foregroundStyle(theme.inkSoft)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(
                LinearGradient(
                    colors: [theme.roseSoft, theme.amberSoft],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.rose.opacity(0.2), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var yearsAgo: Int {
        guard let entryDate = TimeFormatting.parseDate(entry.date),
              let today = TimeFormatting.parseDate(todayISO)
        else { return 1 }
        let cal = Calendar(identifier: .gregorian)
        return cal.component(.year, from: today) - cal.component(.year, from: entryDate)
    }
}

#Preview {
    TimeView().theme(.jbeam)
}
