import SwiftUI

// 抽卡 — translation of CardDeck() in design-import/extra.jsx.
// Tap card to flip; reveals a date idea. Tap "再抽" to draw the next.

struct CardDeckView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var playHistory: PlayHistoryService
    @EnvironmentObject private var auth: AuthService
    let onClose: () -> Void

    @State private var index: Int = 0
    @State private var flipped: Bool = false
    @State private var drawn: Set<Int> = []
    @State private var lastSavedCardId: Int? = nil
    /// v1.0.6 — local tracking so a just-recorded card is excluded
    /// IMMEDIATELY, not after the DB roundtrip + decrypt. The earlier
    /// version only filtered by playHistory.dateCardHistory which depends
    /// on the round-trip; if the user tapped 再抽 before that landed, the
    /// old card could still get drawn again.
    @State private var locallyDoneIds: Set<Int> = []

    /// v1.0.5/.6 (bug 5.3) — exclude cards the couple has already marked as
    /// done so the deck rotates through fresh ideas. Combines remote history
    /// + the local just-saved set so the new card excludes IMMEDIATELY on
    /// tap, not after Supabase round-trip. When everything has been done,
    /// fall back to the full deck so the screen never goes blank.
    private var doneIds: Set<Int> {
        let remote = Set(playHistory.dateCardHistory.compactMap(\.payload.cardId))
        return remote.union(locallyDoneIds)
    }

    private var availableCards: [DateCard] {
        let remaining = MockData.dateCards.filter { !doneIds.contains($0.id) }
        return remaining.isEmpty ? MockData.dateCards : remaining
    }

    private var card: DateCard {
        let cards = availableCards
        return cards[index % cards.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar

            Spacer()

            ZStack {
                shadowCardLayer(offset: 2)
                shadowCardLayer(offset: 1)
                cardFlipper
            }
            .frame(width: 240, height: 340)

            Spacer()

            buttons
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
        }
        .background(theme.paper)
    }

    // MARK: - Top bar

    private var navBar: some View {
        HStack {
            Button(action: onClose) {
                DSIcon(name: .back, size: 22, color: theme.rose, strokeWidth: 2.2).padding(6)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 2) {
                Text("盲盒約會")
                    .font(DSText.ui(theme, 15, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("\(drawn.count)/24 張已抽 · 做過 \(totalDone) 種")
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

    // MARK: - Card stack

    private func shadowCardLayer(offset: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(theme.surface)
            .frame(width: 240, height: 340)
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .offset(x: offset * 6, y: offset * 6)
            .rotationEffect(.degrees(Double(offset) * 1.5))
            .opacity(0.6)
    }

    private var cardFlipper: some View {
        ZStack {
            cardBack
                .opacity(flipped ? 0 : 1)
                .rotation3DEffect(.degrees(flipped ? -180 : 0), axis: (x: 0, y: 1, z: 0))

            cardFront
                .opacity(flipped ? 1 : 0)
                .rotation3DEffect(.degrees(flipped ? 0 : 180), axis: (x: 0, y: 1, z: 0))
        }
        .animation(.timingCurve(0.4, 0.2, 0.2, 1, duration: 0.6), value: flipped)
    }

    private var cardBack: some View {
        ZStack {
            LinearGradient(
                colors: [theme.rose, theme.amber],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            VStack(spacing: 8) {
                Text("(♡˙︶˙♡)")
                    .font(DSText.mono(theme, 28))
                    .foregroundStyle(.white)
                Text("抽卡")
                    .font(.system(size: 18, weight: .semibold, design: .serif))
                    .foregroundStyle(.white)
                Text("TAP TO REVEAL")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .frame(width: 240, height: 340)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: theme.rose.opacity(0.25), radius: 16, x: 0, y: 12)
    }

    private var cardFront: some View {
        let tintColor = tintColor(for: card.tint)
        let tintSoft = tintSoft(for: card.tint)

        return VStack(alignment: .leading, spacing: 0) {
            Text("#\(String(format: "%03d", card.id)) · \(card.mood)")
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(tintColor)

            Text(card.title)
                .font(.system(size: 22, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
                .padding(.top, 8)
                .lineSpacing(2)

            Text(card.detail)
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.inkSoft)
                .lineSpacing(3)
                .padding(.top, 10)

            Spacer(minLength: 0)

            HStack(spacing: 10) {
                Text(card.cost)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tintColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(tintSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))

                Text(card.kaomoji)
                    .font(DSText.mono(theme, 16))
                    .foregroundStyle(tintColor)
            }
        }
        .padding(22)
        .frame(width: 240, height: 340, alignment: .topLeading)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(theme.line, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 16, x: 0, y: 12)
    }

    // MARK: - Buttons

    private var buttons: some View {
        HStack(spacing: 10) {
            if !flipped {
                Button {
                    flipped = true
                    drawn.insert(card.id)
                } label: {
                    HStack(spacing: 4) {
                        Text("抽張卡")
                            .font(DSText.ui(theme, 15, weight: .semibold))
                        Text("(◕‿◕)")
                            .font(DSText.mono(theme, 14))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(theme.rose)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    flipped = false
                    lastSavedCardId = nil
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        index += 1
                    }
                } label: {
                    Text("再抽")
                        .font(DSText.ui(theme, 15, weight: .medium))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(theme.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(theme.line, lineWidth: 0.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)

                Button { recordDoneTap() } label: {
                    HStack(spacing: 6) {
                        if isJustSaved {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .semibold))
                            Text("已記錄 ♡")
                        } else {
                            Text("我哋做過 ♡")
                        }
                    }
                    .font(DSText.ui(theme, 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isJustSaved ? theme.sage : theme.rose)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(isJustSaved)
            }
        }
    }

    // MARK: - Helpers

    private func tintColor(for t: DateCard.Tint) -> Color {
        switch t {
        case .rose:  return theme.rose
        case .sage:  return theme.sage
        case .amber: return theme.amber
        }
    }

    private func tintSoft(for t: DateCard.Tint) -> Color {
        switch t {
        case .rose:  return theme.roseSoft
        case .sage:  return theme.sageSoft
        case .amber: return theme.amberSoft
        }
    }

    // MARK: - History (v0.6.0)

    private var isJustSaved: Bool { lastSavedCardId == card.id }

    /// How many times this couple has recorded the current card as done.
    private var doneCount: Int { playHistory.dateCardDoneCount(card.id) }

    /// Total date cards across the catalog this couple has touched.
    private var totalDone: Int {
        Set(playHistory.dateCardHistory.compactMap(\.payload.cardId)).count
    }

    private func recordDoneTap() {
        guard case .signedIn(let uuid) = auth.state else { return }
        let cardId = card.id
        // Mark locally first so availableCards instantly excludes it even if
        // the network upload takes a while or silently fails.
        locallyDoneIds.insert(cardId)
        lastSavedCardId = cardId
        Task {
            await playHistory.recordDateCard(cardId: cardId, reflection: nil, senderId: uuid)
        }
    }
}

#Preview {
    let crypto = CryptoService()
    return CardDeckView(onClose: {})
        .environmentObject(PlayHistoryService(crypto: crypto))
        .environmentObject(AuthService())
        .theme(.jbeam)
}
