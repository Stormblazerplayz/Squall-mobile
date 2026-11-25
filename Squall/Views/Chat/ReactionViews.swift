import SwiftUI
import UIKit

/// The small emoji under a message you reacted to. Tap it to pick another or take it off.
struct ReactionBadge: View {
    let chatID: String
    let messageID: String
    let tint: Color

    @ObservedObject private var reactions = MessageReactions.shared

    var body: some View {
        if let emoji = reactions.emoji(chatID: chatID, messageID: messageID) {
            Menu {
                ReactionChoices(chatID: chatID, messageID: messageID)
                Button(role: .destructive) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        reactions.remove(chatID: chatID, messageID: messageID)
                    }
                } label: {
                    Label("Take off", systemImage: "xmark")
                }
            } label: {
                Text(emoji)
                    .font(.system(size: 14))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(
                        Capsule()
                            .fill(Theme.background)
                            .overlay(Capsule().fill(tint.opacity(0.18)))
                            .overlay(Capsule().stroke(tint.opacity(0.55), lineWidth: 1))
                    )
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 1)
            }
            .buttonStyle(.plain)
            .transition(.scale(scale: 0.3).combined(with: .opacity))
            .accessibilityLabel(MessageReactions.label(emoji))
            .accessibilityHint("Change or take off the reaction")
        }
    }
}

/// The emoji to pick from, with a check on the one that's on now.
struct ReactionChoices: View {
    let chatID: String
    let messageID: String

    @ObservedObject private var reactions = MessageReactions.shared

    var body: some View {
        let current = reactions.emoji(chatID: chatID, messageID: messageID)
        ForEach(MessageReactions.choices, id: \.self) { emoji in
            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    _ = reactions.toggle(emoji, chatID: chatID, messageID: messageID)
                }
            } label: {
                if emoji == current {
                    Label(emoji, systemImage: "checkmark")
                } else {
                    Text(emoji)
                }
            }
        }
    }
}

extension View {
    /// Hangs the reaction off the bubble's bottom corner and makes room for it below.
    func reactionBadge(chatID: String?, messageID: String, tint: Color, trailing: Bool) -> some View {
        modifier(ReactionSpot(chatID: chatID, messageID: messageID, tint: tint, trailing: trailing))
    }
}

private struct ReactionSpot: ViewModifier {
    let chatID: String?
    let messageID: String
    let tint: Color
    let trailing: Bool

    @ObservedObject private var reactions = MessageReactions.shared

    @ViewBuilder
    func body(content: Content) -> some View {
        if let chatID {
            let on = reactions.emoji(chatID: chatID, messageID: messageID) != nil
            content
                .overlay(alignment: trailing ? .bottomTrailing : .bottomLeading) {
                    ReactionBadge(chatID: chatID, messageID: messageID, tint: tint)
                        .offset(x: trailing ? -8 : 10, y: 15)
                }
                .padding(.bottom, on ? 13 : 0)
        } else {
            content
        }
    }
}
