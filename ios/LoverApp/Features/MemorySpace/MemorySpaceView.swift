import SwiftUI

struct MemorySpaceView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var kk: KKAppModel

    @State private var filter: MemoryCategory?
    @State private var selected: MemoryItem?
    @State private var showCreate = false

    private var filtered: [MemoryItem] {
        guard let filter else { return kk.memory.items }
        return kk.memory.items.filter { $0.category == filter }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                header
                filterRow
                if filtered.isEmpty {
                    empty
                } else {
                    List {
                        ForEach(filtered) { item in
                            Button { selected = item } label: {
                                MemoryRow(item: item)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(theme.paper)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .background(theme.paper.ignoresSafeArea())
            .navigationDestination(item: $selected) { item in
                MemoryDetailView(item: item)
            }
        }
        .sheet(isPresented: $showCreate) {
            MemoryEditorSheet(onClose: {
                showCreate = false
                if kk.memory.draft?.editingId == nil {
                    kk.memory.draft = nil
                }
            })
            .theme(theme)
        }
        .task { await kk.memory.refreshFromServer() }
        .onAppear { presentDraftIfNeeded() }
        .onChange(of: draftToken) { _, _ in presentDraftIfNeeded() }
    }

    /// String so `onChange` does not have to infer an optional generic.
    private var draftToken: String {
        guard let draft = kk.memory.draft, draft.editingId == nil else { return "" }
        return draft.sourceMessageIds.joined(separator: "\n") + "\n" + draft.originalText
    }

    private func presentDraftIfNeeded() {
        if let draft = kk.memory.draft, draft.editingId == nil {
            showCreate = true
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("(´∀｀)♡")
                    .font(.system(size: 20, design: .monospaced))
                    .foregroundStyle(theme.rose)
                Text("記憶空間")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.ink)
                Text(kk.memory.lastError ?? "共享")
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.inkMuted)
            }
            Spacer()
            Button {
                kk.memory.draft = MemoryDraft()
                showCreate = true
            } label: {
                Text("＋")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(theme.rose)
                    .frame(width: 40, height: 40)
                    .background(theme.roseSoft, in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("手寫新記憶")
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                DSChip(label: "全部", active: filter == nil, color: theme.rose) { filter = nil }
                ForEach(MemoryCategory.allCases) { cat in
                    DSChip(label: cat.label, active: filter == cat, color: theme.rose) {
                        filter = cat
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Spacer()
            Text("(´｡• ω •｡`)")
                .font(.system(size: 40, design: .monospaced))
                .foregroundStyle(theme.rose)
            Text("未有記憶")
                .font(DSText.ui(theme, 15))
                .foregroundStyle(theme.inkSoft)
            Button {
                kk.aiRequest = AIExpandRequest(userText: "", memoryItemIds: [])
            } label: {
                Text("(´∀｀)♡  手打提議")
                    .font(DSText.ui(theme, 14, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(theme.rose)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

private struct MemoryRow: View {
    @Environment(\.theme) private var theme
    let item: MemoryItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.title.isEmpty ? "未命名" : item.title)
                    .font(DSText.ui(theme, 15, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Text(item.category.label)
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.rose)
            }
            Text(item.originalText.isEmpty ? item.noteSummary : item.originalText)
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.inkSoft)
                .lineLimit(2)
            if !item.attachmentMarkers.isEmpty || !item.photoThumbMarkers.isEmpty {
                Text((item.photoThumbMarkers + item.attachmentMarkers).joined(separator: " · "))
                    .font(DSText.mono(theme, 10))
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .padding(.vertical, 4)
    }
}

struct MemoryDetailView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var kk: KKAppModel
    @Environment(\.dismiss) private var dismiss

    let item: MemoryItem

    private var live: MemoryItem {
        kk.memory.items.first { $0.id == item.id } ?? item
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text(live.category.label)
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.rose)
                Text(live.title.isEmpty ? "未命名" : live.title)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.ink)
                labeled("原話", live.originalText.isEmpty ? "—" : live.originalText)
                labeled("備註 / 計劃", live.noteSummary.isEmpty ? "—" : live.noteSummary)
                if !live.photoThumbMarkers.isEmpty {
                    Text("相片縮圖（記憶副本，唔係聊天密文）")
                        .font(DSText.mono(theme, 11))
                        .foregroundStyle(theme.inkMuted)
                    HStack {
                        ForEach(Array(live.photoThumbMarkers.enumerated()), id: \.offset) { _, marker in
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(theme.paperAlt)
                                .frame(width: 72, height: 72)
                                .overlay(Text(marker).font(DSText.mono(theme, 9)).foregroundStyle(theme.inkSoft))
                        }
                    }
                }
                if !live.attachmentMarkers.isEmpty {
                    labeled("附件", live.attachmentMarkers.joined(separator: "、"))
                }
                if !live.sourceMessageIds.isEmpty {
                    labeled("來源訊息", "\(live.sourceMessageIds.count) 則 · 48 小時後清引用")
                }
                Text("共享")
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.sage)

                Button {
                    kk.aiRequest = AIExpandRequest(userText: "", memoryItemIds: [])
                } label: {
                    entryLabel("手打提議")
                }
                .buttonStyle(.plain)

                Button {
                    kk.aiRequest = AIExpandRequest(
                        userText: live.originalText,
                        memoryItemIds: [live.id]
                    )
                } label: {
                    entryLabel("跟原話搵計劃")
                }
                .buttonStyle(.plain)

                Button {
                    kk.memory.beginEdit(live)
                } label: {
                    entryLabel("編輯")
                }
                .buttonStyle(.plain)

                Button(role: .destructive) {
                    Task {
                        await kk.memory.delete(live.id)
                        dismiss()
                    }
                } label: {
                    Text("刪除")
                        .font(DSText.ui(theme, 15))
                        .foregroundStyle(theme.rose)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
            }
            .padding(20)
        }
        .background(theme.paper.ignoresSafeArea())
        .navigationTitle("記憶")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: Binding(
            get: { kk.memory.draft?.editingId == live.id },
            set: { if !$0 { kk.memory.draft = nil } }
        )) {
            MemoryEditorSheet(onClose: { kk.memory.draft = nil })
                .theme(theme)
        }
    }

    private func labeled(_ title: String, _ body: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(DSText.mono(theme, 11))
                .foregroundStyle(theme.inkMuted)
            Text(body)
                .font(DSText.ui(theme, 15))
                .foregroundStyle(theme.ink)
        }
    }

    private func entryLabel(_ title: String) -> some View {
        Text(title)
            .font(DSText.ui(theme, 15, weight: .medium))
            .foregroundStyle(theme.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(theme.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

struct MemoryEditorSheet: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var kk: KKAppModel
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            Form {
                TextField("標題", text: title)
                TextField("原話", text: original, axis: .vertical)
                    .lineLimit(3...8)
                Picker("分類", selection: category) {
                    ForEach(MemoryCategory.allCases) { cat in
                        Text(cat.label).tag(cat)
                    }
                }
                TextField("備註 / 計劃", text: note, axis: .vertical)
                    .lineLimit(2...6)
                Toggle("提醒", isOn: remindOn)
                if remindOn.wrappedValue {
                    DatePicker("時間", selection: reminderDate, displayedComponents: [.date, .hourAndMinute])
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.paper)
            .navigationTitle(kk.memory.draft?.editingId == nil ? "新記憶" : "編輯記憶")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        Task {
                            if await kk.memory.saveDraft() { onClose() }
                        }
                    }
                }
            }
        }
    }

    private var title: Binding<String> {
        Binding(get: { kk.memory.draft?.title ?? "" }, set: { kk.memory.draft?.title = $0 })
    }
    private var original: Binding<String> {
        Binding(get: { kk.memory.draft?.originalText ?? "" }, set: { kk.memory.draft?.originalText = $0 })
    }
    private var note: Binding<String> {
        Binding(get: { kk.memory.draft?.noteSummary ?? "" }, set: { kk.memory.draft?.noteSummary = $0 })
    }
    private var category: Binding<MemoryCategory> {
        Binding(get: { kk.memory.draft?.category ?? .daily }, set: { kk.memory.draft?.category = $0 })
    }
    private var remindOn: Binding<Bool> {
        Binding(
            get: { kk.memory.draft?.reminderAt != nil },
            set: { on in
                kk.memory.draft?.reminderAt = on ? (kk.memory.draft?.reminderAt ?? Date().addingTimeInterval(3600)) : nil
            }
        )
    }
    private var reminderDate: Binding<Date> {
        Binding(
            get: { kk.memory.draft?.reminderAt ?? Date() },
            set: { kk.memory.draft?.reminderAt = $0 }
        )
    }
}
