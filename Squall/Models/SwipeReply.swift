import CoreGraphics

/// Swipe a message to the right to reply with a quote of it. The bubble follows your finger up to `trigger`,
/// then slows down, and letting go past `trigger` puts the quote in the message box (the same as Reply with quote).
/// Mostly-up-and-down drags are scrolling, so they never move a bubble.
enum SwipeReply {
    /// How far right a drag has to go to reply.
    static let trigger: CGFloat = 60
    /// The bubble never moves further than this.
    static let maxOffset: CGFloat = 84
    /// A drag counts as sideways when it's this many times wider than it is tall.
    static let sideways: CGFloat = 1.6

    /// True when the drag is a sideways swipe to the right, not scrolling.
    static func isSwipe(_ translation: CGSize) -> Bool {
        translation.width > 0 && translation.width > abs(translation.height) * sideways
    }

    /// How far the bubble moves for a drag: 1 to 1 up to `trigger`, then a third as fast, up to `maxOffset`.
    static func offset(for translation: CGSize) -> CGFloat {
        guard isSwipe(translation) else { return 0 }
        let x = translation.width
        if x <= trigger { return x }
        return min(maxOffset, trigger + (x - trigger) / 3)
    }

    /// True when letting go now replies.
    static func replies(_ translation: CGSize) -> Bool {
        isSwipe(translation) && translation.width >= trigger
    }

    /// How full the reply arrow looks, from 0 to 1.
    static func progress(_ offset: CGFloat) -> CGFloat {
        max(0, min(1, offset / trigger))
    }
}
