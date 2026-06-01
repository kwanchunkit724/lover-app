import SwiftUI
import UIKit

// v1.6.1 Feature 7 — full-screen "cheer" interaction.
//
// CheerOverlay: I tap the screen to cheer my partner out of a sad/angry/tired
// mood (or a single clap for happy/love). On reaching the mood's target tap
// count it fires onComplete (which records the cheer) and celebrates.
//
// CheerReceivedOverlay: shown to the partner who was just cheered — a shared
// celebration so it feels mutual.

struct CheerOverlay: View {
    @Environment(\.theme) private var theme
    let partnerName: String
    let mood: Mood
    /// Called once when the target tap count is reached.
    let onComplete: () -> Void
    let onClose: () -> Void

    @State private var count = 0
    @State private var done = false
    @State private var pop = false

    private var target: Int { mood.targetTaps }
    private var progress: Double { min(1, Double(count) / Double(target)) }

    var body: some View {
        ZStack {
            theme.paper.ignoresSafeArea()

            // Tap catcher — whole screen.
            Color.clear
                .contentShape(Rectangle())
                .ignoresSafeArea()
                .onTapGesture { tap() }

            VStack(spacing: 24) {
                Text(done ? mood.doneKao : mood.cheerKao)
                    .font(.system(size: 56))
                    .scaleEffect(pop ? 1.18 : 1.0)
                    .animation(.spring(response: 0.2, dampingFraction: 0.5), value: pop)

                Text(done ? "你成功\(mood.cheerVerb.replacingOccurrences(of: "同", with: ""))喇！"
                          : "撳爆個畫面\(mood.cheerVerb)")
                    .font(DSText.ui(theme, 16, weight: .semibold))
                    .foregroundStyle(theme.ink)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)

                if !done {
                    // Progress ring + count.
                    ZStack {
                        Circle().stroke(theme.line, lineWidth: 10)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(theme.rose, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 0.15), value: progress)
                        Text(target == 1 ? "👏" : "\(count)/\(target)")
                            .font(DSText.mono(theme, 18).weight(.bold))
                            .foregroundStyle(theme.rose)
                    }
                    .frame(width: 140, height: 140)
                } else {
                    Text("(づ｡◕‿‿◕｡)づ  \(partnerName) ♡")
                        .font(DSText.mono(theme, 14))
                        .foregroundStyle(theme.rose)
                }
            }

            VStack {
                HStack {
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(theme.inkMuted)
                            .padding(10)
                            .background(theme.nav, in: Circle())
                    }
                    .padding(.trailing, 16)
                    .padding(.top, 10)
                }
                Spacer()
            }
        }
        .onChange(of: done) { _, isDone in
            if isDone {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
                onComplete()
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { onClose() }
            }
        }
    }

    private func tap() {
        guard !done else { return }
        count += 1
        pop.toggle()
        let style: UIImpactFeedbackGenerator.FeedbackStyle =
            count >= target - 3 ? .medium : .light
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        if count >= target { done = true }
    }
}

// Celebration shown to the partner who was just cheered.
struct CheerReceivedOverlay: View {
    @Environment(\.theme) private var theme
    let partnerName: String
    let mood: Mood
    let onClose: () -> Void

    @State private var bounce = false

    var body: some View {
        ZStack {
            theme.paper.opacity(0.98).ignoresSafeArea()
                .onTapGesture { onClose() }

            VStack(spacing: 18) {
                Text(mood.doneKao)
                    .font(.system(size: 60))
                    .scaleEffect(bounce ? 1.1 : 0.9)
                    .animation(.spring(response: 0.5, dampingFraction: 0.5).repeatForever(autoreverses: true),
                               value: bounce)
                Text("\(partnerName) 氹返你開心喇 ♡")
                    .font(DSText.ui(theme, 17, weight: .semibold))
                    .foregroundStyle(theme.ink)
                Text("撳一下繼續")
                    .font(DSText.mono(theme, 11))
                    .foregroundStyle(theme.inkMuted)
            }
        }
        .onAppear {
            bounce = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) { onClose() }
        }
    }
}
