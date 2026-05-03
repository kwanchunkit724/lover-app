import SwiftUI

// First-launch flow. Five steps:
//   1. welcome      — kawaii intro + start button
//   2. yourName     — text field for self
//   3. partnerName  — text field for partner
//   4. anniversary  — date picker for "一齊嘅日子"
//   5. theme        — pick from the 3 themes
// On finish, writes UserProfile to UserProfileStore and the app falls through
// to MainTabView. No backend yet — Phase 3 will sync this to Supabase and add
// the partner-side anniversary cross-check during pairing.

struct OnboardingView: View {
    @EnvironmentObject private var profileStore: UserProfileStore

    @State private var step: Step = .welcome
    @State private var myName: String = ""
    @State private var partnerName: String = ""
    @State private var anniversary: Date = Date()
    @State private var themeId: String = "jbeam"

    enum Step: Int, CaseIterable {
        case welcome, yourName, partnerName, anniversary, theme
    }

    /// Live theme reflecting the user's current selection in the theme step,
    /// so picking "深夜暖色" recolors the entire onboarding flow immediately
    /// instead of only after profile save.
    private var theme: Theme {
        switch themeId {
        case "notion": return .notion
        case "cozy":   return .cozy
        default:       return .jbeam
        }
    }

    var body: some View {
        content
            .theme(theme)
    }

    private var content: some View {
        ZStack {
            theme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                progressBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

                Spacer(minLength: 0)

                Group {
                    switch step {
                    case .welcome:     welcomeStep
                    case .yourName:    nameStep(title: "你叫咩名？", placeholder: "名/暱稱", text: $myName)
                    case .partnerName: nameStep(title: "對方叫咩名？", placeholder: "TA 嘅名/暱稱", text: $partnerName)
                    case .anniversary: anniversaryStep
                    case .theme:       themeStep
                    }
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal:   .move(edge: .leading).combined(with: .opacity)
                ))

                Spacer(minLength: 0)

                bottomBar
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .animation(.easeInOut(duration: 0.28), value: step)
    }

    // MARK: - Steps

    private var welcomeStep: some View {
        VStack(spacing: 18) {
            Text("(♡˙︶˙♡)")
                .font(.system(size: 56, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.rose)
            Text("Us")
                .font(.system(size: 44, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
            Text("我哋兩個人嘅小天地")
                .font(DSText.ui(theme, 16))
                .foregroundStyle(theme.inkSoft)
                .padding(.top, 4)
            Text("先設定下基本資料\n之後再同對方配對")
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.inkMuted)
                .multilineTextAlignment(.center)
                .padding(.top, 16)
        }
        .padding(.horizontal, 24)
    }

    private func nameStep(title: String, placeholder: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Text(title)
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)

            DSTextField(placeholder: placeholder, text: text)
                .submitLabel(.next)
                .onSubmit { advanceIfPossible() }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var anniversaryStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("一齊咗幾耐？")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
            Text("揀返開始拍拖嗰日。\n配對嗰陣兩個人輸入嘅日期要一樣，先至成功配對。")
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.inkMuted)

            DatePicker("", selection: $anniversary, in: ...Date(), displayedComponents: .date)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)
                .frame(height: 200)              // wheel collapses to 0 without an explicit height
                .colorScheme(theme.isDark ? .dark : .light)  // wheel text follows theme
                .background(theme.surface)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(theme.line, lineWidth: 0.5)
                )
                .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var themeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("揀個主題")
                .font(.system(size: 28, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
            Text("之後可以喺設定度轉。")
                .font(DSText.ui(theme, 13))
                .foregroundStyle(theme.inkMuted)

            VStack(spacing: 10) {
                ForEach(Theme.allThemes, id: \.id) { t in
                    ThemeOptionCard(theme: t, isSelected: themeId == t.id) {
                        themeId = t.id
                    }
                }
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Progress + bottom bar

    private var progressBar: some View {
        HStack(spacing: 6) {
            ForEach(Step.allCases, id: \.rawValue) { s in
                Capsule()
                    .fill(s.rawValue <= step.rawValue ? theme.rose : theme.line)
                    .frame(height: 3)
            }
        }
    }

    private var bottomBar: some View {
        HStack(spacing: 12) {
            if step != .welcome {
                Button(action: back) {
                    Text("返")
                        .font(DSText.ui(theme, 16, weight: .medium))
                        .foregroundStyle(theme.inkSoft)
                        .frame(width: 64, height: 52)
                        .background(theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(theme.line, lineWidth: 0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                }
            }
            Button(action: advanceIfPossible) {
                Text(step == .theme ? "完成" : "繼續")
                    .font(DSText.ui(theme, 16, weight: .medium))
                    .foregroundStyle(canAdvance ? Color.white : theme.inkMuted)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(canAdvance ? theme.rose : theme.line)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .disabled(!canAdvance)
        }
    }

    // MARK: - Logic

    private var canAdvance: Bool {
        switch step {
        case .welcome:     return true
        case .yourName:    return !myName.trimmingCharacters(in: .whitespaces).isEmpty
        case .partnerName: return !partnerName.trimmingCharacters(in: .whitespaces).isEmpty
        case .anniversary: return true
        case .theme:       return true
        }
    }

    private func advanceIfPossible() {
        guard canAdvance else { return }
        if let next = Step(rawValue: step.rawValue + 1) {
            step = next
        } else {
            finish()
        }
    }

    private func back() {
        if let prev = Step(rawValue: step.rawValue - 1) {
            step = prev
        }
    }

    private func finish() {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withFullDate]
        let profile = UserProfile(
            myName: myName.trimmingCharacters(in: .whitespaces),
            partnerName: partnerName.trimmingCharacters(in: .whitespaces),
            anniversaryISO: isoFormatter.string(from: anniversary),
            themeId: themeId,
            completedAt: Date()
        )
        profileStore.save(profile)
    }
}

// MARK: - Helpers

private struct DSTextField: View {
    @Environment(\.theme) private var theme
    let placeholder: String
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: $text)
            .font(DSText.ui(theme, 18))
            .foregroundStyle(theme.ink)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }
}

private struct ThemeOptionCard: View {
    @Environment(\.theme) private var currentTheme
    let theme: Theme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(theme.paper)
                    Circle().fill(theme.rose).frame(width: 16, height: 16).offset(x: -6, y: -2)
                    Circle().fill(theme.sage).frame(width: 14, height: 14).offset(x: 6, y: 4)
                }
                .frame(width: 38, height: 38)
                .overlay(Circle().stroke(currentTheme.line, lineWidth: 0.5))

                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.name)
                        .font(DSText.ui(currentTheme, 15, weight: .medium))
                        .foregroundStyle(currentTheme.ink)
                    Text(theme.isDark ? "深色" : "淺色")
                        .font(DSText.mono(currentTheme, 11))
                        .foregroundStyle(currentTheme.inkMuted)
                }
                Spacer()
                if isSelected {
                    Text("✓")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(currentTheme.rose)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(currentTheme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? currentTheme.rose : currentTheme.line,
                            lineWidth: isSelected ? 1.5 : 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(UserProfileStore())
        .theme(.jbeam)
}
