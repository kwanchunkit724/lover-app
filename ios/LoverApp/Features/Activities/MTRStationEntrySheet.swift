import SwiftUI

// v1.3.0 — sheet for journaling an MTR station visit. Mirrors
// DistrictEntrySheet but tinted to the line's official MTR brand color.

struct MTRStationEntrySheet: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var playHistory: PlayHistoryService
    @EnvironmentObject private var auth: AuthService

    let station: MTRStation
    let latestEntry: PlayHistoryService.DecryptedItem?
    let onClose: () -> Void

    @State private var reflection: String = ""
    @State private var isSubmitting: Bool = false
    @FocusState private var reflectionFocused: Bool

    private var lineColor: Color { Color(hex: station.line.colorHex) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                navBar
                content
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .padding(.bottom, 30)
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .background(theme.paper)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("完成") { reflectionFocused = false }
                    .foregroundStyle(theme.rose)
            }
        }
    }

    private var navBar: some View {
        HStack {
            Button { onClose() } label: {
                DSIcon(name: .close, size: 22, color: theme.rose, strokeWidth: 2.2)
                    .frame(width: 30, height: 30)
            }
            .buttonStyle(.plain)
            Spacer()
            Text(station.line.rawValue + " · " + station.name)
                .font(DSText.ui(theme, 16, weight: .semibold))
                .foregroundStyle(theme.ink)
            Spacer()
            Button(action: submit) {
                if isSubmitting {
                    ProgressView().tint(theme.rose)
                } else {
                    Text("記低")
                        .font(DSText.ui(theme, 15, weight: .semibold))
                        .foregroundStyle(canSubmit ? theme.rose : theme.inkMuted)
                }
            }
            .buttonStyle(.plain)
            .disabled(!canSubmit || isSubmitting)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 22) {
            heroCard

            if let prev = latestEntry, let prevText = prev.payload.text, !prevText.isEmpty {
                lastVisitCard(text: prevText, at: prev.createdAt)
            }

            section(title: "今次嘅日記") {
                TextField("",
                          text: $reflection,
                          prompt: Text("一兩句記住今日 — 邊個出口／食咗乜／影咗乜")
                            .foregroundColor(theme.inkSoft),
                          axis: .vertical)
                    .font(DSText.ui(theme, 15))
                    .foregroundStyle(theme.ink)
                    .lineLimit(3...8)
                    .focused($reflectionFocused)
                    .padding(14)
            }
        }
    }

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Capsule().fill(lineColor).frame(width: 18, height: 4)
                Text(station.line.rawValue)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
            }
            Text(station.name)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(.white)
            Text(station.id)
                .font(DSText.mono(theme, 11))
                .foregroundStyle(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(lineColor)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func lastVisitCard(text: String, at date: Date) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("上次去 · " + relativeDate(date))
                .font(DSText.mono(theme, 10).weight(.semibold))
                .foregroundStyle(theme.rose)
            Text(text)
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.inkSoft)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.paperAlt)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(theme.line, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func section<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .regular, design: .monospaced))
                .foregroundStyle(theme.inkMuted)
                .textCase(.uppercase)
                .padding(.leading, 4)
            content()
                .background(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.line, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private var canSubmit: Bool {
        !reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canSubmit else { return }
        guard case .signedIn(let uuid) = auth.state else { return }
        let text = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = station.id
        isSubmitting = true
        Task {
            await playHistory.recordMtrStation(code: code, reflection: text, senderId: uuid)
            await MainActor.run {
                isSubmitting = false
                onClose()
            }
        }
    }

    private func relativeDate(_ d: Date) -> String {
        let f = RelativeDateTimeFormatter()
        f.unitsStyle = .short
        f.locale = Locale(identifier: "zh-Hant")
        return f.localizedString(for: d, relativeTo: Date())
    }
}
