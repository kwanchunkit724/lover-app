import SwiftUI

// Three-dot typing indicator next to "Michel 打緊字" — translation of TypingIndicator in chat.jsx.

struct TypingIndicator: View {
    @Environment(\.theme) private var theme

    let partnerName: String

    @State private var phase: Int = 0
    private let timer = Timer.publish(every: 0.46, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            HStack(spacing: 4) {
                ForEach(0..<3) { i in
                    Circle()
                        .fill(theme.inkMuted)
                        .frame(width: 6, height: 6)
                        .offset(y: phase == i ? -3 : 0)
                        .opacity(phase == i ? 1 : 0.5)
                        .animation(.easeInOut(duration: 0.3), value: phase)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.bubbleThem)
            .overlay(
                BubbleShape(isFromMe: false)
                    .stroke(theme.bubbleThemBorder, lineWidth: 0.5)
            )
            .clipShape(BubbleShape(isFromMe: false))

            Text("\(partnerName) 打緊字")
                .font(DSText.mono(theme, 10))
                .foregroundStyle(theme.inkMuted)

            Spacer()
        }
        .padding(.bottom, 8)
        .onReceive(timer) { _ in
            phase = (phase + 1) % 3
        }
    }
}
