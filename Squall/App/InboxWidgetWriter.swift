import Foundation
import WidgetKit

/// Saves what the Inbox widget draws after each real update from the computer, and reloads the widget only when
/// something it shows changed (or every 5 minutes, so it can tell the data is fresh).
@MainActor
enum InboxWidgetWriter {
    private static var last: InboxWidgetSnapshot?
    private static var lastAt: Date?

    /// What needs you first, then problems, each in the Inbox's own order. Snoozed things are left out.
    static func snapshot(inbox: [InboxItem], bots: [Bot], snoozed: (String) -> Bool, now: Date = Date()) -> InboxWidgetSnapshot {
        let awake = inbox.filter { !snoozed($0.id) }
        let needs = awake.filter { $0.kind.needsYou }
        let problems = awake.filter { $0.kind == .error }
        let items = (needs + problems).prefix(InboxWidgetSnapshot.maxItems).map { item -> InboxWidgetSnapshot.Item in
            let bot = bots.first(where: { $0.id == item.botID })
            let trimmed = item.command?.trimmingCharacters(in: .whitespacesAndNewlines)
            let command = trimmed.flatMap { $0.isEmpty ? nil : String($0.prefix(InboxWidgetSnapshot.maxTitle)) }
            return InboxWidgetSnapshot.Item(
                id: item.id,
                kind: kindKey(item.kind),
                botName: bot?.name ?? "A bot",
                hex: bot?.hex ?? 0x6D5CE8,
                title: String(item.title.prefix(InboxWidgetSnapshot.maxTitle)),
                command: command,
                time: item.time
            )
        }
        return InboxWidgetSnapshot(paired: true, syncedAt: now, needsYou: needs.count, problems: problems.count,
                                   items: Array(items))
    }

    static func kindKey(_ kind: InboxItem.Kind) -> String {
        switch kind {
        case .ask: return "ask"
        case .choice: return "choice"
        case .error: return "error"
        case .done: return "done"
        }
    }

    static func update(inbox: [InboxItem], bots: [Bot], now: Date = Date()) {
        guard !bots.isEmpty else { return }
        let snooze = InboxSnooze.shared
        let next = snapshot(inbox: inbox, bots: bots, snoozed: { snooze.isSnoozed($0, now: now) }, now: now)
        var compare = next
        compare.syncedAt = last?.syncedAt ?? now
        let changed = compare != last
        let old = now.timeIntervalSince(lastAt ?? .distantPast) > 5 * 60
        guard changed || old else { return }
        last = next
        lastAt = now
        if InboxWidgetSnapshot.save(next) {
            WidgetCenter.shared.reloadTimelines(ofKind: InboxWidgetSnapshot.kind)
        }
    }

    /// After Unpair: the widget says it isn't paired instead of showing old requests.
    static func forget() {
        last = nil
        lastAt = nil
        if InboxWidgetSnapshot.load()?.paired != false, InboxWidgetSnapshot.save(.notPaired()) {
            WidgetCenter.shared.reloadTimelines(ofKind: InboxWidgetSnapshot.kind)
        }
    }
}
