import SwiftUI

/// Holds a reply's words, folded when they're long (see LongReplies), with Show more and Show less.
struct FoldedReply<Content: View>: View {
    let id: String
    let text: String
    var size: Double = 15
    var tint: Color = Color(hex: Theme.defaultAccentHex)
    @ViewBuilder var content: () -> Content
    @ObservedObject private var opened = OpenReplies.shared

    var body: some View {
        if LongReplies.isLong(text) {
            let isOpen = opened.isOpen(id)
            VStack(alignment: .leading, spacing: 6) {
                content()
                    .frame(maxHeight: isOpen ? nil : foldedHeight, alignment: .top)
                    .clipped()
                    .mask {
                        if isOpen {
                            Rectangle()
                        } else {
                            LinearGradient(stops: [.init(color: .black, location: 0), .init(color: .black, location: 0.72),
                                                   .init(color: .clear, location: 1)],
                                           startPoint: .top, endPoint: .bottom)
                        }
                    }
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { opened.toggle(id) }
                } label: {
                    HStack(spacing: 5) {
                        Text(isOpen ? "Show less" : LongReplies.moreLabel(text))
                            .font(.system(size: 12.5, weight: .semibold))
                        Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                            .font(.system(size: 10.5, weight: .bold))
                    }
                    .foregroundStyle(tint)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(Capsule().fill(tint.opacity(0.14)))
                    .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isOpen ? "Show less of this reply" : "Show the whole reply")
            }
        } else {
            content()
        }
    }

    /// The height of the lines shown while folded, for the chat's text size.
    private var foldedHeight: CGFloat {
        CGFloat(size * 1.32 * Double(LongReplies.shownLines))
    }
}
