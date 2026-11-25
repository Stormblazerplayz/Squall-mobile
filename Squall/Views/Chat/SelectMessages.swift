import SwiftUI
import UIKit

/// In select mode, a message gets a check circle and a tap picks it (see ChatSelection).
private struct SelectableMessage: ViewModifier {
    let message: ChatMessage
    let chatID: String?
    let tint: Color

    @ObservedObject private var selection = ChatSelection.shared

    @ViewBuilder
    func body(content: Content) -> some View {
        if selection.isSelecting(chatID) && ChatSelection.canSelect(message) {
            let on = selection.isSelected(message.id)
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(on ? tint : Theme.muted)
                    .contentTransition(.symbolEffect(.replace))
                content
                    .allowsHitTesting(false)
                    .opacity(on ? 1 : 0.75)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeOut(duration: 0.12)) { selection.toggle(message.id) }
            }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
            .accessibilityHint(on ? "Tap to unpick" : "Tap to pick")
            .transition(.opacity)
        } else {
            content
        }
    }
}

extension View {
    func selectableMessage(_ message: ChatMessage, chatID: String?, tint: Color) -> some View {
        modifier(SelectableMessage(message: message, chatID: chatID, tint: tint))
    }
}

/// The bar over the message box in select mode: how many are picked, Copy, Share, Star and Done.
struct SelectionBar: View {
    let chatID: String

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var selection = ChatSelection.shared
    @ObservedObject private var starred = StarredMessages.shared

    var body: some View {
        VStack(spacing: 0) {
            if selection.isSelecting(chatID) {
                let picked = ChatSelection.picked(store.messages(for: chatID), ids: selection.ids)
                let text = ChatSelection.text(picked, name: name)
                HStack(spacing: 6) {
                    Text(ChatSelection.countText(picked.count))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                        .contentTransition(.numericText())
                    Spacer(minLength: 4)
                    Button {
                        UIPasteboard.general.string = text
                        store.showToast(picked.count == 1 ? "Copied." : "Copied \(picked.count) messages.")
                        selection.end()
                    } label: {
                        Image(systemName: "doc.on.doc")
                    }
                    .accessibilityLabel("Copy")
                    .disabled(picked.isEmpty)
                    ShareLink(item: text) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share")
                    .disabled(picked.isEmpty)
                    Button {
                        starAll(picked)
                    } label: {
                        Image(systemName: "star")
                    }
                    .accessibilityLabel("Star")
                    .disabled(picked.isEmpty)
                    Button("Done") {
                        withAnimation(.easeOut(duration: 0.2)) { selection.end() }
                    }
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(store.accent)
                    .padding(.leading, 4)
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.text)
                .buttonStyle(.plain)
                .padding(.horizontal, 16)
                .frame(height: 46)
                .background(Theme.background.opacity(0.95))
                .overlay(alignment: .top) { Rectangle().fill(Theme.cardBorder).frame(height: 1) }
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: selection.chatID)
        .onChange(of: chatID) { _, _ in selection.end() }
        .onDisappear { selection.end() }
    }

    private func name(_ id: String) -> String {
        if id == ChatMessage.meID { return "You" }
        return store.bot(id)?.name ?? id
    }

    private func starAll(_ picked: [ChatMessage]) {
        var added = 0
        for message in picked where !starred.isStarred(chatID: chatID, messageID: message.id) {
            if starred.toggle(message, chatID: chatID, authorName: message.kind == .me ? "You" : name(message.author)) {
                added += 1
            }
        }
        store.showToast(added == 0 ? "Already starred." : (added == 1 ? "Starred 1 message." : "Starred \(added) messages."))
        selection.end()
    }
}
