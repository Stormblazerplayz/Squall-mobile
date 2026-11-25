import Combine
import Foundation

/// Task lists in a teammate's reply ("- [ ] Run the tests") can be ticked on the phone: tap a line to tick it or untick
/// it, and the reply shows "2 of 5 done". Only the ticks you change are kept, on this phone, by chat, message and line.
final class TickLists: ObservableObject {
    static let shared = TickLists()
    static let key = "squall.tickLists"
    /// Replies with ticks kept, at most. The oldest go first.
    static let maxReplies = 300

    /// Ticks by reply ("chat/message/part"), then by the line's place in the reply.
    @Published private(set) var ticks: [String: [Int: Bool]] = [:]
    /// The order replies were last ticked in, oldest first, to know which to drop.
    private var order: [String] = []

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let saved = defaults.dictionary(forKey: Self.key) as? [String: [String: Bool]] ?? [:]
        for (reply, lines) in saved {
            var parsed: [Int: Bool] = [:]
            for (line, on) in lines { if let index = Int(line) { parsed[index] = on } }
            if !parsed.isEmpty { ticks[reply] = parsed }
        }
        order = defaults.stringArray(forKey: Self.key + ".order")?.filter { ticks[$0] != nil } ?? []
        for reply in ticks.keys.sorted() where !order.contains(reply) { order.insert(reply, at: 0) }
    }

    /// The key for one part of a reply. A reply can have a second part, so it has its own ticks.
    static func key(chatID: String, messageID: String, part: Int = 1) -> String {
        "\(chatID)\u{1}\(messageID)\u{1}\(part)"
    }

    /// Whether a line shows as done: your tick when you changed it, otherwise what the teammate wrote.
    func isDone(_ reply: String, line: Int, written: Bool) -> Bool {
        ticks[reply]?[line] ?? written
    }

    /// Ticks or unticks a line. Going back to what the teammate wrote forgets the change.
    func toggle(_ reply: String, line: Int, written: Bool) {
        let now = !isDone(reply, line: line, written: written)
        var lines = ticks[reply] ?? [:]
        if now == written {
            lines[line] = nil
        } else {
            lines[line] = now
        }
        ticks[reply] = lines.isEmpty ? nil : lines
        order.removeAll { $0 == reply }
        if ticks[reply] != nil { order.append(reply) }
        while order.count > Self.maxReplies {
            ticks[order.removeFirst()] = nil
        }
        save()
    }

    /// How many task lines a reply has and how many show as done.
    func progress(_ blocks: [MarkdownBlock], reply: String?) -> (done: Int, total: Int) {
        var done = 0
        var total = 0
        for (index, block) in blocks.enumerated() {
            guard case .bullet(_, _, let checked) = block, let checked else { continue }
            total += 1
            let on = reply.map { isDone($0, line: index, written: checked) } ?? checked
            if on { done += 1 }
        }
        return (done, total)
    }

    /// Drops ticks for chats that are gone.
    func keepOnly(chats: Set<String>) {
        let kept = ticks.filter { reply, _ in
            chats.contains(String(reply.split(separator: "\u{1}", omittingEmptySubsequences: false).first ?? ""))
        }
        guard kept.count != ticks.count else { return }
        ticks = kept
        order = order.filter { kept[$0] != nil }
        save()
    }

    func clear() {
        guard !ticks.isEmpty else { return }
        ticks = [:]
        order = []
        save()
    }

    private func save() {
        if ticks.isEmpty {
            defaults.removeObject(forKey: Self.key)
            defaults.removeObject(forKey: Self.key + ".order")
            return
        }
        var out: [String: [String: Bool]] = [:]
        for (reply, lines) in ticks {
            out[reply] = Dictionary(uniqueKeysWithValues: lines.map { (String($0.key), $0.value) })
        }
        defaults.set(out, forKey: Self.key)
        defaults.set(order, forKey: Self.key + ".order")
    }
}
