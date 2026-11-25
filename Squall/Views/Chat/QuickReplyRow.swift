import SwiftUI

/// Tap-to-send answers under a teammate's newest reply when it asks a quick question (see QuickReplies).
struct QuickReplyRow: View {
    let text: String
    var tint: Color = Color(hex: Theme.defaultAccentHex)
    var onSend: (String) -> Void

    var body: some View {
        let replies = QuickReplies.suggestions(for: text)
        if !replies.isEmpty {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    Image(systemName: "arrowshape.turn.up.left.fill")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.muted)
                        .accessibilityHidden(true)
                    ForEach(replies, id: \.self) { reply in
                        Button(reply) { onSend(reply) }
                            .buttonStyle(ChipButtonStyle(tint: tint, minHeight: 34))
                            .accessibilityLabel("Reply \(reply)")
                    }
                }
                .padding(.leading, 36)
                .padding(.trailing, 8)
            }
            .transition(.opacity)
        }
    }
}
