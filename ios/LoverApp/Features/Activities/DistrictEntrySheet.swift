import SwiftUI

// v1.1.0 — sheet for journaling a district visit. Single-page form: shows
// the district name + kaomoji, lets the couple type a short reflection,
// and saves to PlayHistoryService.recordDistrict.
//
// Re-visiting a district appends a NEW entry (records all visits, not just
// first). The previous entry is shown above the input as a "last time"
// reminder so the user has context.

struct DistrictEntrySheet: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var playHistory: PlayHistoryService
    @EnvironmentObject private var auth: AuthService

    let district: District
    let latestEntry: PlayHistoryService.DecryptedItem?
    let onClose: () -> Void

    @State private var reflection: String = ""
    @State private var isSubmitting: Bool = false
    @State private var coverData: Data? = nil
    @State private var showPicker = false
    @State private var showCamera = false
    @FocusState private var reflectionFocused: Bool

    private var tintColor: Color {
        switch district.tint {
        case .rose:  return theme.rose
        case .sage:  return theme.sage
        case .amber: return theme.amber
        }
    }
    private var tintSoft: Color {
        switch district.tint {
        case .rose:  return theme.roseSoft
        case .sage:  return theme.sageSoft
        case .amber: return theme.amberSoft
        }
    }

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
            Text(district.region.rawValue + " · " + district.name)
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
                          prompt: Text("一兩句記住今日 — 邊度／食咗乜／乜嘢心情")
                            .foregroundColor(theme.inkSoft),
                          axis: .vertical)
                    .font(DSText.ui(theme, 15))
                    .foregroundStyle(theme.ink)
                    .lineLimit(3...8)
                    .focused($reflectionFocused)
                    .padding(14)
            }

            section(title: "封面相片 (可以唔加)") {
                photoPickerRow.padding(14)
            }
        }
    }

    // MARK: - Photo picker (v1.4.0)

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
                Button { coverData = nil } label: {
                    Text("移除張相")
                        .font(DSText.mono(theme, 11))
                        .foregroundStyle(theme.rose)
                }
                .buttonStyle(.plain)
            }
        } else {
            HStack(spacing: 10) {
                Button { showCamera = true } label: { pickerButton(icon: .cam, label: "影相") }
                    .buttonStyle(.plain)
                Button { showPicker = true } label: { pickerButton(icon: .image, label: "由相簿揀") }
                    .buttonStyle(.plain)
            }
            .sheet(isPresented: $showPicker) {
                PhotoPickerSheet(
                    onPick: { d in showPicker = false; coverData = d },
                    onCancel: { showPicker = false }
                )
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraSheet(
                    onPick: { d in showCamera = false; coverData = d },
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

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(district.kaomoji)
                .font(.system(size: 36, weight: .regular, design: .monospaced))
                .foregroundStyle(tintColor)
            Text(district.name)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
            Text(district.region.rawValue)
                .font(DSText.mono(theme, 11))
                .foregroundStyle(theme.inkMuted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(tintSoft)
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

    // MARK: - Actions

    private var canSubmit: Bool {
        !reflection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func submit() {
        guard canSubmit else { return }
        guard case .signedIn(let uuid) = auth.state else { return }
        let text = reflection.trimmingCharacters(in: .whitespacesAndNewlines)
        let code = district.id
        let cover = coverData
        isSubmitting = true
        Task {
            await playHistory.recordDistrict(
                code: code, reflection: text,
                coverData: cover, senderId: uuid)
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

#Preview {
    let crypto = CryptoService()
    return DistrictEntrySheet(
        district: District.all[0],
        latestEntry: nil,
        onClose: {}
    )
    .environmentObject(PlayHistoryService(crypto: crypto))
    .environmentObject(AuthService())
    .theme(.jbeam)
}
