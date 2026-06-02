import SwiftUI

// v1.6.5 — shared quick checklist as a COMPACT panel anchored top-right
// (~1/4 of the screen), not a full sheet. Both partners see the same live
// list; tap a row to tick it off, tap the trash to remove.
struct ChecklistSheet: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var checklist: ChecklistService
    let onClose: () -> Void

    @State private var draft = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 6) {
                Text("清單")
                    .font(DSText.ui(theme, 14, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.inkMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .overlay(Rectangle().frame(height: 0.5).foregroundStyle(theme.line), alignment: .bottom)

            // Add row
            HStack(spacing: 6) {
                TextField("買嘢 / 做嘢…", text: $draft)
                    .focused($fieldFocused)
                    .font(DSText.ui(theme, 13))
                    .submitLabel(.done)
                    .onSubmit(addDraft)
                Button(action: addDraft) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(canAdd ? theme.rose : theme.inkMuted)
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            if let err = checklist.lastError {
                Text(err)
                    .font(DSText.mono(theme, 9))
                    .foregroundStyle(theme.rose)
                    .lineLimit(2)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onTapGesture { checklist.lastError = nil }
            }

            // Items
            if checklist.items.isEmpty {
                Text("(っ˕ -｡) 空空如也")
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.inkMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(checklist.items) { item in
                            HStack(spacing: 8) {
                                Button { Task { await checklist.toggle(item) } } label: {
                                    Image(systemName: item.done ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 17))
                                        .foregroundStyle(item.done ? theme.sage : theme.inkMuted)
                                }
                                .buttonStyle(.plain)
                                Text(item.text)
                                    .font(DSText.ui(theme, 13))
                                    .foregroundStyle(item.done ? theme.inkMuted : theme.ink)
                                    .strikethrough(item.done, color: theme.inkMuted)
                                    .lineLimit(2)
                                Spacer(minLength: 4)
                                Button { Task { await checklist.remove(item) } } label: {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundStyle(theme.inkMuted)
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            Rectangle().frame(height: 0.5).foregroundStyle(theme.line.opacity(0.6))
                        }
                    }
                }
                .frame(maxHeight: 240)
            }
        }
        .frame(width: 250)
        .background(theme.nav)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(theme.line, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.18), radius: 16, y: 6)
    }

    private var canAdd: Bool { !draft.trimmingCharacters(in: .whitespaces).isEmpty }

    private func addDraft() {
        let t = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !t.isEmpty else { return }
        draft = ""
        Task { await checklist.add(t) }
    }
}
