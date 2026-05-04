import SwiftUI

// 21 條問題 — async-reveal quiz. Each partner writes their answer privately;
// when both answer the same question, the answers reveal side-by-side with
// a 心有靈犀 badge if they match.
//
// State machine per question:
//   nobody answered    → input field for me + "等緊兩邊都答"
//   only I answered    → my answer hidden, "等緊對方"
//   only partner did   → input field for me + "對方已答 ✓"
//   both answered      → reveal both answers + match badge if equal
//
// Stored in play_history with kind=.quizAnswer + questionId + text. Both
// sides see the partner's answer the moment realtime fires the insert.

struct QuizView: View {
    @Environment(\.theme) private var theme
    @EnvironmentObject private var playHistory: PlayHistoryService
    @EnvironmentObject private var auth: AuthService
    @EnvironmentObject private var profileStore: UserProfileStore
    @EnvironmentObject private var pairing: PairingService

    let onClose: () -> Void

    @State private var step: Int = 0
    @State private var draft: String = ""
    @State private var isSubmitting: Bool = false

    private var questions: [QuizQuestion] { MockData.quizQuestions }
    private var question: QuizQuestion { questions[step % questions.count] }

    private var meId: UUID? {
        if case .signedIn(let id) = auth.state { return id }
        return nil
    }
    private var partnerId: UUID? { pairing.partner?.id }

    /// My answer for the current question, if I've answered it.
    private var myAnswer: String? {
        guard let meId else { return nil }
        return playHistory.items.first {
            $0.payload.kind == .quizAnswer
            && $0.payload.questionId == question.id
            && $0.senderId == meId
        }?.payload.text
    }

    /// Partner's answer for the current question, if they've answered it.
    private var partnerAnswer: String? {
        guard let partnerId else { return nil }
        return playHistory.items.first {
            $0.payload.kind == .quizAnswer
            && $0.payload.questionId == question.id
            && $0.senderId == partnerId
        }?.payload.text
    }

    private var bothAnswered: Bool { myAnswer != nil && partnerAnswer != nil }

    /// Light normalization so "Kit Kat" and "kit kat" match.
    private var matched: Bool {
        guard let m = myAnswer, let p = partnerAnswer else { return false }
        let normalize: (String) -> String = {
            $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        return normalize(m) == normalize(p)
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            progressBar
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            actionRow
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .padding(.bottom, 10)
        }
        .background(theme.paper)
        .onChange(of: step) { _, _ in draft = "" }
    }

    // MARK: - Top bar

    private var navBar: some View {
        HStack {
            Button(action: onClose) {
                DSIcon(name: .back, size: 22, color: theme.rose, strokeWidth: 2.2).padding(6)
            }
            .buttonStyle(.plain)
            Spacer()
            Text("\(questions.count) 條問題")
                .font(DSText.ui(theme, 15, weight: .semibold))
                .foregroundStyle(theme.ink)
            Spacer()
            Text("\(step + 1)/\(questions.count)")
                .font(DSText.mono(theme, 12))
                .foregroundStyle(theme.inkMuted)
                .padding(6)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .padding(.bottom, 12)
    }

    // MARK: - Progress

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Rectangle().fill(theme.line)
                Rectangle()
                    .fill(theme.rose)
                    .frame(width: geo.size.width * CGFloat(step + 1) / CGFloat(questions.count))
                    .animation(.easeOut(duration: 0.3), value: step)
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
        .padding(.horizontal, 20)
        .padding(.bottom, 24)
    }

    // MARK: - Content

