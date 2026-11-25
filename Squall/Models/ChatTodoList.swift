import Foundation

/// Every task-list line ("- [ ] …") in a teammate's replies in one chat, gathered in one place, from the ••• menu as
/// "To-dos in this chat". Ticking one here ticks it in the reply too, since both use TickLists.
enum ChatTodoList {
    struct Entry: Equatable, Identifiable {
        /// The reply's TickLists key.
        let reply: String
        /// The line's place in the reply's blocks, as TickLists counts it.
        let line: Int
        let text: String
        /// What the teammate wrote: [x] or [ ].
        let written: Bool
        let messageID: String
        let at: Date?
        let time: String

        var id: String { reply + "#\(line)" }
    }

    /// The to-dos, newest reply first, and in order inside a reply.
    static func entries(chatID: String, messages: [ChatMessage]) -> [Entry] {
        var out: [Entry] = []
        for message in messages.reversed() where message.kind == .bot {
            let texts = [message.text] + (message.text2.map { [$0] } ?? [])
            for (offset, text) in texts.enumerated() {
                let reply = TickLists.key(chatID: chatID, messageID: message.id, part: offset + 1)
                for (index, block) in Markdown.blocks(text).enumerated() {
                    guard case .bullet(_, let words, let checked) = block, let checked else { continue }
                    let plain = Markdown.inlinePlain(words).trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !plain.isEmpty else { continue }
                    out.append(Entry(reply: reply, line: index, text: plain, written: checked,
                                     messageID: message.id, at: message.at, time: message.time))
                }
            }
        }
        return out
    }

    /// The open ones and the done ones, each in the same order as given.
    static func split(_ entries: [Entry], isDone: (Entry) -> Bool) -> (open: [Entry], done: [Entry]) {
        var open: [Entry] = []
        var done: [Entry] = []
        for entry in entries {
            if isDone(entry) { done.append(entry) } else { open.append(entry) }
        }
        return (open, done)
    }

    /// "3 of 8 done".
    static func summary(done: Int, total: Int) -> String {
        "\(done) of \(total) done"
    }
}
