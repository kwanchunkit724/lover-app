import SwiftUI

// Sheet for adding a new shared anniversary. Title + date + recurrence +
// emoji picker. Encrypts via the chat key + inserts into anniversaries
// table; the partner's device picks it up via realtime.

struct AddAnniversaryView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var anniversaryService: AnniversaryService
    @EnvironmentObject private var auth: AuthService

    let onClose: () -> Void

    @State private var title: String = ""
    @State private var date: Date = Date()
    @State private var recur: AnniversaryPayload.Recur = .yearly
    @State private var emoji: String = "♡"
    @State private var isSubmitting = false

    private let emojiOptions = ["♡","☕","🍰","🎂","🏠","🌸","🎉","✈️","🌊","🌙","🍡"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navBar

                VStack(alignment: .leading, spacing: 18) {
                    section(title: "名稱") {
                        TextField("我哋一齊嘅日子", text: $title)
                            .font(DSText.ui(theme, 16))
                            .foregroundStyle(theme.ink)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .background(theme.surface)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(theme.line, lineWidth: 0.5)
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    section(title: "日期") {
                        DatePicker("", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.wheel)
                            .labelsHidden()
                            .frame(maxWidth: .infinity)
                            .frame(height: 180)
                            .colorScheme(theme.isDark ? .dark : .light)
                            .background(theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    section(title: "重覆") {
                        HStack(spacing: 10) {
                            recurChip(.yearly, label: "每年")
                            recurChip(.monthly, label: "每月")
                        }
                    }

                    section(title: "Emoji") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                            ForEach(emojiOptions, id: \.self) { e in
                                Button { emoji = e } label: {
                                    Text(e)
                                        .font(.system(size: 22))
                                        .frame(width: 40, height: 40)
                                        .background(emoji == e ? theme.roseSoft : theme.surface)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                                .stroke(emoji == e ? theme.rose : theme.line,
                                                        lineWidth: emoji == e ? 1.5 : 0.5)
                                        )
                                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    submitButton
                        .padding(.top, 12)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 28)
            }
        }
        .background(theme.paper)
    }

    private var navBar: some View {
        HStack {
            Button(action: onClose) {
                DSIcon(name: .close, size: 22, color: theme.inkSoft, strokeWidth: 2.2).padding(6)
            }
            .buttonStyle(.plain)
            Text("新紀念日")
                .font(DSText.ui(theme, 17, weight: .semibold))
                .foregroundStyle(theme.ink)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .padding(.bottom, 12)
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DSText.mono(theme, 11))
                .foregroundStyle(theme.inkMuted)
                .textCase(.uppercase)
            content()
        }
    }

    private func recurChip(_ value: AnniversaryPayload.Recur, label: String) -> some View {
        let active = recur == value
        return Button { recur = value } label: {
            Text(label)
                .font(DSText.ui(theme, 14, weight: .medium))
                .foregroundStyle(active ? .white : theme.inkSoft)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(active ? theme.rose : theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(active ? theme.rose : theme.line, lineWidth: active ? 1.5 : 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var submitButton: some View {
        Button(action: submit) {
            Group {
                if isSubmitting {
                    ProgressView().tint(.white)
                } else {
                    Text("加入")
                        .font(DSText.ui(theme, 16, weight: .medium))
                }
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(canSubmit ? theme.rose : theme.line)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .disabled(!canSubmit || isSubmitting)
    }

    private var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        guard case .signedIn(let uuid) = auth.state else { return }
        let payload = AnniversaryPayload(
            title: title.trimmingCharacters(in: .whitespaces),
            baseDateISO: LocalDate.string(from: date),
            recur: recur,
            kaomoji: nil,
            emoji: emoji,
            subtitle: nil
        )
        isSubmitting = true
        Task {
            await anniversaryService.add(payload: payload, senderId: uuid)
            isSubmitting = false
            onClose()
        }
    }
}
