import SwiftUI

// Entry detail screen — translation of EntryDetail() in design-import/screens.jsx.
// Same screen handles both upcoming (reminder) and past (memory) states.

struct EntryDetailView: View {
    @Environment(\.theme) private var theme
    let entry: Entry
    let onClose: () -> Void

    // v1.4.2 — was using MockData.todayISO (hardcoded constant from a
    // dev day in 2026), so any entry whose date was BEFORE that constant
    // never flipped to "已發生 · 記憶". Use the real current day.
    private var isPast: Bool { entry.isPast(today: LocalDate.string(from: Date())) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navBar

                if isPast, let cover = entry.cover {
                    // v1.4.1 — render real encrypted cover photo if attached;
                    // otherwise fall back to the gradient placeholder.
                    if cover.hasPrefix("couple-") {
                        EncryptedAsyncImage(mediaHandle: cover, maxHeight: 280, cornerRadius: 0)
                    } else {
                        DSPhotoPlaceholder(id: cover, height: 240, cornerRadius: 0)
                    }
                }

                VStack(alignment: .leading, spacing: 0) {
                    statusPill
                        .padding(.bottom, 8)

                    Text(entry.title + (entry.isSpecial ? " ♡" : ""))
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(theme.ink)
                        .padding(.bottom, 6)

                    Text("\(TimeFormatting.fullString(entry.date))" + (entry.time.map { " · \($0)" } ?? ""))
                        .font(DSText.mono(theme, 12))
                        .foregroundStyle(theme.inkMuted)

                    metaRow
                        .padding(.top, 14)

                    Text(proposerLabel)
                        .font(DSText.mono(theme, 11))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.top, 8)

                    if isPast {
                        pastSections
                    } else {
                        upcomingSections
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 30)
            }
        }
        .background(theme.paper)
    }

    // MARK: - Top nav

    private var navBar: some View {
        HStack {
            Button(action: onClose) {
                DSIcon(name: .back, size: 22, color: theme.rose, strokeWidth: 2.2)
                    .padding(6)
            }
            .buttonStyle(.plain)

            Spacer()

            Text(isPast ? "記憶" : "提醒")
                .font(DSText.mono(theme, 11))
                .foregroundStyle(theme.inkMuted)

            Spacer()

            // v1.4.0 — removed dead "more" placeholder button.
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .background(theme.nav)
        .background(.thinMaterial)
    }

    // MARK: - Status pill

    private var statusPill: some View {
        HStack(spacing: 8) {
            Text(isPast ? "已發生 · 記憶" : "未發生 · 提醒")
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(isPast ? theme.sage : theme.rose)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isPast ? theme.sageSoft : theme.roseSoft)
                .clipShape(Capsule())

            if entry.tag != .solo {
                Text("＃\(entry.tag.rawValue)")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.inkMuted)
            }
        }
    }

    // MARK: - Meta row

    private var metaRow: some View {
        HStack(spacing: 14) {
            metaPair(icon: .pin2, label: entry.location ?? "冇地點")
            metaPair(icon: .us, label: whoLabel)
        }
        .padding(.top, 14)
        .padding(.bottom, 0)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
            alignment: .top
        )
    }

    private func metaPair(icon: DSIconName, label: String) -> some View {
        HStack(spacing: 6) {
            DSIcon(name: icon, size: 12, color: theme.inkMuted)
            Text(label)
                .font(DSText.ui(theme, 12))
                .foregroundStyle(theme.inkSoft)
        }
    }

    private var whoLabel: String {
        switch entry.who {
        case .both:   return "我哋兩個"
        case .mine:   return "只係 Kit"
        case .theirs: return "只係 Michel"
        }
    }

    private var proposerLabel: String {
        if entry.proposedBy == "kit" { return "Kit 提議" }
        if entry.proposedBy == "michel" { return "Michel 提議" }
        return "一齊諗到"
    }

    // MARK: - Upcoming sections

    private var upcomingSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let notes = entry.notes {
                section(title: "筆記") {
                    Text("📝 \(notes)")
                        .font(DSText.ui(theme, 14))
                        .foregroundStyle(theme.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                }
            }

            section(title: "提醒") {
                rowItem(icon: .clock, label: "提前提醒", value: "1 個鐘前")
                rowItem(icon: .heart, label: "過咗存做記憶", value: "開")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("過咗之後 ⤵")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.amber)
                Text("呢個提醒會自動變成記憶。當日嘅相片、語音、對話會自動結集喺度。你可以後補感想、地點。")
                    .font(DSText.ui(theme, 13))
                    .foregroundStyle(theme.ink)
            }
            .padding(14)
            .background(theme.amberSoft)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(.top, 18)
    }

    // MARK: - Past sections

    private var pastSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let r = entry.reflection {
                VStack(alignment: .leading, spacing: 6) {
                    Text((r.from == "kit" ? "KIT" : "MICHEL") + " 寫低")
                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.rose)
                    Text(r.text)
                        .font(DSText.ui(theme, 14))
                        .foregroundStyle(theme.ink)
                        .lineSpacing(3)
                    if let kao = r.kaomoji {
                        Text(kao)
                            .font(DSText.mono(theme, 16))
                            .foregroundStyle(theme.rose)
                            .padding(.top, 4)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(theme.roseSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                // v1.4.0 — removed dead "+ Michel 仲未寫感想" placeholder
                // (the partner reflection feature isn't built yet).
                if false, r.from == "kit" {
                    Button {} label: {
                        Text("＋ Michel 仲未寫感想")
                            .font(DSText.ui(theme, 13))
                            .foregroundStyle(theme.inkMuted)
                            .frame(maxWidth: .infinity)
                            .padding(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(theme.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                            )
                    }
                    .buttonStyle(.plain)
                }
            }

            if entry.photos > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    // v1.4.1 — when there's a real encrypted cover, render
                    // it once instead of the deterministic-hash placeholder
                    // grid. Each entry only has one cover photo today; the
                    // multi-photo album shape is for a future phase.
                    if let cover = entry.cover, cover.hasPrefix("couple-") {
                        EncryptedAsyncImage(mediaHandle: cover, maxHeight: 220, cornerRadius: 8)
                    } else {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 3), spacing: 4) {
                            ForEach(0..<min(entry.photos, 6), id: \.self) { i in
                                DSPhotoPlaceholder(id: "\(entry.id)-p\(i)", height: 100, cornerRadius: 6)
                            }
                        }
                    }
                }
            }

            // v1.4.1 — voice + chat-message sections are mocked data and
            // were confusing users (showing fake "當日嘅笑聲" / "Michel:
            // 而家行緊嚟" on real entries that had no such media). Hide
            // them entirely until Phase 4d wires real per-entry media.
            if false, entry.voiceClips > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    Text("語音 · \(entry.voiceClips) 段")
                        .font(DSText.mono(theme, 10))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.leading, 4)

                    HStack(spacing: 12) {
                        DSIcon(name: .play2, size: 14, color: theme.rose)
                            .frame(width: 36, height: 36)
                            .background(theme.roseSoft)
                            .clipShape(Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("當日嘅笑聲")
                                .font(DSText.ui(theme, 13))
                                .foregroundStyle(theme.ink)
                            Text("0:14")
                                .font(DSText.mono(theme, 10))
                                .foregroundStyle(theme.inkMuted)
                        }
                        Spacer()
                    }
                    .padding(12)
                    .background(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(theme.line, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            if false, entry.messages > 0 {
                VStack(alignment: .leading, spacing: 10) {
                    Text("當日對話 · \(entry.messages) 條")
                        .font(DSText.mono(theme, 10))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.leading, 4)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Michel: 而家行緊嚟 (´｡• ω •｡`)")
                            .foregroundStyle(theme.inkSoft)
                        Text("Kit: 慢慢嚟，我等你")
                            .foregroundStyle(theme.inkSoft)
                        Text("… 仲有 \(entry.messages - 2) 條")
                            .font(DSText.mono(theme, 11))
                            .foregroundStyle(theme.inkMuted)
                            .padding(.top, 4)
                    }
                    .font(DSText.ui(theme, 13))
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(theme.line, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }

            // v1.4.0 — removed the "+ 加相 / 補感想 / 地點" chip row. They
            // were design placeholders with empty actions; the real photo
            // upload now lives in AddEntryView's 封面相片 section, location
            // is set on creation, and partner reflection is queued for a
            // later phase.
        }
        .padding(.top, 18)
    }

    private func addChip(icon: DSIconName, label: String) -> some View {
        Button {} label: {
            Text(label)
                .font(DSText.ui(theme, 12))
                .foregroundStyle(theme.inkSoft)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .padding(.horizontal, 8)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.lineStrong, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section primitive

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(theme.inkMuted)
                .textCase(.uppercase)
                .padding(.leading, 4)
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func rowItem(icon: DSIconName, label: String, value: String) -> some View {
        HStack(spacing: 12) {
            DSIcon(name: icon, size: 16, color: theme.inkMuted)
            Text(label)
                .font(DSText.ui(theme, 14))
                .foregroundStyle(theme.ink)
            Spacer()
            Text(value)
                .font(DSText.mono(theme, 13))
                .foregroundStyle(theme.inkSoft)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(
            Rectangle().frame(height: 0.5).foregroundStyle(theme.line),
            alignment: .bottom
        )
    }
}

extension EntryDetailView: Identifiable {
    var id: String { entry.id }
}

#Preview("Past entry") {
    EntryDetailView(entry: MockData.entries.first { $0.id == "m3" }!, onClose: {})
        .theme(.jbeam)
}

#Preview("Upcoming entry") {
    EntryDetailView(entry: MockData.entries.first { $0.id == "e_today1" }!, onClose: {})
        .theme(.jbeam)
}
