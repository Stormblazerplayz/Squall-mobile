import SwiftUI

/// Swipe a message right to reply with a quote of it (see SwipeReply). A reply arrow fills in as you drag,
/// with a tick when letting go will reply.
private struct SwipeToReply: ViewModifier {
    let message: ChatMessage
    let chatID: String
    let authorName: String
    let tint: Color

    @AppStorage(Prefs.haptics) private var haptics = true
    @State private var offset: CGFloat = 0
    @State private var armed = false

    @ViewBuilder
    func body(content: Content) -> some View {
        let words = StarredMessages.words(of: message)
        if words.isEmpty || !(message.kind == .me || message.kind == .bot) {
            content
        } else {
            content
                .offset(x: offset)
                .background(alignment: .leading) {
                    if offset > 4 {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(armed ? Color.white : tint)
                            .frame(width: 32, height: 32)
                            .background(Circle().fill(armed ? tint : tint.opacity(0.16)))
                            .scaleEffect(0.6 + 0.4 * SwipeReply.progress(offset))
                            .opacity(Double(SwipeReply.progress(offset)))
                            .padding(.leading, 4)
                            .accessibilityHidden(true)
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            offset = SwipeReply.offset(for: value.translation)
                            let now = SwipeReply.replies(value.translation)
                            if now != armed { armed = now }
                        }
                        .onEnded { value in
                            if SwipeReply.replies(value.translation) {
                                reply(words)
                            }
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                                offset = 0
                            }
                            armed = false
                        }
                )
                .sensoryFeedback(.impact(weight: .light), trigger: armed) { _, now in haptics && now }
                .accessibilityAction(named: "Reply with quote") { reply(words) }
        }
    }

    private func reply(_ words: String) {
        let quote = QuoteReply.quote(words, author: authorName, mine: message.kind == .me)
        SavedPrompts.shared.insert = SavedPrompts.Insert(chatID: chatID, text: quote)
    }
}

extension View {
    /// Swipe right to reply with a quote. Only your messages and teammates' replies that have words can be swiped.
    func swipeToReply(_ message: ChatMessage, chatID: String, authorName: String, tint: Color) -> some View {
        modifier(SwipeToReply(message: message, chatID: chatID, authorName: authorName, tint: tint))
    }
}
