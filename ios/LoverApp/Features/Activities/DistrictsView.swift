import SwiftUI

// v1.1.0 — 18 區日記. Grid view of Hong Kong's 18 districts with visit
// progress + a tap-to-journal flow. Replaces the placeholder 香港探險地圖
// activity tile. Backed by PlayHistoryService.recordDistrict.

struct DistrictsView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var playHistory: PlayHistoryService
    @EnvironmentObject private var auth: AuthService
    let onClose: () -> Void

    @State private var selectedDistrict: District? = nil

    private var visited: Set<String> { playHistory.visitedDistrictCodes }
    private var visitedCount: Int { visited.count }
    private var totalCount: Int { District.all.count }

    var body: some View {
        VStack(spacing: 0) {
            navBar

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    progressBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 8)

                    ForEach(District.Region.allCases, id: \.self) { region in
                        regionSection(region)
                    }

                    Color.clear.frame(height: 24)
                }
            }
        }
        .background(theme.paper.ignoresSafeArea())
        .errorToast(Binding(
            get: { playHistory.lastError },
            set: { playHistory.lastError = $0 }
        ))
        .sheet(item: $selectedDistrict) { d in
            DistrictEntrySheet(
                district: d,
                latestEntry: playHistory.latestEntry(forDistrict: d.id),
                onClose: { selectedDistrict = nil }
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
                Text("18 區日記")
                    .font(DSText.ui(theme, 15, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("\(visitedCount)/\(totalCount) 區去過")
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
                Text("一齊行勻香港")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text("揀一區，去一日，寫返兩句")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(.white.opacity(0.85))
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 0) {
                Text("\(visitedCount)")
                    .font(.system(size: 30, weight: .bold, design: .serif))
                    .foregroundStyle(.white)
                Text("/ \(totalCount) 區")
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

    private func regionSection(_ region: District.Region) -> some View {
        let districts = District.all.filter { $0.region == region }
        return VStack(alignment: .leading, spacing: 10) {
            Text(region.rawValue)
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.inkMuted)
                .padding(.horizontal, 20)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
            ], spacing: 10) {
                ForEach(districts) { d in
                    tile(d)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func tile(_ d: District) -> some View {
        let isDone = visited.contains(d.id)
        let tint = tintColor(for: d.tint)
        // v1.4.2 — surface the saved photo (if any) as the tile background.
        let cover: String? = playHistory.latestEntry(forDistrict: d.id)?.payload.coverHandle
        return Button {
            selectedDistrict = d
        } label: {
            ZStack(alignment: .topLeading) {
                // Photo background, if attached
                if let cover, cover.hasPrefix("couple-") {
                    EncryptedAsyncImage(mediaHandle: cover, maxHeight: 160, cornerRadius: 14)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                    LinearGradient(
                        colors: [Color.black.opacity(0.05), .clear, Color.black.opacity(0.55)],
                        startPoint: .top, endPoint: .bottom
                    )
                }

                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(d.name)
                            .font(.system(size: 16, weight: .semibold, design: .serif))
                            .foregroundStyle(cover != nil ? .white : theme.ink)
                        Spacer()
                        if isDone {
                            DSIcon(name: .check, size: 14,
                                   color: cover != nil ? .white : theme.sage,
                                   strokeWidth: 2.4)
                        }
                    }

                    Text(d.kaomoji)
                        .font(DSText.mono(theme, 18))
                        .foregroundStyle(cover != nil ? .white : tint)
                        .padding(.top, 8)

                    Spacer(minLength: 0)

                    Text(isDone ? "已記低 ♡" : "tap 寫日記")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(cover != nil
                                         ? .white.opacity(0.9)
                                         : (isDone ? theme.sage : theme.inkMuted))
                        .padding(.top, 8)
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
            .background(cover != nil
                        ? AnyView(Color.clear)
                        : AnyView(isDone ? tint.opacity(0.13) : theme.surface))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isDone ? tint.opacity(0.5) : theme.line,
                            lineWidth: isDone ? 1 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tintColor(for t: District.Tint) -> Color {
        switch t {
        case .rose:  return theme.rose
        case .sage:  return theme.sage
        case .amber: return theme.amber
        }
    }
}

#Preview {
    let crypto = CryptoService()
    return DistrictsView(onClose: {})
        .environmentObject(PlayHistoryService(crypto: crypto))
        .environmentObject(AuthService())
        .theme(.jbeam)
}
