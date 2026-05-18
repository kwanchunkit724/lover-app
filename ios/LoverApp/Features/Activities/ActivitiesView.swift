import SwiftUI

// 玩樂 tab top-level — translation of Activities() in design-import/screens.jsx.
// Featured "本週推介" hero card + 2-column grid of activity tiles.

struct ActivitiesView: View {
    @Environment(\.theme) private var theme

    @State private var presented: ActivityRoute? = nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                featureCard
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                grid
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
        }
        .background(theme.paper)
        .sheet(item: $presented) { route in
            switch route {
            case .cards:     CardDeckView(onClose: { presented = nil }).theme(theme)
            case .quiz:      QuizView(onClose: { presented = nil }).theme(theme)
            case .journal:   JournalView(onClose: { presented = nil }).theme(theme)
            case .districts: DistrictsView(onClose: { presented = nil }).theme(theme)
            case .mtr:       MTRStationsView(onClose: { presented = nil }).theme(theme)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("玩樂")
                .font(.system(size: 32, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
            Text("約會點子、小遊戲、測驗")
                .font(DSText.mono(theme, 11))
                .foregroundStyle(theme.inkMuted)
        }
    }

    private var featureCard: some View {
        ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 0) {
                Text("本週推介")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(.white.opacity(0.7))

                Text("抽張卡，今晚做乜？")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                    .padding(.top, 4)

                Text("24 個冇做過嘅約會點子\n由 random 揀")
                    .font(DSText.ui(theme, 13))
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.top, 6)

                Button {
                    presented = .cards
                } label: {
                    Text("抽卡 →")
                        .font(DSText.ui(theme, 13, weight: .semibold))
                        .foregroundStyle(theme.rose)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(.white)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 14)
            }
            .padding(20)

            Text("(♡˙︶˙♡)")
                .font(DSText.mono(theme, 36))
                .foregroundStyle(.white.opacity(0.3))
                .rotationEffect(.degrees(15))
                .offset(x: 10, y: -10)
                .clipped()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.rose)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private var grid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible(), spacing: 10),
            GridItem(.flexible(), spacing: 10)
        ], spacing: 10) {
            ForEach(ActivityCatalog.all) { activity in
                tile(activity)
            }
        }
    }

    private func tile(_ activity: Activity) -> some View {
        Button {
            switch activity.kind {
            case .cards:     presented = .cards
            case .quiz:      presented = .quiz
            case .journal:   presented = .journal
            case .districts: presented = .districts
            case .mtr:       presented = .mtr
            case .map:       break    // legacy — superseded by .districts
            }
        } label: {
            VStack(alignment: .leading, spacing: 0) {
                iconBadge(for: activity.kind)
                    .padding(.bottom, 10)

                Text(activity.title)
                    .font(DSText.ui(theme, 14, weight: .semibold))
                    .foregroundStyle(theme.ink)

                Text(activity.subtitle)
                    .font(DSText.ui(theme, 11))
                    .foregroundStyle(theme.inkSoft)
                    .lineSpacing(1)
                    .padding(.top, 3)

                if let count = activity.count {
                    Text("\(count) 個")
                        .font(DSText.mono(theme, 10))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.top, 8)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 120, alignment: .leading)
            .padding(14)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func iconBadge(for kind: Activity.Kind) -> some View {
        let (iconName, fgColor, bgColor): (DSIconName, Color, Color) = {
            switch kind {
            case .cards:     return (.sparkle, theme.rose, theme.roseSoft)
            case .quiz:      return (.kao, theme.sage, theme.sageSoft)
            case .map:       return (.pin2, theme.amber, theme.amberSoft)
            case .journal:   return (.edit, theme.amber, theme.amberSoft)
            case .districts: return (.pin2, theme.rose, theme.roseSoft)
            case .mtr:       return (.pin2, theme.sage, theme.sageSoft)
            }
        }()
        return DSIcon(name: iconName, size: 16, color: fgColor)
            .frame(width: 32, height: 32)
            .background(bgColor)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private enum ActivityRoute: String, Identifiable {
    case cards, quiz, journal, districts, mtr
    var id: String { rawValue }
}

#Preview {
    ActivitiesView().theme(.jbeam)
}
