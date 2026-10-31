import SwiftUI

/// Colors and fonts from the Squall concept designs: a dark, glowy look.
enum Theme {
    static let background = Color(hex: 0x0B0A12)
    static let text = Color(hex: 0xECEAF6)
    static let textBright = Color(hex: 0xF2F0FB)
    static let sub = Color(hex: 0xA9ADC0)
    static let label = Color(hex: 0x9A9EB2)
    static let muted = Color(hex: 0x8E92A6)
    static let card = Color.white.opacity(0.04)
    static let cardBorder = Color.white.opacity(0.08)
    static let field = Color.white.opacity(0.06)

    static let goldHex: UInt32 = 0xD8B747
    static let gold = Color(hex: 0xD8B747)
    static let goldBright = Color(hex: 0xF5C84B)
    static let goldText = Color(hex: 0xFDE68A)
    static let darkInk = Color(hex: 0x17140A)

    static let green = Color(hex: 0x4ADE80)
    static let greenText = Color(hex: 0x86EFAC)
    static let yellow = Color(hex: 0xFACC15)
    static let red = Color(hex: 0xE5484D)
    static let redSoft = Color(hex: 0xF87171)
    static let redText = Color(hex: 0xFCA5A5)
    static let grayDot = Color(hex: 0x8B90A3)
    static let grayText = Color(hex: 0xC3C7D4)
    static let commandText = Color(hex: 0x9FC3EC)

    static let defaultAccentHex: UInt32 = 0x6D5CE8

    /// Accent colors people can pick in Settings.
    static let accentChoices: [(name: String, hex: UInt32)] = [
        ("Purple", 0x6D5CE8),
        ("Blue", 0x2F6FD0),
        ("Teal", 0x0D7D6B),
        ("Orange", 0xB4472F),
        ("Pink", 0xB23A7A)
    ]

    static func mono(_ size: CGFloat = 12.5) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

extension Color {
    /// Makes a color from a hex number like 0x6D5CE8.
    init(hex: UInt32, opacity: Double = 1) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: opacity)
    }

    /// Mixes a hex color toward white (`towardWhite: true`) or black by `amount` (0 to 1).
    static func shade(_ hex: UInt32, towardWhite: Bool, _ amount: Double) -> Color {
        let target: Double = towardWhite ? 255 : 0
        func channel(_ shift: UInt32) -> Double {
            let value = Double((hex >> shift) & 0xFF)
            return (value + (target - value) * amount) / 255
        }
        return Color(.sRGB, red: channel(16), green: channel(8), blue: channel(0), opacity: 1)
    }

    /// Rough brightness of a hex color, 0 (black) to 1 (white).
    static func brightness(_ hex: UInt32) -> Double {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }
}
