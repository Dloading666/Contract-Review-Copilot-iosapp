import SwiftUI

enum DogeTheme {
    static let background = Color(red: 0.98, green: 0.94, blue: 0.87)
    static let panel = Color(red: 1.0, green: 0.97, blue: 0.91)
    static let ink = Color(red: 0.08, green: 0.08, blue: 0.08)
    static let muted = Color(red: 0.44, green: 0.42, blue: 0.39)
    static let blue = Color(red: 0.16, green: 0.44, blue: 0.88)
    static let green = Color(red: 0.13, green: 0.65, blue: 0.28)
    static let orange = Color(red: 0.90, green: 0.49, blue: 0.02)
    static let red = Color(red: 0.90, green: 0.18, blue: 0.16)
}

struct PixelPanel: ViewModifier {
    let border: Color
    let dashed: Bool

    func body(content: Content) -> some View {
        content
            .padding(18)
            .background(DogeTheme.panel)
            .overlay {
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(border, style: StrokeStyle(lineWidth: 2.5, dash: dashed ? [7, 6] : []))
            }
    }
}

extension View {
    func pixelPanel(border: Color = DogeTheme.ink, dashed: Bool = false) -> some View {
        modifier(PixelPanel(border: border, dashed: dashed))
    }
}

struct DogeBadge: View {
    var size: CGFloat = 86

    var body: some View {
        Image(uiImage: UIImage(named: "doge.png") ?? UIImage())
            .resizable()
            .interpolation(size < 50 ? .medium : .none)
            .scaledToFit()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: size * 0.12))
            .accessibilityLabel("Doge")
    }
}

struct RiskPill: View {
    let risk: RiskLevel

    var body: some View {
        Text(risk.title)
            .font(.caption.bold())
            .foregroundStyle(risk.color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(risk.color.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}
