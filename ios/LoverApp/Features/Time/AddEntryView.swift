import SwiftUI

// Add Entry sheet — translation of AddEvent() in design-import/screens.jsx.
// Currently UI-only; persistence wires up when entries move from MockData
// to Supabase in a later milestone.

struct AddEntryView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var entryService: EntryService
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var profileStore: UserProfileStore

    let onClose: () -> Void

    @State private var title: String = ""
    @State private var tag: Entry.Tag = .outing
    @State private var who: Entry.Who = .both
    @State private var proposer: String = "kit"
    @State private var memorable: Bool = true
    @State private var date: Date = Date()
    @State private var includeTime: Bool = false
    @State private var location: String = ""
    @State private var isSubmitting: Bool = false

    private let suggestions = ["食飯", "睇戲", "行山", "散步", "煮嘢食", "紀念日"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navBar
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
            }
        }
        .background(theme.paper)
    }

    private var navBar: some View {
        HStack {
            Button("取消") { onClose() }
                .font(DSText.ui(theme, 15))
                .foregroundStyle(theme.rose)
            Spacer()
            Text("新提醒")
                .font(DSText.ui(theme, 16, weight: .semibold))
                .foregroundStyle(theme.ink)
            Spacer()
            Button(action: submit) {
                if isSubmitting {
                    ProgressView().tint(theme.rose)
                } else {
                    Text("加")
                        .font(DSText.ui(theme, 15, weight: .semibold))
                        .foregroundStyle(canSubmit ? theme.rose : theme.inkMuted)
                }
            }
            .disabled(!canSubmit || isSubmitting)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            TextField("想做啲乜？", text: $title)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
                .padding(.bottom, 14)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestions, id: \.self) { s in
                        DSChip(label: "＋ \(s)") { title = s }
                    }
                }
            }
            .padding(.bottom, 22)

            section(title: "日期 · 時間") {
                VStack(alignment: .leading, spacing: 0) {
                    DatePicker(
                        "日期",
                        selection: $date,
                        displayedComponents: includeTime ? [.date, .hourAndMinute] : .date
                    )
                    .datePickerStyle(.compact)
                    .tint(theme.rose)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider().background(theme.line)

                    Toggle(isOn: $includeTime) {
                        HStack(spacing: 12) {
                            DSIcon(name: .clock, size: 16, color: theme.inkMuted)
                            Text("有時間")
                                .font(DSText.ui(theme, 14))
                                .foregroundStyle(theme.ink)
                        }
                    }
                    .tint(theme.rose)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)

                    Divider().background(theme.line)

                    HStack(spacing: 12) {
                        DSIcon(name: .pin2, size: 16, color: theme.inkMuted)
                        TextField("地點 (可以唔填)", text: $location)
                            .font(DSText.ui(theme, 14))
                            .foregroundStyle(theme.ink)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
            .padding(.bottom, 22)

            section(title: "標籤") {
                HStack {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Entry.Tag.allCases.filter { $0 != .solo }, id: \.self) { t in
                                tagChip(t)
                            }
                        }
                    }
                }
                .padding(14)
            }
            .padding(.bottom, 22)

            section(title: "邊個") {
                VStack(spacing: 0) {
                    HStack(spacing: 8) {
                        whoButton(.both, label: "我哋兩個")
                        whoButton(.mine, label: "只係 Kit")
                        whoButton(.theirs, label: "只係 Michel")
                    }
                    .padding(14)

                    if who == .both {
                        Divider().background(theme.line)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("邊個提議？")
                                .font(DSText.mono(theme, 10))
                                .foregroundStyle(theme.inkMuted)
                            HStack(spacing: 8) {
                                proposerButton("kit", label: "Kit")
                                proposerButton("michel", label: "Michel")
                                proposerButton("both", label: "一齊諗")
                            }
                        }
                        .padding(14)
                    }
                }
            }
            .padding(.bottom, 22)

            section(title: "記憶簿") {
                HStack(spacing: 12) {
                    DSIcon(name: .heart, size: 18, color: theme.rose, filled: memorable)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("過咗之後存做記憶")
                            .font(DSText.ui(theme, 14, weight: .medium))
                            .foregroundStyle(theme.ink)
                        Text("當日相片、語音、對話會自動結集")
                            .font(DSText.mono(theme, 10))
                            .foregroundStyle(theme.inkMuted)
                    }
                    Spacer()
                    Toggle("", isOn: $memorable)
                        .labelsHidden()
                        .tint(theme.rose)
                }
                .padding(14)
            }
            .padding(.bottom, 30)
        }
    }

    // MARK: - Pieces

    private func section<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
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

    private func row(icon: DSIconName, label: String, value: String, isLast: Bool = false) -> some View {
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
            Rectangle()
                .frame(height: isLast ? 0 : 0.5)
                .foregroundStyle(theme.line),
            alignment: .bottom
        )
    }

    private func tagChip(_ t: Entry.Tag) -> some View {
        let active = t == tag
        let color = tagColor(for: t)
        return Button {
            tag = t
        } label: {
            Text("＃\(t.rawValue)")
                .font(DSText.ui(theme, 12))
                .foregroundStyle(theme.ink)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(active ? color.opacity(0.13) : Color.clear)
                .overlay(
                    Capsule()
                        .stroke(active ? color : theme.line, lineWidth: active ? 1.5 : 1)
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func whoButton(_ value: Entry.Who, label: String) -> some View {
        let active = who == value
        return Button { who = value } label: {
            Text(label)
                .font(DSText.ui(theme, 12))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(active ? theme.roseSoft : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(active ? theme.rose : theme.line, lineWidth: active ? 1.5 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func proposerButton(_ value: String, label: String) -> some View {
        let active = proposer == value
        return Button { proposer = value } label: {
            Text(label)
                .font(DSText.ui(theme, 12))
                .foregroundStyle(theme.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(active ? theme.sageSoft : .clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(active ? theme.sage : theme.line, lineWidth: active ? 1.5 : 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func tagColor(for t: Entry.Tag) -> Color {
        switch t {
        case .special, .food: return theme.rose
        case .outing, .walk:  return theme.sage
        case .home:           return theme.amber
        case .solo:           return theme.inkMuted
        }
    }

    // MARK: - Submit

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        guard canSubmit else { return }
        guard case .signedIn(let uuid) = auth.state else { return }
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "HH:mm"
        timeFormatter.timeZone = .current
        let payload = EntryPayload(
            title: title.trimmingCharacters(in: .whitespaces),
            dateISO: LocalDate.string(from: date),
            time: includeTime ? timeFormatter.string(from: date) : nil,
            location: location.isEmpty ? nil : location,
            proposedBy: proposer,
            who: who.rawValue,
            tag: tag.rawValue,
            isSpecial: memorable,
            notes: nil,
            kaomoji: nil,
            photoCount: 0,
            voiceCount: 0,
            messageCount: 0,
            reflection: nil
        )
        isSubmitting = true
        Task {
            await entryService.add(payload: payload, senderId: uuid)
            isSubmitting = false
            onClose()
        }
    }
}

#Preview {
    let crypto = CryptoService()
    return AddEntryView(onClose: {})
        .environmentObject(EntryService(crypto: crypto))
        .environmentObject(AuthService())
        .environmentObject(UserProfileStore())
        .theme(.jbeam)
}
