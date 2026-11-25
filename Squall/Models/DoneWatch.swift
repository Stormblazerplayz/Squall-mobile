import Combine
import Foundation
import UserNotifications

/// "Tell me when Rex is done": a one-time watch on a busy teammate. When that teammate stops working,
/// the phone pings once and the watch goes away. Watches are kept on the phone, so they last if the app is closed,
/// and the ping comes the next time Squall gets the team from the computer.
final class DoneWatch: ObservableObject {
    static let shared = DoneWatch()
    static let key = "squall.doneWatch"

    /// The ping for a teammate who stopped working.
    struct Ping: Equatable {
        let botID: String
        let title: String
        let body: String
        let subtitle: String
    }

    /// The teammates being watched, by bot id.
    @Published private(set) var watching: Set<String>

    private let defaults: UserDefaults
    private let sendsPings: Bool

    init(defaults: UserDefaults = .standard, sendsPings: Bool = true) {
        self.defaults = defaults
        self.sendsPings = sendsPings
        watching = Set(defaults.stringArray(forKey: Self.key) ?? [])
    }

    // MARK: - Watching

    func isWatching(_ botID: String) -> Bool { watching.contains(botID) }

    /// Only a teammate who is working right now can be watched. Returns false when there's nothing to wait for.
    @discardableResult
    func watch(_ bot: Bot) -> Bool {
        guard Self.canWatch(bot) else { return false }
        if watching.insert(bot.id).inserted { save() }
        return true
    }

    func stop(_ botID: String) {
        if watching.remove(botID) != nil { save() }
    }

    static func canWatch(_ bot: Bot) -> Bool { bot.status == .working }

    // MARK: - Updates from the computer

    /// Pings for every watched teammate who stopped working, and ends those watches.
    /// A teammate who was removed from the team is dropped without a ping.
    @discardableResult
    func update(bots: [Bot]) -> [Ping] {
        guard !watching.isEmpty, !bots.isEmpty else { return [] }
        let result = Self.check(watching: watching, bots: bots)
        guard result.keep != watching else { return [] }
        watching = result.keep
        save()
        for ping in result.pings { send(ping) }
        return result.pings
    }

    /// The pure part of `update`: which watches end with a ping, and which stay.
    static func check(watching: Set<String>, bots: [Bot]) -> (pings: [Ping], keep: Set<String>) {
        var pings: [Ping] = []
        var keep = Set<String>()
        for bot in bots where watching.contains(bot.id) {
            if bot.status == .working {
                keep.insert(bot.id)
            } else {
                pings.append(ping(for: bot))
            }
        }
        return (pings, keep)
    }

    static func ping(for bot: Bot) -> Ping {
        let name = bot.name
        let title: String
        let body: String
        switch bot.status {
        case .working, .idle:
            title = "\(name) is done"
            body = "\(name) finished and is free for something new."
        case .napping:
            title = "\(name) is done"
            body = "\(name) finished and is taking a nap."
        case .waiting:
            title = "\(name) needs you"
            body = "\(name) stopped and is waiting for you."
        case .handed:
            title = "\(name) handed it on"
            body = "\(name) passed the work to Chief."
        case .paused:
            title = "\(name) was paused"
            body = "\(name) stopped because the team is paused."
        }
        let task = bot.task.trimmingCharacters(in: .whitespacesAndNewlines)
        return Ping(botID: bot.id, title: title, body: body, subtitle: task)
    }

    /// The menu words for a teammate.
    static func menuTitle(for bot: Bot, watching: Bool) -> String {
        watching ? "Stop waiting on \(bot.name)" : "Tell me when \(bot.name) is done"
    }

    // MARK: - Keeping it tidy

    /// Drops watches for teammates who left the team.
    func keepOnly(_ botIDs: Set<String>) {
        let kept = watching.intersection(botIDs)
        if kept != watching {
            watching = kept
            save()
        }
    }

    func clear() {
        guard !watching.isEmpty else { return }
        watching = []
        save()
    }

    // MARK: - Private

    private func save() {
        if watching.isEmpty {
            defaults.removeObject(forKey: Self.key)
        } else {
            defaults.set(watching.sorted(), forKey: Self.key)
        }
    }

    private func send(_ ping: Ping) {
        guard sendsPings else { return }
        let content = UNMutableNotificationContent()
        content.title = ping.title
        content.subtitle = ping.subtitle
        content.body = ping.body
        content.threadIdentifier = ping.botID
        content.userInfo = [AlertIDs.routeKey: "chat/\(ping.botID)"]
        if FocusRules.current.silent {
            content.interruptionLevel = .passive
        } else {
            content.sound = .default
        }
        let request = UNNotificationRequest(identifier: "squall.done.\(ping.botID).\(UUID().uuidString)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }
}
