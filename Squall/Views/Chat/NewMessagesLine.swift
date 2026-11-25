import SwiftUI

/// The line above the first message that came in since you last had the chat open.
struct NewMessagesLine: View {
    let count: Int
    var tint: Color = Theme.redSoft

    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(tint.opacity(0.55)).frame(height: 1)
            HStack(spacing: 5) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 10, weight: .bold))
                Text(NewMessages.label(count).uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .tracking(0.6)
            }
            .foregroundStyle(tint)
            .fixedSize()
            Rectangle().fill(tint.opacity(0.55)).frame(height: 1)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NewMessages.label(count))
    }
}
