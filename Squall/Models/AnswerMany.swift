import Foundation
import LocalAuthentication

/// Answer many OK requests at once: tick the ones you want and Allow or Deny them together. Only plain OKs are here;
/// a question with choices still needs its own answer. Each one goes to the computer the same way a single Allow does.
enum AnswerMany {
    /// The bar shows up once this many OKs are waiting.
    static let minimum = 2

    struct Group: Identifiable, Equatable {
        let botID: String
        let items: [InboxItem]
        var id: String { botID }
    }

    /// The plain OK requests waiting on you, in the Inbox's order.
    static func asks(in inbox: [InboxItem]) -> [InboxItem] {
        inbox.filter { $0.kind == .ask }
    }

    /// The asks by teammate, in the order each teammate first shows up.
    static func groups(_ asks: [InboxItem]) -> [Group] {
        var order: [String] = []
        var buckets: [String: [InboxItem]] = [:]
        for item in asks {
            if buckets[item.botID] == nil { order.append(item.botID) }
            buckets[item.botID, default: []].append(item)
        }
        return order.map { Group(botID: $0, items: buckets[$0] ?? []) }
    }

    /// The picked ids that are still waiting, in the Inbox's order.
    static func stillWaiting(_ picked: Set<String>, in inbox: [InboxItem]) -> [String] {
        asks(in: inbox).map(\.id).filter { picked.contains($0) }
    }

    /// "Allowed 3." or "Denied 1. 2 didn't go through, so they're still in the Inbox."
    static func doneText(allow: Bool, sent: Int, failed: Int) -> String {
        var parts: [String] = []
        if sent > 0 { parts.append("\(allow ? "Allowed" : "Denied") \(sent).") }
        if failed > 0 {
            parts.append(failed == 1
                         ? "1 didn't go through, so it's still in the Inbox."
                         : "\(failed) didn't go through, so they're still in the Inbox.")
        }
        return parts.isEmpty ? "Nothing was waiting anymore." : parts.joined(separator: " ")
    }

    /// The button's words, like "Allow 3".
    static func buttonTitle(allow: Bool, count: Int) -> String {
        "\(allow ? "Allow" : "Deny") \(count)"
    }

    // MARK: - Sending

    /// Answers each picked OK in turn. Ones that were answered somewhere else meanwhile are skipped.
    @MainActor
    static func run(_ ids: [String], allow: Bool, store: SquallStore,
                    progress: @escaping (Int) -> Void = { _ in }) async -> (sent: Int, failed: Int) {
        var sent = 0
        var failed = 0
        for (index, id) in ids.enumerated() {
            progress(index + 1)
            guard store.inbox.contains(where: { $0.id == id && $0.kind == .ask }) else { continue }
            guard store.isConnected else {
                failed += 1
                continue
            }
            let action = SyncAction(type: "inbox.answer", fields: [
                "itemId": .string(id),
                "answer": .string(allow ? "allow" : "deny"),
            ])
            if await store.perform(action, busyKey: "inbox.\(id)", quiet: true) != nil {
                sent += 1
                LiveActivities.shared.approvalAnswered(id, allowed: allow)
            } else {
                failed += 1
            }
        }
        if sent > 0 { Feedback.play(allow ? .approved : .denied) }
        return (sent, failed)
    }

    /// Allowing several things at once asks for Face ID, Touch ID or the passcode first, like Allow on a notification.
    /// A device with no passcode can't check, so it goes ahead.
    static func confirmAllow(count: Int) async -> Bool {
        let context = LAContext()
        context.localizedCancelTitle = "Not now"
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else { return true }
        let reason = count == 1 ? "Allow 1 request" : "Allow \(count) requests"
        return (try? await context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reason)) ?? false
    }
}
