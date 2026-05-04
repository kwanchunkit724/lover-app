import SwiftUI

// 感激清單 — gratitude / daily-reflection journal.
// Each partner can write ONE entry per local day (client-side gate; server
// allows multiple — Phase 6 polish may add a server-side enforcement).
// Both partners see the combined timeline.

struct JournalView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var playHistory: PlayHistoryService
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var pairing: PairingService

    let onClose: () -> Void

    @State private var draft: String = ""
    @State private var isSubmitting = false

    private var meId: UUID? {
        if case .signedIn(let id) = auth.state { return id }
        return nil
    }

    private var hasWrittenToday: Bool {
        guard let meId else { return false }
        return playHistory.hasJournaledToday(senderId: meId)
    }

    /// All journal entries from both partners, newest first.
    private var entries: [PlayHistoryService.DecryptedItem] {
        playHistory.journalEntries
    }

    /// Entries grouped by day so we can render section headers like
    /// "5月 4 日 (一)" with both partners' entries underneath.
    private var groupedByDay: [(dayISO: String, items: [PlayHistoryService.DecryptedItem])] {
        let groups = Dictionary(grouping: entries) { $0.payload.dayISO ?? "未知" }
        return groups
            .map { (dayISO: $0.key, items: $0.value) }
            .sorted { $0.dayISO > $1.dayISO }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navBar

                composer
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 22)

                if entries.isEmpty {
                    emptyState
                        .padding(.top, 40)
                } else {
                    timeline
                        .padding(.horizontal, 20)
                        .padding(.bottom, 28)
                }
            }
        }
        .background(theme.paper)
    }

    // MARK: - Nav

    private var navBar: some View {
        HStack {
            Button(action: onClose) {
                DSIcon(name: .back, size: 22, color: theme.rose, strokeWidth: 2.2).padding(6)
            }
            .buttonStyle(.plain)
            VStack(spacing: 2) {
                Text("感激清單")
                    .font(DSText.ui(theme, 15, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("\(entries.count) 條 · 每日一條")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.inkMuted)
            }
            .frame(maxWidth: .infinity)
            // Spacer right to keep title centered
            Color.clear.frame(width: 36, height: 1)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .padding(.bottom, 12)
    }

    // MARK: - Composer

    @ViewBuilder
    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("今日感激啲乜")
                .font(DSText.mono(theme, 11))
                .foregroundStyle(theme.inkMuted)
                .textCase(.uppercase)

            if hasWrittenToday {
                doneCard
            } else {
                editor
            }
        }
    }

    private var doneCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(theme.sage)
            VStack(alignment: .leading, spacing: 2) {
                Text("今日已記低 ♡")
                    .font(DSText.ui(theme, 14, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("聽日再嚟")
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
        }
        .padding(14)
        .background(theme.sageSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("e.g. 多謝你今朝沖嘅咖啡 (♡˙︶˙♡)")
                        .font(DSText.ui(theme, 14))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $draft)
                    .font(DSText.ui(theme, 14))
                    .foregroundStyle(theme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(minHeight: 110)
            }
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button(action: submit) {
                HStack(spacing: 6) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("記低")
                    }
                    Text("(◕‿◕)")
                        .font(DSText.mono(theme, 13))
                        .opacity(isSubmitting ? 0 : 1)
                }
                .font(DSText.ui(theme, 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 48)
                .background(canSubmit ? theme.rose : theme.line)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!canSubmit || isSubmitting)
        }
    }

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        guard canSubmit, let meId else { return }
        let text = draft.trimmingCharacters(in: .whitespaces)
        let payload = PlayHistoryPayload(
            kind: .journal,
            cardId: nil,
            text: text,
            dayISO: LocalDate.string(from: Date()),
            questionId: nil,
            atISO: ISO8601DateFormatter().string(from: Date())
        )
        isSubmitting = true
        Task {
            await playHistory.add(payload: payload, senderId: meId)
            isSubmitting = false
            draft = ""
        }
    }

    // MARK: - Timeline

    private var timeline: some View {
        VStack(alignment: .leading, spacing: 22) {
            ForEach(groupedByDay, id: \.dayISO) { group in
                VStack(alignment: .leading, spacing: 8) {
                    Text(prettyDay(group.dayISO))
                        .font(DSText.mono(theme, 11))
                        .foregroundStyle(theme.inkMuted)
                        .textCase(.uppercase)
                    VStack(spacing: 8) {
                        ForEach(group.items) { entry in
                            entryCard(entry)
                        }
                    }
                }
            }
        }
    }

    private func entryCard(_ entry: PlayHistoryService.DecryptedItem) -> some View {
        let mine = entry.senderId == meId
        let authorName = mine
            ? (profileStore.profile?.myName ?? "你")
            : (pairing.partner?.myName ?? profileStore.profile?.partnerName ?? "對方")
        return HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(mine ? theme.roseSoft : theme.sageSoft)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(authorName.prefix(1)))
                        .font(DSText.mono(theme, 13))
                        .foregroundStyle(mine ? theme.rose : theme.sage)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(authorName)
                    .font(DSText.ui(theme, 12, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text(entry.payload.text ?? "")
                    .font(DSText.ui(theme, 14))
                    .foregroundStyle(theme.inkSoft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(14)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.line, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contextMenu {
            if mine {
                Button(role: .destructive) {
                    Task { await playHistory.delete(entry) }
                } label: {
                    Label("刪除", systemImage: "trash")
                }
            }
        }
    }

    private func prettyDay(_ iso: String) -> String {
        guard let d = LocalDate.date(from: iso) else { return iso }
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_HK")
        f.dateFormat = "M月 d 日 (EEE)"
        f.timeZone = .current
        return f.string(from: d)
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 14) {
            Text("(´｡• ᵕ •｡`)")
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.rose)
            Text("仲未有感激清單")
                .font(.system(size: 18, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
            Text("每日寫一樣感激，慢慢儲起回憶")
                .font(DSText.ui(theme, 12))
                .foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    let crypto = CryptoService()
    return JournalView(onClose: {})
        .environmentObject(PlayHistoryService(crypto: crypto))
        .environmentObject(AuthService())
        .environmentObject(UserProfileStore())
        .environmentObject(PairingService())
        .theme(.jbeam)
}
