import SwiftUI

/// The red count, or a dot for a chat marked as unread.
struct UnreadBadge: View {
    let badge: UnreadMarks.Badge

    var body: some View {
        switch badge {
        case .count(let text):
            Text(text)
                .font(.system(size: 10.5, weight: .bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 18)
                .background(Capsule().fill(Theme.red))
        case .dot:
            Circle()
                .fill(Theme.red)
                .frame(width: 11, height: 11)
                .overlay(Circle().stroke(Theme.background, lineWidth: 2))
        }
    }
}

/// Mark as unread or Mark as read, for a teammate's context menu.
struct UnreadMenuItem: View {
    @ObservedObject private var marks = UnreadMarks.shared
    let chatID: String

    var body: some View {
        let marked = marks.isMarked(chatID)
        Button {
            withAnimation(.easeOut(duration: 0.2)) {
                if marked { marks.clear(chatID) } else { marks.mark(chatID) }
            }
        } label: {
            Label(marked ? "Mark as read" : "Mark as unread",
                  systemImage: marked ? "envelope.open" : "envelope.badge")
        }
    }
}
