import SwiftUI
import UIKit

/// The pinned message at the top of a chat (see PinnedMessages). Tap to open the whole message, with Copy and Unpin.
/// ChatView gives it the chat's id as its identity, so switching chats starts it closed.
struct PinnedBanner: View {
    let chatID: String
    let tint: Color

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var pinned = PinnedMessages.shared
    @State private var open = false

    var body: some View {
        if let pin = pinned.pin(chatID: chatID) {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { open.toggle() }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(tint)
                            .rotationEffect(.degrees(45))
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(tint.opacity(0.18)))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Pinned · \(pin.authorName)")
                                .font(.system(size: 11.5, weight: .bold))
                                .foregroundStyle(tint)
                            if !open {
                                Text(PinnedMessages.preview(pin.text))
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                            }
                        }
                        Spacer(minLength: 4)
                        Image(systemName: open ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.sub)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(open ? "Close the pinned message" : "Pinned message from \(pin.authorName): \(PinnedMessages.preview(pin.text))")

                if open {
                    ScrollView {
                        MarkdownText(text: pin.text, size: 14.5, tint: tint)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    .frame(maxHeight: 200)
                    HStack(spacing: 8) {
                        if !pin.time.isEmpty {
                            Text(pin.time)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.muted)
                        }
                        Spacer(minLength: 0)
                        Button {
                            UIPasteboard.general.string = pin.text
                            store.showToast("Copied.")
                        } label: {
                            Label("Copy", systemImage: "doc.on.doc")
                        }
                        Button {
                            withAnimation(.easeOut(duration: 0.2)) {
                                open = false
                                pinned.unpin(chatID: chatID)
                            }
                        } label: {
                            Label("Unpin", systemImage: "pin.slash")
                        }
                    }
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.field)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(tint.opacity(0.35), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
}
