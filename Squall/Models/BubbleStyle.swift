import SwiftUI

/// The shape of message bubbles, picked in Settings under Chat: Round (the usual), Tails (a small corner that points at
/// who wrote it, like a texting app) or Square.
enum BubbleStyle: String, CaseIterable, Identifiable {
    case rounded, tails, square

    static let key = "squall.bubbleStyle"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rounded: return "Round"
        case .tails: return "Tails"
        case .square: return "Square"
        }
    }

    /// Your bubbles are a bit rounder than a teammate's card, as before.
    static let mineRadius: CGFloat = 18
    static let theirsRadius: CGFloat = 16
    static let tailRadius: CGFloat = 5
    static let squareRadius: CGFloat = 6

    /// The corners of a bubble. Yours points down to the right; a teammate's points up to the left at their picture,
    /// so a reply that follows another from the same teammate (no picture) gets no tail.
    func radii(mine: Bool, continued: Bool = false) -> RectangleCornerRadii {
        let big = mine ? Self.mineRadius : Self.theirsRadius
        switch self {
        case .rounded:
            return RectangleCornerRadii(topLeading: big, bottomLeading: big, bottomTrailing: big, topTrailing: big)
        case .square:
            let r = Self.squareRadius
            return RectangleCornerRadii(topLeading: r, bottomLeading: r, bottomTrailing: r, topTrailing: r)
        case .tails:
            if mine {
                return RectangleCornerRadii(topLeading: big, bottomLeading: big, bottomTrailing: Self.tailRadius, topTrailing: big)
            }
            return RectangleCornerRadii(topLeading: continued ? big : Self.tailRadius, bottomLeading: big,
                                        bottomTrailing: big, topTrailing: big)
        }
    }

    func shape(mine: Bool, continued: Bool = false) -> UnevenRoundedRectangle {
        UnevenRoundedRectangle(cornerRadii: radii(mine: mine, continued: continued), style: .continuous)
    }
}

/// A teammate's reply card in the picked shape. Round keeps the usual glass card.
struct BubbleGlass: ViewModifier {
    let style: BubbleStyle
    let tintHex: UInt32
    let continued: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if style == .rounded {
            content.glassCard(radius: BubbleStyle.theirsRadius, tint: tintHex, strength: 0.1)
        } else {
            let shape = style.shape(mine: false, continued: continued)
            content
                .background(
                    shape.fill(LinearGradient(
                        colors: [Color(hex: tintHex, opacity: 0.1), Color.white.opacity(0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                )
                .overlay(shape.stroke(Color(hex: tintHex, opacity: 0.24), lineWidth: 1))
                .contentShape(.contextMenuPreview, shape)
        }
    }
}

extension View {
    func bubbleGlass(_ style: BubbleStyle, tintHex: UInt32, continued: Bool) -> some View {
        modifier(BubbleGlass(style: style, tintHex: tintHex, continued: continued))
    }
}
