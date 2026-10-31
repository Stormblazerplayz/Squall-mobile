import SwiftUI

/// Colors used across the app. Matches the dark "storm" look of Squall desktop.
enum Theme {
    static let background = Color(hex: 0x0B1020)
    static let card = Color(hex: 0x151B2E)
    static let cardBorder = Color.white.opacity(0.08)
    static let accent = Color(hex: 0x4FD1FF)
    static let bolt = Color(hex: 0xFFD54F)
    static let textSecondary = Color.white.opacity(0.6)
}

extension Color {
    /// Makes a color from a hex number like 0x4FD1FF.
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }
}

/// Rounded dark card with a thin border.
struct CardStyle: ViewModifier {
    var cornerRadius: CGFloat = 18

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Theme.cardBorder, lineWidth: 1)
            )
    }
}

extension View {
    func card(cornerRadius: CGFloat = 18) -> some View {
        modifier(CardStyle(cornerRadius: cornerRadius))
    }
}
