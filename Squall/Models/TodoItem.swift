import Foundation

/// One item on Squall's shared To do list: the list you, your live sessions and the bots keep on the computer
/// (the To do pane on the right of Squall's window). Everything here comes from the computer.
struct TodoItem: Identifiable, Equatable {
    enum Status: String, Equatable {
        case todo
        case doing
        case done
    }

    let id: String
    var text: String
    var status: Status
    /// Who added it: "Storm", a bot's name, or a live session like "Laptop".
    var by: String
    /// Who is on it, or did it.
    var who: String
    /// The bot's id when `who` is one of your bots.
    var botID: String?
    /// Why a bot is waiting on you for this one, if it is.
    var needs: String?
    /// The bot to answer when it needs you.
    var needsBy: String?
    var addedAt: Date?
    var doneAt: Date?

    var isOpen: Bool { status != .done }
    var needsYou: Bool { isOpen && !(needs ?? "").isEmpty }
}

/// The whole list, sorted the way the phone shows it.
struct TodoList: Equatable {
    var items: [TodoItem]

    /// Open items a bot is waiting on you for.
    var needsYou: [TodoItem] { items.filter(\.needsYou) }
    /// Being done now (and not waiting on you).
    var doing: [TodoItem] { items.filter { $0.status == .doing && !$0.needsYou } }
    /// Not started yet (and not waiting on you).
    var next: [TodoItem] { items.filter { $0.status == .todo && !$0.needsYou } }
    /// The newest finished ones first.
    var done: [TodoItem] {
        items.filter { $0.status == .done }.sorted { ($0.doneAt ?? .distantPast) > ($1.doneAt ?? .distantPast) }
    }

    var openCount: Int { items.filter(\.isOpen).count }
    var doneCount: Int { items.count - openCount }
    var progress: Double { items.isEmpty ? 0 : Double(doneCount) / Double(items.count) }

    /// "3 of 8 done"
    var countText: String { "\(doneCount) of \(items.count) done" }

    func item(_ id: String) -> TodoItem? { items.first { $0.id == id } }

    /// What Siri says about the list.
    var spoken: String {
        let open = items.filter(\.isOpen)
        if items.isEmpty { return "Your To do list is empty." }
        if open.isEmpty { return "Everything on your To do list is done." }
        var parts: [String] = []
        let waiting = needsYou.count
        let doingNow = doing.count
        let notStarted = next.count
        parts.append(open.count == 1 ? "There's 1 thing on your To do list." : "There are \(open.count) things on your To do list.")
        if waiting > 0 { parts.append(waiting == 1 ? "1 needs you." : "\(waiting) need you.") }
        if doingNow > 0 { parts.append("\(doingNow) \(doingNow == 1 ? "is" : "are") being done.") }
        if notStarted > 0 { parts.append("\(notStarted) \(notStarted == 1 ? "hasn't" : "haven't") started.") }
        let first = (needsYou.first ?? doing.first ?? next.first).map { "First up: \(TodoList.sentence($0.text))" }
        if let first { parts.append(first) }
        return parts.joined(separator: " ")
    }

    /// Ends text with a full stop if it has no ending mark.
    static func sentence(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = text.last else { return text }
        return ".!?".contains(last) ? text : text + "."
    }
}
