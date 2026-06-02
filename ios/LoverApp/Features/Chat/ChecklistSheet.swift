import SwiftUI

// v1.6.5 — shared quick checklist sheet (to buy / to do). Both partners see
// the same live list; tap to tick off, swipe/✕ to remove.
struct ChecklistSheet: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var checklist: ChecklistService

    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("清單")
                    .font(DSText.ui(theme, 18, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("（買嘢 / 做嘢）")
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.inkMuted)
                Spacer()
                Button("完成") { dismiss() }
                    .font(DSText.ui(theme, 14, weight: .semibold))
                    .foregroundStyle(theme.rose)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .overlay(Rectangle().frame(height: 0.5).foregroundStyle(theme.line), alignment: .bottom)

            // Add field
            HStack(spacing: 10) {
                TextField("加一樣嘢…（例如：買牛奶）", text: $draft)
                    .focused($fieldFocused)
                    .font(DSText.ui(theme, 15))
                    .submitLabel(.done)
                    .onSubmit(addDraft)
                Button(action: addDraft) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(draft.trimmingCharacters(in: .whitespaces).isEmpty
                                         ? theme.inkMuted : theme.rose)
                }
                .buttonStyle(.plain)
                .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if checklist.items.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Text("(っ˕ -｡)").font(DSText.mono(theme, 22)).foregroundStyle(theme.rose)
                    Text("清單空空如也").font(DSText.ui(theme, 13)).foregroundStyle(theme.inkMuted)
                }
                Spacer()
            } else {
                List {
                    ForEach(checklist.items) { item in
                        Button { Task { await checklist.toggle(item) } } label: {
                            HStack(spacing: 12) {
                                Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(item.done ? theme.sage : theme.inkMuted)
                                Text(item.text)
                                    .font(DSText.ui(theme, 15))
                                    .foregroundStyle(item.done ? theme.inkMuted : theme.ink)
                                    .strikethrough(item.done, color: theme.inkMuted)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(theme.surface)
                        .swipeActions {
                            Button(role: .destructive) {
                                Task { await checklist.remove(item) }
                            } label: { Label("刪除", systemImage: "trash") }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)

                if checklist.items.contains(where: { $0.done }) {
                    Button { Task { await checklist.clearDone() } } label: {
                        Text("清除已完成")
                            .font(DSText.mono(theme, 12))
                            .foregroundStyle(theme.inkMuted)
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 10)
                }
            }
        }
        .background(theme.paper.ignoresSafeArea())
    }

    private func addDraft() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        draft = ""
        Task { await checklist.add(t) }
    }
}
