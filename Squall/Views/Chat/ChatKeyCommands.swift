import SwiftUI

/// Keyboard shortcuts in a chat (see ChatShortcuts). Hidden buttons, so iPad lists them when you hold ⌘.
struct ChatKeyCommands: View {
    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var find = ChatFind.Model.shared
    @ObservedObject private var dayJump = ChatDayJump.Model.shared
    @Binding var bigEditor: Bool

    var body: some View {
        let hasMessages = !store.messages(for: store.currentChatID).isEmpty
        Group {
            Button("Find in chat") {
                withAnimation(.easeOut(duration: 0.2)) { find.open() }
            }
            .keyboardShortcut("f", modifiers: .command)
            .disabled(!hasMessages)
            if find.isOpen {
                Button("Close Find in chat") {
                    withAnimation(.easeOut(duration: 0.2)) { find.close() }
                }
                .keyboardShortcut(.escape, modifiers: [])
            }
            Button("Go to a day") {
                dayJump.showList = true
            }
            .keyboardShortcut("d", modifiers: [.command, .shift])
            .disabled(!hasMessages)
            Button("Full editor") {
                bigEditor = true
            }
            .keyboardShortcut("e", modifiers: .command)
            Button("Next chat") { move(1) }
                .keyboardShortcut(.downArrow, modifiers: [.command, .option])
            Button("Previous chat") { move(-1) }
                .keyboardShortcut(.upArrow, modifiers: [.command, .option])
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func move(_ offset: Int) {
        let ids = ChatListOrder.favoritesFirst(store.displayBots, favorites: ChatFavorites.shared.ids).map(\.id)
        if let next = ChatShortcuts.neighbor(of: store.currentChatID, in: ids, offset: offset) {
            store.openChat(next)
        }
    }
}
