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
    // v1.6.0 — when non-nil we're in edit mode: prefill all fields and call
    // entryService.update(...) on submit instead of add(...).
    var existing: EntryService.DecryptedEntry? = nil

    @State private var title: String = ""
    @State private var tag: Entry.Tag = .outing
    @State private var who: Entry.Who = .both
    @State private var proposer: String = "kit"
    @State private var memorable: Bool = true
    @State private var date: Date = Date()
    @State private var includeTime: Bool = false
    @State private var location: String = ""
    @State private var isSubmitting: Bool = false
    // v1.2.0 — optional cover photo. Buffered as Data; uploaded + encrypted
    // on submit so the entry becomes a real "memory" once its date passes.
    @State private var coverData: Data? = nil
    // v1.6.0 — when editing, keep the previously-saved encrypted cover
    // handle so we can preserve it if the user doesn't pick a new photo.
    @State private var existingCoverHandle: String? = nil
    @State private var didLoadExisting: Bool = false
    @State private var showPicker: Bool = false
    @State private var showCamera: Bool = false
    @State private var showPickerSource: Bool = false   // chooser sheet

    private let suggestions = ["食飯", "睇戲", "行山", "散步", "煮嘢食", "紀念日"]

    @FocusState private var titleFocused: Bool

    // v1.6.0 — past = photo upload allowed; future = disabled with hint.
    private var isFutureEvent: Bool {
        let startOfToday = Calendar.current.startOfDay(for: Date())
        let startOfPicked = Calendar.current.startOfDay(for: date)
        return startOfPicked > startOfToday
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navBar
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 20)
            }
        }
        .onAppear { loadExistingIfNeeded() }
        // v1.0.4 — without this the keyboard stays parked over the lower
        // sections (標籤 / 邊個 / 記憶簿) so the user can't see / tap them.
        // .interactively lets a downward drag dismiss the keyboard, and the
        // toolbar "完成" gives an explicit dismiss for the title field.
        .scrollDismissesKeyboard(.interactively)
        .background(theme.paper)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { titleFocused = false }
                    .foregroundStyle(theme.rose)
            }
        }
    }

    private var navBar: some View {
        HStack {
            // v1.0.5 — text labels swapped for icons per user request.
            Button { onClose() } label: {
                DSIcon(name: .close, size: 22, color: theme.rose, strokeWidth: 2.2)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(existing == nil ? "新提醒" : "改提醒")
                .font(DSText.ui(theme, 16, weight: .semibold))
                .foregroundStyle(theme.ink)
            Spacer()
            Button(action: submit) {
                if isSubmitting {
                    ProgressView().tint(theme.rose)
                } else {
                    DSIcon(name: .plus, size: 22,
                           color: canSubmit ? theme.rose : theme.inkMuted,
                           strokeWidth: 2.4)
                        .frame(width: 30, height: 30)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isSubmitting)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            // v1.0.5 — placeholder uses inkSoft (not the iOS default very-light
            // gray) so user can actually read what the field is asking for.
            TextField("",
                      text: $title,
                      prompt: Text("想做啲乜？").foregroundColor(theme.inkSoft))
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
                .focused($titleFocused)
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
                        TextField("",
                                  text: $location,
                                  prompt: Text("地點 (可以唔填)").foregroundColor(theme.inkSoft))
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

            // v1.2.0 — optional cover photo. Past entries with a cover
            // render as a real-photo memory cell on the calendar instead
            // of the deterministic gradient placeholder.
            // v1.6.0 — disable photo upload for future-dated events; you
            // can come back after the day arrives to add the cover photo.
            section(title: "封面相片 (可以唔加)") {
                if isFutureEvent && coverData == nil && existingCoverHandle == nil {
                    futurePhotoHint
                        .padding(14)
                } else {
                    photoPickerRow
                        .padding(14)
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

    // MARK: - Photo picker (v1.2.0)

    // v1.6.0 — friendly hint when the user picks a future date.
    private var futurePhotoHint: some View {
        VStack(spacing: 8) {
            DSIcon(name: .clock, size: 22, color: theme.inkMuted)
            Text("活動發生後再加相")
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.inkMuted)
            Text("到時返嚟編輯就得")
                .font(DSText.mono(theme, 11))
                .foregroundStyle(theme.inkSoft)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var photoPickerRow: some View {
        if let data = coverData, let ui = UIImage(data: data) {
            VStack(spacing: 10) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Button {
                    coverData = nil
                } label: {
                    Text("移除張相")
                        .font(DSText.mono(theme, 11))
                        .foregroundStyle(theme.rose)
                }
                .buttonStyle(.plain)
            }
        } else if let handle = existingCoverHandle, handle.hasPrefix("couple-") {
            // v1.6.0 — edit mode showing the previously-saved encrypted cover.
            VStack(spacing: 10) {
                EncryptedAsyncImage(mediaHandle: handle, maxHeight: 180, cornerRadius: 12)
                HStack(spacing: 16) {
                    Button { existingCoverHandle = nil } label: {
                        Text("移除張相")
                            .font(DSText.mono(theme, 11))
                            .foregroundStyle(theme.rose)
                    }
                    .buttonStyle(.plain)
                    Button { showPicker = true } label: {
                        Text("換張新相")
                            .font(DSText.mono(theme, 11))
                            .foregroundStyle(theme.rose)
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showPicker) {
                PhotoPickerSheet(
                    onPick: { data in
                        showPicker = false
                        coverData = data
                    },
                    onCancel: { showPicker = false }
                )
            }
        } else {
            HStack(spacing: 10) {
                Button { showCamera = true } label: {
                    pickerButton(icon: .cam, label: "影相")
                }
                .buttonStyle(.plain)
                Button { showPicker = true } label: {
                    pickerButton(icon: .image, label: "由相簿揀")
                }
                .buttonStyle(.plain)
            }
            .sheet(isPresented: $showPicker) {
                PhotoPickerSheet(
                    onPick: { data in
                        showPicker = false
                        coverData = data
                    },
                    onCancel: { showPicker = false }
                )
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraSheet(
                    onPick: { data in
                        showCamera = false
                        coverData = data
                    },
                    onCancel: { showCamera = false }
                )
                .ignoresSafeArea()
            }
        }
    }

    private func pickerButton(icon: DSIconName, label: String) -> some View {
        VStack(spacing: 6) {
            DSIcon(name: icon, size: 22, color: theme.rose)
            Text(label)
                .font(DSText.ui(theme, 12))
                .foregroundStyle(theme.ink)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(theme.paperAlt)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.line, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
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
        // v1.6.0 — preserve previously-saved counts / reflection / cover
        // handle in edit mode; otherwise start a fresh payload.
        let basePhotoCount = existing?.payload.photoCount ?? 0
        let baseVoice = existing?.payload.voiceCount ?? 0
        let baseMsg = existing?.payload.messageCount ?? 0
        let baseReflection = existing?.payload.reflection
        let baseNotes = existing?.payload.notes
        let baseKaomoji = existing?.payload.kaomoji
        var payload = EntryPayload(
            title: title.trimmingCharacters(in: .whitespaces),
            dateISO: LocalDate.string(from: date),
            time: includeTime ? timeFormatter.string(from: date) : nil,
            location: location.isEmpty ? nil : location,
            proposedBy: proposer,
            who: who.rawValue,
            tag: tag.rawValue,
            isSpecial: memorable,
            notes: baseNotes,
            kaomoji: baseKaomoji,
            photoCount: basePhotoCount,
            voiceCount: baseVoice,
            messageCount: baseMsg,
            reflection: baseReflection
        )
        // Preserve existing encrypted cover handle if user didn't pick a new one.
        payload.coverHandle = existingCoverHandle
        isSubmitting = true
        let cover = coverData
        let existingId = existing?.id
        Task {
            if let existingId {
                await entryService.update(id: existingId, payload: payload, coverData: cover)
            } else {
                await entryService.add(payload: payload, coverData: cover, senderId: uuid)
            }
            isSubmitting = false
            onClose()
        }
    }

    // v1.6.0 — populate state from `existing` once when sheet appears.
    private func loadExistingIfNeeded() {
        guard !didLoadExisting, let existing else { didLoadExisting = true; return }
        didLoadExisting = true
        let p = existing.payload
        title = p.title
        if let parsed = TimeFormatting.parseDate(p.dateISO) {
            // Merge in the saved HH:mm if available.
            if let hhmm = p.time {
                let fmt = DateFormatter()
                fmt.dateFormat = "yyyy-MM-dd HH:mm"
                fmt.timeZone = .current
                date = fmt.date(from: "\(p.dateISO) \(hhmm)") ?? parsed
                includeTime = true
            } else {
                date = parsed
                includeTime = false
            }
        }
        location = p.location ?? ""
        proposer = p.proposedBy
        who = Entry.Who(rawValue: p.who) ?? .both
        tag = Entry.Tag(rawValue: p.tag) ?? .outing
        memorable = p.isSpecial
        existingCoverHandle = p.coverHandle
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
