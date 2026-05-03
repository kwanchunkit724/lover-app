import SwiftUI

// 21 條問題 — translation of Quiz() in design-import/extra.jsx.
// Both partners answer; reveal side-by-side. "心有靈犀" badge if matched.

struct QuizView: View {
    @Environment(\.theme) private var theme
    let onClose: () -> Void

    @State private var step: Int = 0
    @State private var revealed: Bool = false

    private var question: QuizQuestion {
        let questions = MockData.quizQuestions
        return questions[step % questions.count]
    }

    var body: some View {
        VStack(spacing: 0) {
            navBar
            progressBar
            content
            actionButton
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .padding(.bottom, 10)
        }
        .background(theme.paper)
    }

    // MARK: - Top bar

    private var navBar: some View {
        HStack {
            Button(action: onClose) {
                DSIcon(name: .back, size: 22, color: theme.rose, strokeWidth: 2.2).padding(6)
            }
            .buttonStyle(.plain)

            Spacer()

            Text("21 條問題")
                .font(DSText.ui(theme, 15, weight: .semibold))
                .foregroundStyle(theme.ink)

            Spacer()

            Text("\(step + 1)/21")
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
                Rectangle()
                    .fill(theme.line)
                Rectangle()
                    .fill(theme.rose)
                    .frame(width: geo.size.width * CGFloat(step + 1) / 21)
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
            Text("QUESTION \(String(format: "%02d", step + 1))")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(theme.rose)

            Text(question.question)
                .font(.system(size: 26, weight: .semibold, design: .serif))
                .foregroundStyle(theme.ink)
                .padding(.top, 10)
                .lineSpacing(4)

            if revealed {
                revealCards
                    .padding(.top, 24)
            } else {
                Spacer()
                waitingCards
                    .padding(.bottom, 10)
            }

            if revealed { Spacer() }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var waitingCards: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                DSAvatar(person: MockData.me, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("KIT 已答 ✓")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(theme.sage)
                    Text("等緊 Michel…")
                        .font(DSText.ui(theme, 13))
                        .foregroundStyle(theme.inkMuted)
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

            HStack(spacing: 10) {
                DSAvatar(person: MockData.partner, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MICHEL 答緊…")
                        .font(.system(size: 10, weight: .regular, design: .monospaced))
                        .foregroundStyle(theme.amber)
                    HStack(spacing: 3) {
                        ForEach(0..<3) { _ in
                            Circle().fill(theme.amber).frame(width: 5, height: 5)
                        }
                    }
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
    }

    private var revealCards: some View {
        VStack(alignment: .leading, spacing: 10) {
            if question.matched {
                Text("♡ 心有靈犀！")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(theme.sage)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(theme.sageSoft)
                    .clipShape(Capsule())
                    .padding(.bottom, 4)
            }

            answerCard(person: MockData.me, answer: question.kitAnswer)
            answerCard(person: MockData.partner, answer: question.michelAnswer)
        }
    }

    private func answerCard(person: Person, answer: String) -> some View {
        let tint: Color = person.tint == .rose ? theme.rose : theme.sage
        let tintSoft: Color = person.tint == .rose ? theme.roseSoft : theme.sageSoft

        return HStack(alignment: .top, spacing: 12) {
            DSAvatar(person: person, size: 32)
            VStack(alignment: .leading, spacing: 4) {
                Text(person.name.uppercased())
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

    // MARK: - Action

    private var actionButton: some View {
        Button {
            if !revealed {
                revealed = true
            } else {
                revealed = false
                step = (step + 1) % 21
            }
        } label: {
            Text(revealed ? "下一條 →" : "睇答案")
                .font(DSText.ui(theme, 15, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(theme.rose)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    QuizView(onClose: {}).theme(.jbeam)
}