    private var content: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("QUESTION \(String(format: "%02d", question.id))")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.rose)

            Text(question.question)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
                .padding(.top, 10)
                .lineSpacing(4)

            if bothAnswered {
                revealCards
                    .padding(.top, 24)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        statusRow(forMe: true)
                        statusRow(forMe: false)
                        if myAnswer == nil { composer.padding(.top, 8) }
                    }
                    .padding(.top, 20)
                }
            }
        }
        .padding(.horizontal, 24)
    }

    @ViewBuilder
    private func statusRow(forMe: Bool) -> some View {
        let answered = forMe ? (myAnswer != nil) : (partnerAnswer != nil)
        let name = forMe
            ? (profileStore.profile?.myName ?? "你")
            : (pairing.partner?.myName ?? profileStore.profile?.partnerName ?? "對方")
        let tint = forMe ? theme.rose : theme.sage
        let tintSoft = forMe ? theme.roseSoft : theme.sageSoft

        HStack(spacing: 10) {
            Circle()
                .fill(tintSoft)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(DSText.mono(theme, 13))
                        .foregroundStyle(tint)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text("\(name.uppercased()) \(answered ? "已答 ✓" : "答緊…")")
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(answered ? tint : theme.inkMuted)
                Text(answered ? "(寫好嘞，等對方)" : "(仲未答)")
                    .font(DSText.ui(theme, 13))
                    .foregroundStyle(theme.inkSoft)
            }
            Spacer()
        }
        .padding(14)
        .background(theme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(theme.line, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("你嘅答案")
                .font(DSText.mono(theme, 11))
                .foregroundStyle(theme.inkMuted)
                .textCase(.uppercase)
            ZStack(alignment: .topLeading) {
                if draft.isEmpty {
                    Text("寫返先 — 對方答埋之後一齊揭曉")
                        .font(DSText.ui(theme, 14))
                        .foregroundStyle(theme.inkMuted)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                }
                TextEditor(text: $draft)
                    .font(DSText.ui(theme, 14))
                    .foregroundStyle(theme.ink)
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 10)
                    .frame(minHeight: 90)
            }
            .background(theme.surface)
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(theme.line, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Button(action: submit) {
                HStack(spacing: 6) {
                    if isSubmitting {
                        ProgressView().tint(.white)
                    } else {
                        Text("記低答案")
                    }
                }
                .font(DSText.ui(theme, 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(canSubmit ? theme.rose : theme.line)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .disabled(!canSubmit || isSubmitting)
        }
    }

    private var revealCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            if matched {
                Text("♡ 心有靈犀！")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.sage)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.sageSoft)
                    .clipShape(Capsule())
                    .padding(.bottom, 4)
            }

            if let mine = myAnswer {
                answerCard(
                    name: profileStore.profile?.myName ?? "你",
                    answer: mine,
                    tint: theme.rose,
                    tintSoft: theme.roseSoft
                )
            }
            if let theirs = partnerAnswer {
                answerCard(
                    name: pairing.partner?.myName ?? profileStore.profile?.partnerName ?? "對方",
                    answer: theirs,
                    tint: theme.sage,
                    tintSoft: theme.sageSoft
                )
            }
        }
    }

    private func answerCard(name: String, answer: String, tint: Color, tintSoft: Color) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(tintSoft)
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(name.prefix(1)))
                        .font(DSText.mono(theme, 13))
                        .foregroundStyle(tint)
                )
            VStack(alignment: .leading, spacing: 4) {
                Text(name.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(tint)
                Text(answer)
                    .font(DSText.ui(theme, 14))
                    .foregroundStyle(theme.ink)
                    .lineSpacing(3)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(tintSoft)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Action row

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button { step = max(0, step - 1) } label: {
                Text("←")
                    .font(DSText.ui(theme, 16, weight: .medium))
                    .foregroundStyle(theme.inkSoft)
                    .frame(width: 56, height: 48)
                    .background(theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(theme.line, lineWidth: 0.5)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(step == 0)
            .opacity(step == 0 ? 0.5 : 1)

            Button {
                step = (step + 1) % questions.count
            } label: {
                Text(step + 1 < questions.count ? "下一條 →" : "再來一次 ↺")
                    .font(DSText.ui(theme, 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
                    .background(theme.rose)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Submit

    private var canSubmit: Bool {
        !draft.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func submit() {
        guard canSubmit, let meId else { return }
        let text = draft.trimmingCharacters(in: .whitespaces)
        let payload = PlayHistoryPayload(
            kind: .quizAnswer,
            cardId: nil,
            text: text,
            dayISO: nil,
            questionId: question.id,
            atISO: ISO8601DateFormatter().string(from: Date())
        )
        isSubmitting = true
        Task {
            await playHistory.add(payload: payload, senderId: meId)
            isSubmitting = false
            draft = ""
        }
    }
}

#Preview {
    let crypto = CryptoService()
    return QuizView(onClose: {})
        .environmentObject(PlayHistoryService(crypto: crypto))
        .environmentObject(AuthService())
        .environmentObject(UserProfileStore())
        .environmentObject(PairingService())
        .theme(.jbeam)
}
