import SwiftUI

// v1.3.0 — MTR 站日記. Sibling of DistrictsView (18 區日記) but
// granularity is the MTR station instead of the district. Stations are
// grouped by line, each line tinted to its official MTR brand color.
//
// Backed by PlayHistoryService.recordMtrStation (kind: .mtrStation,
// mtrStationCode: 3-letter MTR code).

struct MTRStationsView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var playHistory: PlayHistoryService
    @EnvironmentObject private var auth: AuthService
    let onClose: () -> Void

    @State private var selected: MTRStation? = nil

    private var visited: Set<String> { playHistory.visitedMtrCodes }
    private var visitedCount: Int { visited.count }
    private var totalCount: Int { MTRStation.all.count }

    var body: some View {
        VStack(spacing: 0) {
            navBar

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    progressBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    ForEach(MTRLine.allCases, id: \.self) { line in
                        lineSection(line)
                    }

                    Color.clear.frame(height: 24)
                }
            }
        }
        .background(theme.paper.ignoresSafeArea())
        .sheet(item: $selected) { station in
            MTRStationEntrySheet(
                station: station,
                latestEntry: playHistory.latestEntry(forMtr: station.id),
                onClose: { selected = nil }
            )
            .theme(theme)
        }
    }

    // MARK: - Pieces

    private var navBar: some View {
        HStack {
            Button(action: onClose) {
                DSIcon(name: .back, size: 22, color: theme.rose, strokeWidth: 2.2)
                    .padding(6)
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text("MTR 站日記")
                    .font(DSText.ui(theme, 15, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("\(visitedCount)/\(totalCount) 個站去過")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Color.clear.frame(width: 34)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .padding(.bottom, 12)
    }

    private var progressBanner: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("一齊搭遍 MTR")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text("出個站，行一日，記返今日")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(visitedCount)")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("/ \(totalCount) 站")
                    .font(DSText.mono(theme, 9))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            LinearGradient(colors: [theme.rose, theme.amber],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func lineSection(_ line: MTRLine) -> some View {
        let stations = MTRStation.stations(on: line)
        let lineColor = Color(hex: line.colorHex)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Capsule().fill(lineColor).frame(width: 16, height: 4)
                Text(line.rawValue)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.ink)
                Spacer()
                let visitedOnLine = stations.filter { visited.contains($0.id) }.count
                Text("\(visitedOnLine)/\(stations.count)")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(stations.indices, id: \.self) { i in
                    stationRow(stations[i], lineColor: lineColor,
                               showDivider: i < stations.count - 1)
                }
            }
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .padding(.horizontal, 16)
        }
    }

    private func stationRow(_ s: MTRStation, lineColor: Color, showDivider: Bool) -> some View {
        let isDone = visited.contains(s.id)
        return Button { selected = s } label: {
            HStack(spacing: 12) {
                Circle()
                    .fill(isDone ? lineColor : theme.surface)
                    .overlay(Circle().stroke(lineColor, lineWidth: 2))
                    .frame(width: 14, height: 14)

                Text(s.name)
                    .font(DSText.ui(theme, 14, weight: isDone ? .semibold : .regular))
                    .foregroundStyle(theme.ink)

                Text(s.id)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.inkMuted)

                Spacer()

                if isDone {
                    DSIcon(name: .check, size: 14, color: theme.sage, strokeWidth: 2.4)
                } else {
                    Text("tap →")
                        .font(DSText.mono(theme, 10))
                        .foregroundStyle(theme.inkMuted)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(isDone ? lineColor.opacity(0.06) : Color.clear)
            .contentShape(Rectangle())
            .overlay(
                Rectangle()
                    .frame(height: showDivider ? 0.5 : 0)
                    .foregroundStyle(theme.line),
                alignment: .bottom
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let crypto = CryptoService()
    return MTRStationsView(onClose: {})
        .environmentObject(PlayHistoryService(crypto: crypto))
        .environmentObject(AuthService())
        .theme(.cream)
}
