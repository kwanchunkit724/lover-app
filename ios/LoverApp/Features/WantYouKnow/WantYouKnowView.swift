import SwiftUI

struct WantYouKnowView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var kk: KKAppModel

    @State private var selected: WantYouKnowNote?
    @State private var showCreate = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("(´ε｀ )♡")
                            .font(.system(size: 20, design: .monospaced))
                            .foregroundStyle(theme.rose)
                        Text("想你知道")
                            .font(.system(size: 22, weight: .semibold, design: .serif))
                            .foregroundStyle(theme.ink)
                        Text("共享 · 已讀回條 · 雙方刪先消失")
                            .font(DSText.mono(theme, 10))
                            .foregroundStyle(theme.inkMuted)
                    }
                    Spacer()
                    Button { showCreate = true } label: {
                        Text("＋")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundStyle(theme.rose)
                            .frame(width: 40, height: 40)
                            .background(theme.roseSoft, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("新一則")
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)

                if kk.want.visible.isEmpty {
                    VStack(spacing: 10) {
                        Spacer()
                        Text("(´｡• ω •｡`)")
                            .font(.system(size: 40, design: .monospaced))
                            .foregroundStyle(theme.rose)
                        Text("未有想你知道")
                            .font(DSText.ui(theme, 15))
                            .foregroundStyle(theme.inkSoft)
                        Spacer()
                    }
                } else {
                    List {
                        ForEach(kk.want.visible) { note in
                            Button { selected = note } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(note.title.isEmpty ? "無標題" : note.title)
                                        .font(DSText.ui(theme, 15, weight: .semibold))
                                        .foregroundStyle(theme.ink)
                                    Text(note.content)
                                        .font(DSText.ui(theme, 13))
                                        .foregroundStyle(theme.inkSoft)
                                        .lineLimit(2)
                                    HStack(spacing: 8) {
                                        Text(note.readByMe ? "我已讀" : "我未讀")
                                        Text(note.readByPartner ? "對方已讀" : "對方未讀")
                                        if note.deletedByMe { Text("等對方刪") }
                                    }
                                    .font(DSText.mono(theme, 10))
                                    .foregroundStyle(theme.inkMuted)
                                }
                                .padding(.vertical, 4)
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
            .navigationDestination(item: $selected) { note in
                WantDetailView(note: note)
            }
        }
        .task { await kk.want.refreshFromServer() }
        .sheet(isPresented: $showCreate) {
            WantEditorSheet(onClose: { showCreate = false })
                .theme(theme)
        }
    }
}

private struct WantDetailView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var kk: KKAppModel
    @Environment(\.dismiss) private var dismiss
    let note: WantYouKnowNote

    private var live: WantYouKnowNote {
        kk.want.notes.first { $0.id == note.id } ?? note
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text(live.title.isEmpty ? "無標題" : live.title)
                    .font(.system(size: 26, weight: .semibold, design: .serif))
                    .foregroundStyle(theme.ink)
                Text(live.content)
                    .font(DSText.ui(theme, 16))
                    .foregroundStyle(theme.ink)
                if let deadline = live.deadline {
                    Text(deadlineLabel(deadline))
                        .font(DSText.mono(theme, 12))
                        .foregroundStyle(theme.inkSoft)
                    if live.remindAtNineHKT {
                        Text("到期當日 09:00（香港時間）推送一次。推送未接上。")
                            .font(DSText.mono(theme, 11))
                            .foregroundStyle(theme.inkMuted)
                    }
                }
                Text(live.readByMe ? "我已讀" : "我未讀")
                    .font(DSText.ui(theme, 13))
                    .foregroundStyle(theme.inkSoft)
                Text(live.readByPartner ? "對方已讀" : "對方未讀（回條未同步）")
                    .font(DSText.ui(theme, 13))
                    .foregroundStyle(theme.inkSoft)
                if !live.readByMe {
                    Button("標記已讀") { Task { await kk.want.markRead(live.id) } }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.rose)
                }
                if live.deletedByMe {
                    Text("你刪咗。等對方都刪，呢則先會消失。")
                        .font(DSText.ui(theme, 13))
                        .foregroundStyle(theme.inkSoft)
                } else {
                    Button("刪除") { Task { await kk.want.markDeletedByMe(live.id) } }
                        .buttonStyle(.plain)
                        .foregroundStyle(theme.rose)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
        }
        .background(theme.paper.ignoresSafeArea())
        .navigationTitle("想你知道")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if !live.readByMe { Task { await kk.want.markRead(live.id) } }
        }
    }

    private func deadlineLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "zh_Hant_HK")
        f.timeZone = KKTime.zone
        f.dateStyle = .medium
        f.timeStyle = .none
        return "期限 " + f.string(from: date)
    }
}

private struct WantEditorSheet: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var kk: KKAppModel
    let onClose: () -> Void

    @State private var title = ""
    @State private var content = ""
    @State private var hasDeadline = false
    @State private var deadline = Date()
    @State private var remind = true

    var body: some View {
        NavigationStack {
            Form {
                TextField("標題（可選）", text: $title)
                TextField("內容", text: $content, axis: .vertical)
                    .lineLimit(4...10)
                Toggle("期限", isOn: $hasDeadline)
                if hasDeadline {
                    DatePicker("日期", selection: $deadline, displayedComponents: .date)
                    Toggle("到期日 09:00 香港時間提醒", isOn: $remind)
                }
            }
            .scrollContentBackground(.hidden)
            .background(theme.paper)
            .navigationTitle("新一則")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消", action: onClose)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("儲存") {
                        Task {
                            let ok = await kk.want.add(
                                title: title,
                                content: content,
                                deadline: hasDeadline ? deadline : nil,
                                remind: remind
                            )
                            if ok { onClose() }
                        }
                    }
                    .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}
