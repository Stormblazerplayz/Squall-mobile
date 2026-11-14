import AppIntents
import Foundation

// Siri and Shortcuts. Everything here asks the paired computer for real data;
// when it can't be reached, Siri says so (and how old the saved copy is) instead of guessing.

/// Screens Siri or a Shortcut asked the app to open. Kept in UserDefaults so a request
/// made while the app was closed still opens the screen once it's up.
enum SquallIntentRequests {
    static let notification = Notification.Name("squall.intentRequest")
    private static let key = "squall.intent.pending"

    /// Asks the app to open a screen, like "call" (same names as squall:// links).
    static func post(_ route: String) {
        let defaults = UserDefaults.standard
        var pending = defaults.stringArray(forKey: key) ?? []
        pending.append(route)
        defaults.set(pending, forKey: key)
        NotificationCenter.default.post(name: notification, object: nil)
    }

    static func drain() -> [String] {
        let defaults = UserDefaults.standard
        let pending = defaults.stringArray(forKey: key) ?? []
        if !pending.isEmpty { defaults.removeObject(forKey: key) }
        return pending
    }
}

/// "Call Chief in Squall": opens the app on a voice call with Chief.
struct CallChiefIntent: AppIntent {
    static let title: LocalizedStringResource = "Call Chief"
    static let description = IntentDescription("Starts a voice call with Chief on your computer.")
    static let openAppWhenRun = true

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        SquallIntentRequests.post("call")
        return .result()
    }
}

/// "What's my team doing in Squall": says what Chief and the team are up to.
struct TeamStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "What's my team doing"
    static let description = IntentDescription("Tells you what Chief and your bots are doing, and what needs you.")
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pairing = PairingStore()
        guard let computer = pairing.computer else {
            return .result(dialog: "Squall isn't paired with your computer yet. Open Squall to pair.")
        }
        do {
            let snapshot = try await pairing.fetchState()
            return .result(dialog: "\(TeamSummary.spoken(snapshot))")
        } catch {
            let reason = (error as? PairingError)?.message ?? PairingError.cantReach.message
            if let saved = SnapshotCache.load(for: computer),
               let snapshot = try? JSONDecoder().decode(StateSnapshot.self, from: saved.data) {
                let age = saved.savedAt.formatted(.relative(presentation: .named))
                return .result(dialog: "\(computer.name) isn't answering. As of \(age): \(TeamSummary.spoken(snapshot))")
            }
            return .result(dialog: "\(reason)")
        }
    }
}

/// "Approve Chief's request in Squall": allows the OK Chief is waiting on, after you confirm.
struct ApproveChiefIntent: AppIntent {
    static let title: LocalizedStringResource = "Approve Chief's request"
    static let description = IntentDescription("Allows the OK that Chief is waiting on. Siri reads it to you and asks before sending.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let pairing = PairingStore()
        guard pairing.isPaired else {
            return .result(dialog: "Squall isn't paired with your computer yet. Open Squall to pair.")
        }
        let snapshot: StateSnapshot
        do {
            snapshot = try await pairing.fetchState()
        } catch {
            let reason = (error as? PairingError)?.message ?? PairingError.cantReach.message
            return .result(dialog: "Nothing was approved. \(reason)")
        }
        let items = snapshot.inbox.map(\.model)
        let bots = snapshot.bots.map(\.model)
        guard let item = items.first(where: { $0.kind == .ask && $0.botID == Bot.chiefID }) else {
            if let other = items.first(where: { $0.kind == .ask }) {
                let name = bots.first(where: { $0.id == other.botID })?.name ?? "A bot"
                return .result(dialog: "Chief isn't waiting on an OK. \(name) is: \(other.title). Open Squall to answer it.")
            }
            return .result(dialog: "Chief isn't waiting on an OK right now.")
        }
        var question = "Chief asks: \(item.title)."
        if let command = item.command, !command.isEmpty {
            question += " It wants to run \(command)."
        }
        question += " Allow it?"
        // Siri reads the request and waits for a yes. A no stops here and sends nothing.
        try await requestConfirmation(result: .result(dialog: "\(question)"))
        do {
            try await pairing.send(SyncAction(type: "inbox.answer", fields: [
                "itemId": .string(item.id),
                "answer": .string("allow")
            ]))
        } catch {
            let reason = (error as? SyncActionError)?.message
                ?? (error as? PairingError)?.message
                ?? PairingError.cantReach.message
            return .result(dialog: "It wasn't sent. \(reason)")
        }
        return .result(dialog: "Allowed. Chief can go ahead.")
    }
}

/// The phrases Siri knows without any setup. Each must say the app's name.
struct SquallShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: CallChiefIntent(),
            phrases: [
                "Call Chief in \(.applicationName)",
                "Call Chief with \(.applicationName)",
                "Start a \(.applicationName) call"
            ],
            shortTitle: "Call Chief",
            systemImageName: "phone.fill"
        )
        AppShortcut(
            intent: TeamStatusIntent(),
            phrases: [
                "What's my team doing in \(.applicationName)",
                "What is my \(.applicationName) team doing",
                "\(.applicationName) team status"
            ],
            shortTitle: "Team status",
            systemImageName: "person.2.fill"
        )
        AppShortcut(
            intent: ApproveChiefIntent(),
            phrases: [
                "Approve Chief's request in \(.applicationName)",
                "Approve Chief in \(.applicationName)",
                "Allow Chief's request in \(.applicationName)"
            ],
            shortTitle: "Approve Chief",
            systemImageName: "checkmark.shield.fill"
        )
    }
}

/// Turns the team into one or two sentences Siri can read out.
enum TeamSummary {
    static func spoken(_ snapshot: StateSnapshot) -> String {
        let bots = snapshot.bots.map(\.model)
        let inbox = snapshot.inbox.map(\.model)
        guard !bots.isEmpty else {
            return "Your computer didn't send any bots yet."
        }
        var parts: [String] = []
        if snapshot.paused {
            parts.append("Your team is paused.")
        }
        if let chief = bots.first(where: { $0.isChief }) {
            let task = chief.task.trimmingCharacters(in: .whitespacesAndNewlines)
            if chief.status == .working, !task.isEmpty {
                parts.append("Chief is working on \(task).")
            } else {
                parts.append("Chief is \(chief.status.label.lowercased()).")
            }
        }
        let teammates = bots.filter { !$0.isChief }
        if teammates.isEmpty {
            parts.append("There are no teammates yet.")
        } else {
            let working = teammates.filter { $0.status.isBusy }
            let names = working.prefix(3).map(\.name)
            if working.isEmpty {
                parts.append("None of your \(teammates.count) teammates are working.")
            } else if working.count == 1, let name = names.first {
                let others = teammates.count - 1
                if others == 0 {
                    parts.append("\(name) is working.")
                } else {
                    let rest = others == 1 ? "1 other teammate isn't" : "\(others) other teammates aren't"
                    parts.append("\(name) is working, and \(rest).")
                }
            } else {
                let list = ListFormatter.localizedString(byJoining: names)
                let extra = working.count > names.count ? " and \(working.count - names.count) more" : ""
                parts.append("\(list)\(extra) are working.")
            }
        }
        let waiting = inbox.filter { $0.kind.needsYou }
        if let first = waiting.first {
            let name = bots.first(where: { $0.id == first.botID })?.name ?? "A bot"
            let count = waiting.count == 1 ? "1 thing needs you" : "\(waiting.count) things need you"
            parts.append("\(count). \(name) asks: \(first.title).")
        } else {
            parts.append("Nothing needs you.")
        }
        return parts.joined(separator: " ")
    }
}
