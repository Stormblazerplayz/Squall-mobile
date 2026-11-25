import Foundation
import WidgetKit

/// Saves what the Teammate widget draws after each real update from the computer, and reloads the widget only when
/// something it shows changed (or every 5 minutes, so it can tell the data is fresh).
@MainActor
enum TeammateWidgetWriter {
    private static var last: TeammateWidgetSnapshot?
    private static var lastAt: Date?

    /// The widget's data from the computer's chats and the team.
    static func snapshot(chats: [String: [MessageDTO]], bots: [Bot], now: Date = Date()) -> TeammateWidgetSnapshot {
        let order = bots.filter(\.isChief) + bots.filter { !$0.isChief }
        let teammates = order.map { bot -> TeammateWidgetSnapshot.Teammate in
            let last = lastMessage(in: chats[bot.id] ?? [])
            return TeammateWidgetSnapshot.Teammate(
                id: bot.id,
                name: bot.name,
                hex: bot.hex,
                status: statusKey(bot.status),
                statusLabel: bot.status.label,
                task: bot.task,
                isChief: bot.isChief,
                lastText: last?.text,
                lastFromMe: last?.fromMe ?? false,
                lastTime: last?.time ?? ""
            )
        }
        return TeammateWidgetSnapshot(paired: true, syncedAt: now, teammates: teammates)
    }

    /// The newest message from you or the teammate that has words, in plain words.
    static func lastMessage(in list: [MessageDTO]) -> (text: String, fromMe: Bool, time: String)? {
        for message in list.reversed() {
            let kind = message.kind ?? "bot"
            guard kind == "me" || kind == "bot" else { continue }
            let words = ReplyAlerts.clean([message.text, message.text2].compactMap { $0 }.joined(separator: " "))
            guard !words.isEmpty else { continue }
            let text = words.count > TeammateWidgetSnapshot.maxText
                ? String(words.prefix(TeammateWidgetSnapshot.maxText - 1)).trimmingCharacters(in: .whitespaces) + "…"
                : words
            return (text, kind == "me", SyncText.clock(at: message.at, fallback: message.time))
        }
        return nil
    }

    static func statusKey(_ status: BotStatus) -> String {
        switch status {
        case .working: return "working"
        case .idle: return "idle"
        case .napping: return "napping"
        case .waiting: return "waiting"
        case .handed: return "handed"
        case .paused: return "paused"
        }
    }

    static func update(chats: [String: [MessageDTO]], bots: [Bot], now: Date = Date()) {
        guard !bots.isEmpty else { return }
        let next = snapshot(chats: chats, bots: bots, now: now)
        var compare = next
        compare.syncedAt = last?.syncedAt ?? now
        let changed = compare != last
        let old = now.timeIntervalSince(lastAt ?? .distantPast) > 5 * 60
        guard changed || old else { return }
        last = next
        lastAt = now
        if TeammateWidgetSnapshot.save(next) {
            WidgetCenter.shared.reloadTimelines(ofKind: TeammateWidgetSnapshot.kind)
        }
    }

    /// After Unpair: the widget says it isn't paired instead of showing an old team.
    static func forget() {
        last = nil
        lastAt = nil
        if TeammateWidgetSnapshot.load()?.paired != false, TeammateWidgetSnapshot.save(.notPaired()) {
            WidgetCenter.shared.reloadTimelines(ofKind: TeammateWidgetSnapshot.kind)
        }
    }
}
