import SwiftUI

// Striped gradient photo placeholder — translation of PhotoPH in ui.jsx.
// Used wherever a real photo would normally render. Different `id` values
// produce different hue/angle, deterministically.

struct DSPhotoPlaceholder: View {
    @Environment(\.theme) private var theme

    let id: String
    var label: String? = nil
    var height: CGFloat = 200
    var cornerRadius: CGFloat = 14

    var body: some View {
        let hash = id.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        let hue = Double(hash % 360) / 360
        let angle = Double((hash * 37) % 180)
        let isDark = theme.isDark

        let tint1 = Color(hue: hue, saturation: 0.18, brightness: isDark ? 0.30 : 0.86)
        let tint2 = Color(hue: (hue + 30/360).truncatingRemainder(dividingBy: 1),
                          saturation: 0.20, brightness: isDark ? 0.24 : 0.78)

        ZStack(alignment: .bottomLeading) {
            LinearGradient(
                colors: [tint1, tint2],
                startPoint: gradientStart(angle: angle),
                endPoint: gradientEnd(angle: angle)
            )

            DiagonalStripes(angle: angle)
                .stroke(isDark ? Color.white.opacity(0.06) : Color.black.opacity(0.06),
                        lineWidth: 1)

            if let label {
                Text(label.lowercased())
                    .font(.system(size: 10, weight: .regular, design: .monospaced))
                    .foregroundStyle(isDark ? Color.white.opacity(0.5) : Color.black.opacity(0.45))
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
            }
        }
        .frame(height: height)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private func gradientStart(angle: Double) -> UnitPoint {
        let radians = angle * .pi / 180
        return UnitPoint(x: 0.5 - 0.5 * cos(radians), y: 0.5 - 0.5 * sin(radians))
    }
    private func gradientEnd(angle: Double) -> UnitPoint {
        let radians = angle * .pi / 180
        return UnitPoint(x: 0.5 + 0.5 * cos(radians), y: 0.5 + 0.5 * sin(radians))
    }
}

private struct DiagonalStripes: Shape {
    let angle: Double

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radians = angle * .pi / 180
        let dx = cos(radians)
        let dy = sin(radians)
        let spacing: CGFloat = 14
        let diagonal = sqrt(rect.width * rect.width + rect.height * rect.height)
        let count = Int(diagonal / spacing) + 4

        for i in -count...count {
            let offset = CGFloat(i) * spacing
            let cx = rect.midX + offset * CGFloat(-dy)
            let cy = rect.midY + offset * CGFloat(dx)
            let p1 = CGPoint(x: cx - CGFloat(dx) * diagonal, y: cy - CGFloat(dy) * diagonal)
            let p2 = CGPoint(x: cx + CGFloat(dx) * diagonal, y: cy + CGFloat(dy) * diagonal)
            path.move(to: p1)
            path.addLine(to: p2)
        }
        return path
    }
}

#Preview {
    VStack(spacing: 12) {
        DSPhotoPlaceholder(id: "morning-coffee", label: "morning-coffee", height: 160)
        DSPhotoPlaceholder(id: "lamma", label: "lamma", height: 160)
    }
    .padding()
    .background(Theme.jbeam.paper)
    .theme(.jbeam)
}
