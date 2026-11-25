import SwiftUI
import UIKit

/// Your messages that are waiting to send (see Outbox), under the chat's real messages. They look like your
/// own bubbles, faded, with a clock. Long-press one to send it now, edit it, copy it or delete it.
struct OutboxBubbles: View {
    let chatID: String

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var outbox = Outbox.shared
    @AppStorage(Prefs.chatTextSize) private var textSize = 15.0

    var body: some View {
        let waiting = outbox.entries(for: chatID)
        if !waiting.isEmpty {
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(waiting) { entry in
                    bubble(entry)
                }
                HStack(spacing: 5) {
                    if store.flushingOutbox {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "clock")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    Text(Outbox.statusText(connected: store.isConnected, sending: store.flushingOutbox))
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundStyle(Theme.muted)
                .accessibilityElement(children: .combine)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
            .transition(.opacity)
        }
    }

    private func bubble(_ entry: Outbox.Entry) -> some View {
        HStack {
            Spacer(minLength: 50)
            Text(entry.text)
                .font(.system(size: textSize))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(store.accent.opacity(0.45))
                        .overlay(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(store.accent.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                        )
                )
                .accessibilityLabel("Waiting to send: \(entry.text)")
                .contextMenu {
                    if store.isConnected {
                        Button {
                            store.flushOutbox()
                        } label: {
                            Label("Send now", systemImage: "paperplane")
                        }
                    }
                    Button {
                        outbox.remove(entry.id)
                        SavedPrompts.shared.insert = SavedPrompts.Insert(chatID: chatID, text: entry.text)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        UIPasteboard.general.string = entry.text
                        store.showToast("Copied.")
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        outbox.remove(entry.id)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
        }
    }
}
