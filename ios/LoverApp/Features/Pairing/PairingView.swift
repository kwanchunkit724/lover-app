import SwiftUI

// Three-mode pairing surface, shown when the user is signed in but has no
// couple row in the backend. Modes:
//
//   .choose   — two big options: "我嚟生成配對碼" / "對方畀咗我配對碼"
//   .generate — server-issued 6-digit code with countdown
//   .enter    — numeric keypad for entering partner's code +
//               anniversary date picker (cross-checked server-side)

struct PairingView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var pairing: PairingService

    enum Mode: Equatable { case choose, generate, enter }

    @State private var mode: Mode = .choose
    @State private var enteredCode: String = ""
    @State private var enteredAnniversary: Date = Date()
    @State private var showAnniversaryPicker: Bool = false
    @State private var now: Date = Date()

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                ScrollView {
                    VStack(spacing: 0) {
                        switch mode {
                        case .choose:   chooseMode
                        case .generate: generateMode
                        case .enter:    enterMode
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 28)
                }
            }
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { d in
            now = d
        }
    }

    // MARK: - Top bar (back + sign out)

    private var topBar: some View {
        HStack {
            if mode != .choose {
                Button(action: backToChoose) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                        Text("返")
                            .font(DSText.ui(theme, 14, weight: .medium))
                    }
                    .foregroundStyle(theme.inkSoft)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
            }
            Spacer()
            Button { Task { await auth.signOut() } } label: {
                Text("登出")
                    .font(DSText.mono(theme, 12))
                    .foregroundStyle(theme.inkMuted)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Choose mode

    private var chooseMode: some View {
        VStack(spacing: 18) {
            Text("(´｡• ᵕ •｡`)")
                .font(.system(size: 44, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.rose)
                .padding(.top, 12)
            Text("配對")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
            Text("揀其中一個方法 —\n兩部手機要輸入同一個紀念日先成功")
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.bottom, 12)

            choiceCard(
                icon: "qrcode",
                title: "我嚟生成配對碼",
                subtitle: "佢會見到一個 6 位數字，我講畀 TA 聽",
                action: { mode = .generate; Task { await pairing.createCode() } }
            )

            choiceCard(
                icon: "keyboard",
                title: "對方畀咗我配對碼",
                subtitle: "輸入 TA 個 6 位數字 + 紀念日",
                action: { mode = .enter }
            )

            if let err = pairing.lastError {
                Text(err)
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.rose)
                    .multilineTextAlignment(.center)
                    .padding(.top, 16)
            }
        }
    }

    private func choiceCard(icon: String, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundStyle(theme.rose)
                    .frame(width: 44, height: 44)
                    .background(theme.roseSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(DSText.ui(theme, 16, weight: .medium))
                        .foregroundStyle(theme.ink)
                    Text(subtitle)
                        .font(DSText.ui(theme, 12))
                        .foregroundStyle(theme.inkSoft)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.inkMuted)
            }
            .padding(16)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Generate mode (phone A)

    private var generateMode: some View {
        VStack(spacing: 18) {
            Text("講畀對方聽")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
                .padding(.top, 12)
            Text("TA 喺自己手機輸入呢個 code +\n你哋共同嘅紀念日。")
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.inkSoft)
                .multilineTextAlignment(.center)
                .padding(.bottom, 8)

            if pairing.isLoading && pairing.activeCode == nil {
                ProgressView()
                    .padding(.vertical, 60)
            } else if let active = pairing.activeCode {
                codeDisplay(active.code)
                expiryRow(active.expiresAt)
            } else if let err = pairing.lastError {
                Text(err)
                    .font(DSText.mono(theme, 12))
                    .foregroundStyle(theme.rose)
                    .multilineTextAlignment(.center)
            }

            // Display the anniversary the partner needs to enter — this is
            // the value the server stored from your onboarding profile and
            // will compare against. Without this, you wouldn't know exactly
            // which date to tell them.
            if let annivISO = profileStore.profile?.anniversaryISO {
                VStack(spacing: 6) {
                    Text("對方要輸入嘅紀念日")
                        .font(DSText.mono(theme, 11))
                        .foregroundStyle(theme.inkMuted)
                    Text(DisplayDate.from(iso: annivISO))
                        .font(.system(size: 18, weight: .semibold, design: .monospaced))
                        .foregroundStyle(theme.ink)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .padding(.horizontal, 16)
                .background(theme.sageSoft)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .padding(.top, 4)
            }

            Button { Task { await pairing.createCode() } } label: {
                Text("換一個 code")
                    .font(DSText.ui(theme, 14, weight: .medium))
                    .foregroundStyle(theme.rose)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.rose.opacity(0.4), lineWidth: 1)
                    )
            }
            .padding(.top, 8)
        }
    }

    private func codeDisplay(_ code: String) -> some View {
        HStack(spacing: 8) {
            ForEach(Array(code), id: \.self) { ch in
                Text(String(ch))
                    .font(.system(size: 38, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.ink)
                    .frame(width: 44, height: 60)
                    .background(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(theme.line, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .padding(.vertical, 12)
    }

    private func expiryRow(_ expiresAt: Date) -> some View {
        let remaining = max(0, Int(expiresAt.timeIntervalSince(now)))
        let m = remaining / 60
        let s = remaining % 60
        return Text(remaining > 0 ? "仲有 \(m):\(String(format: "%02d", s)) 過期" : "已過期 — 換一個")
            .font(DSText.mono(theme, 12))
            .foregroundStyle(remaining > 0 ? theme.inkMuted : theme.rose)
    }

    // MARK: - Enter mode (phone B)

    private var enterMode: some View {
        VStack(spacing: 16) {
            Text("輸入 code")
                .font(.system(size: 24, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
                .padding(.top, 12)

            digitsRow

            Text("紀念日")
                .font(DSText.mono(theme, 12))
                .foregroundStyle(theme.inkMuted)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 12)

            Button { showAnniversaryPicker.toggle() } label: {
                HStack {
                    Text(formattedAnniversary)
                        .font(DSText.ui(theme, 16))
                        .foregroundStyle(theme.ink)
                    Spacer()
                    Image(systemName: "calendar")
                        .foregroundStyle(theme.inkMuted)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .background(theme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(theme.line, lineWidth: 0.5)
                )
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)

            if showAnniversaryPicker {
                DatePicker("", selection: $enteredAnniversary, in: ...Date(), displayedComponents: .date)
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .colorScheme(theme.isDark ? .dark : .light)
                    .background(theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }

            if let err = pairing.lastError {
                Text(err)
                    .font(DSText.mono(theme, 12))
                    .foregroundStyle(theme.rose)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            Button(action: submitRedemption) {
                Group {
                    if pairing.isLoading {
                        ProgressView().tint(.white)
                    } else {
                        Text("配對")
                            .font(DSText.ui(theme, 16, weight: .medium))
                    }
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(canSubmit ? theme.rose : theme.line)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!canSubmit || pairing.isLoading)
            .padding(.top, 8)
        }
    }

    private var digitsRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<6) { idx in
                let ch: String = idx < enteredCode.count
                    ? String(enteredCode[enteredCode.index(enteredCode.startIndex, offsetBy: idx)])
                    : ""
                Text(ch)
                    .font(.system(size: 28, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.ink)
                    .frame(width: 40, height: 54)
                    .background(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(idx == enteredCode.count ? theme.rose : theme.line, lineWidth: idx == enteredCode.count ? 1.5 : 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
        }
        .background(
            // Hidden TextField focuses the keyboard onto the row.
            TextField("", text: Binding(
                get: { enteredCode },
                set: { v in enteredCode = String(v.filter(\.isNumber).prefix(6)) }
            ))
            .keyboardType(.numberPad)
            .focused($codeFieldFocused)
            .opacity(0.001)
        )
        .onTapGesture { codeFieldFocused = true }
        .onAppear { codeFieldFocused = true }
    }

    @FocusState private var codeFieldFocused: Bool

    private var formattedAnniversary: String {
        DisplayDate.formatter.string(from: enteredAnniversary)
    }

    private var canSubmit: Bool { enteredCode.count == 6 }

    private func submitRedemption() {
        guard case let .signedIn(meId) = auth.state else { return }
        Task {
            let ok = await pairing.redeem(code: enteredCode, anniversary: enteredAnniversary, meId: meId)
            if ok {
                // Refresh state — RootView will swap to MainTabView automatically.
                enteredCode = ""
            }
        }
    }

    // MARK: - Navigation

    private func backToChoose() {
        mode = .choose
        pairing.lastError = nil
        pairing.clearActiveCode()
        enteredCode = ""
    }
}

#Preview {
    PairingView()
        .environmentObject(UserProfileStore())
        .environmentObject(AuthService())
        .environmentObject(PairingService())
        .theme(.jbeam)
}
