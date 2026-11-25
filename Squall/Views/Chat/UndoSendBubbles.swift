import SwiftUI

/// Messages held by Undo send (see UndoSend): your bubble with a ring that fills as the wait runs out, and Undo,
/// which puts the words back in the message box.
struct UndoSendBubbles: View {
    let chatID: String

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var undo = UndoSend.shared
    @AppStorage(Prefs.chatTextSize) private var textSize = 15.0

    var body: some View {
        let waiting = undo.pending(for: chatID)
        if !waiting.isEmpty {
            TimelineView(.animation(minimumInterval: 0.1)) { context in
                VStack(alignment: .trailing, spacing: 8) {
                    ForEach(waiting) { item in
                        row(item, now: context.date)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .transition(.opacity)
        }
    }

    private func row(_ item: UndoSend.Pending, now: Date) -> some View {
        VStack(alignment: .trailing, spacing: 5) {
            HStack {
                Spacer(minLength: 50)
                Text(item.text)
                    .font(.system(size: textSize))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(store.accent.opacity(0.7)))
            }
            HStack(spacing: 8) {
                ZStack {
                    Circle().stroke(Theme.muted.opacity(0.3), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: UndoSend.progress(item, now: now))
                        .stroke(store.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 14, height: 14)
                Text("Sending in \(UndoSend.secondsLeft(item, now: now))")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(Theme.muted)
                    .monospacedDigit()
                Button {
                    if let back = undo.undo(item.id) {
                        SavedPrompts.shared.insert = SavedPrompts.Insert(chatID: back.chatID, text: back.text)
                    }
                } label: {
                    Text("Undo")
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(store.accent)
                        .padding(.horizontal, 10)
                        .frame(height: 26)
                        .background(Capsule().fill(store.accent.opacity(0.15)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Undo sending \(item.text)")
            }
        }
    }
}
