import SwiftUI

// 7-column calendar grid for the time tab — translation of the cell logic
// inside Timetable() in design-import/screens.jsx.
//
// Each cell renders one of three states:
//   1. Past day with a memory  → photo fills the cell + day number top-left
//   2. Today / upcoming day    → surface bg + day number + up to 2 entry labels
//   3. Past day with no memory → dashed outline placeholder

struct MonthGrid: View {
    @Environment(\.theme) private var theme

    let year: Int
    let month: Int   // 1...12
    let todayISO: String
    let entries: [Entry]
    @Binding var selectedISO: String

    var body: some View {
        VStack(spacing: 4) {
            weekdayHeader
            grid
        }
    }

    // MARK: - Weekday header

    private var weekdayHeader: some View {
        HStack(spacing: 3) {
            ForEach(TimeFormatting.weekdays, id: \.self) { d in
                Text(d)
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Grid

    private var grid: some View {
        let cells = buildCells()
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 3), count: 7),
            spacing: 3
        ) {
            ForEach(cells.indices, id: \.self) { i in
                if let day = cells[i] {
                    cell(day: day)
                } else {
                    Color.clear.aspectRatio(1, contentMode: .fit)
                }
            }
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private func cell(day: Int) -> some View {
        let iso = isoString(day: day)
        let dayEntries = entries.filter { $0.date == iso }
        let past = dayEntries.first { $0.isPast(today: todayISO) }
        let upcoming = dayEntries.filter { !$0.isPast(today: todayISO) }
        let isToday = iso == todayISO
        let isSelected = iso == selectedISO
        let isPastEmpty = iso < todayISO && past == nil

        Button {
            selectedISO = iso
        } label: {
            ZStack(alignment: .topLeading) {
                if let past {
                    photoCell(past, day: day)
                } else {
                    labelCell(day: day, upcoming: upcoming, isToday: isToday, isPastEmpty: isPastEmpty)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(isSelected ? theme.rose : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // Past day with memory — photo fills cell.
    private func photoCell(_ entry: Entry, day: Int) -> some View {
        ZStack(alignment: .topLeading) {
            DSPhotoPlaceholder(id: entry.cover ?? entry.id, height: 999, cornerRadius: 8)

            LinearGradient(
                colors: [Color.black.opacity(0.05), .clear, Color.black.opacity(0.55)],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text("\(day)")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.4), radius: 1, y: 1)
                .padding(.leading, 5)
                .padding(.top, 4)

            if entry.isSpecial {
                Text("♡")
                    .font(.system(size: 10))
                    .foregroundStyle(.white)
                    .padding(.trailing, 5)
                    .padding(.top, 4)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            if entry.photos > 0 {
                Text("\(entry.photos)")
                    .font(.system(size: 8, weight: .regular, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(Color.black.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                    .padding(.trailing, 4)
                    .padding(.bottom, 3)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
        }
    }

    // Today / upcoming / empty-past day cell.
    private func labelCell(day: Int, upcoming: [Entry], isToday: Bool, isPastEmpty: Bool) -> some View {
        let bg: Color = isToday ? theme.rose : (isPastEmpty ? .clear : theme.surface)
        let border: Color = isPastEmpty ? theme.line : theme.line
        let dayColor: Color = isToday ? .white : (isPastEmpty ? theme.inkMuted : theme.ink)

        return VStack(alignment: .leading, spacing: 2) {
            Text("\(day)")
                .font(.system(size: 11, weight: isToday ? .bold : .medium, design: .monospaced))
                .foregroundStyle(dayColor)

            ForEach(upcoming.prefix(2)) { entry in
                let tagC = tagColor(for: entry.tag)
                Text((entry.isSpecial ? "♡ " : "") + entry.title)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(isToday ? .white : tagC)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(isToday ? Color.white.opacity(0.22) : tagC.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                    .lineLimit(1)
            }

            if upcoming.count > 2 {
                Text("+\(upcoming.count - 2)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundStyle(isToday ? .white.opacity(0.8) : theme.inkMuted)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 5)
        .padding(.top, 5)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(bg)
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(border, style: isPastEmpty ? StrokeStyle(lineWidth: 0.5, dash: [2, 2]) : StrokeStyle(lineWidth: 0.5))
        )
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    // MARK: - Helpers

    /// Build an array sized to a multiple of 7 with leading blanks before day 1
    /// and trailing blanks after last day.
    private func buildCells() -> [Int?] {
        var cells: [Int?] = []
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = 1
        guard let firstDate = calendar.date(from: components),
              let range = calendar.range(of: .day, in: .month, for: firstDate)
        else { return [] }

        let firstWeekday = calendar.component(.weekday, from: firstDate) - 1   // 0 = Sun
        for _ in 0..<firstWeekday { cells.append(nil) }
        for day in range { cells.append(day) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return cells
    }

    private func isoString(day: Int) -> String {
        String(format: "%04d-%02d-%02d", year, month, day)
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

#Preview {
    MonthGrid(
        year: 2026,
        month: 5,
        todayISO: MockData.todayISO,
        entries: MockData.entries,
        selectedISO: .constant(MockData.todayISO)
    )
    .padding()
    .background(Theme.jbeam.paper)
    .theme(.jbeam)
}
