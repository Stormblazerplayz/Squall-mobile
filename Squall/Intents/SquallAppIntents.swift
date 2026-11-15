import AppIntents
import Foundation

// Siri and Shortcuts. Everything here asks the paired computer for real data;
// when it can't be reached, Siri says so (and how old the saved copy is) instead of guessing.

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

/// Turns a failed send into one sentence Siri can say.
enum SiriText {
    static func failure(_ error: Error, _ lead: String) -> String {
        let reason = (error as? SquallDirect.Failure)?.message ?? PairingError.cantReach.message
        return "\(lead) \(reason)"
    }
}

/// "Pause my team in Squall": pauses every bot on the computer.
struct PauseTeamSiriIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause my team"
    static let description = IntentDescription("Pauses every bot on your computer until you resume them.")
    static let openAppWhenRun = false

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try await SquallDirect.send("team.pause", ["paused": true])
            return .result(dialog: "Paused. Your team waits until you resume it.")
        } catch {
            return .result(dialog: "\(SiriText.failure(error, "Nothing was paused."))")
        }
    }
}

/// "Resume my team in Squall": starts every bot again.
struct ResumeTeamSiriIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume my team"
    static let description = IntentDescription("Starts every bot on your computer again after a pause.")
    static let openAppWhenRun = false

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            try await SquallDirect.send("team.pause", ["paused": false])
            return .result(dialog: "Done. Your team is back to work.")
        } catch {
            return .result(dialog: "\(SiriText.failure(error, "Your team wasn't resumed."))")
        }
    }
}

/// "Tell Chief in Squall": Siri asks what to say, then sends it to Chief's chat.
struct TellChiefIntent: AppIntent {
    static let title: LocalizedStringResource = "Tell Chief"
    static let description = IntentDescription("Sends Chief a message on your computer, like a new job for the team.")
    static let openAppWhenRun = false
    // Chief can start real work from a message, so the phone has to be unlocked.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Message", requestValueDialog: "What should I tell Chief?")
    var message: String

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let text = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return .result(dialog: "Nothing was sent to Chief.")
        }
        do {
            try await SquallDirect.send("chat.send", ["chatId": Bot.chiefID, "text": text])
            return .result(dialog: "Sent to Chief.")
        } catch {
            return .result(dialog: "\(SiriText.failure(error, "Chief didn't get it."))")
        }
    }
}

/// "What needs me in Squall": reads out what's waiting on you.
struct WhatNeedsMeIntent: AppIntent {
    static let title: LocalizedStringResource = "What needs me"
    static let description = IntentDescription("Reads out the OKs and questions your bots are waiting on.")
    static let openAppWhenRun = false

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
            return .result(dialog: "\(reason)")
        }
        return .result(dialog: "\(NeedsMeSummary.spoken(snapshot))")
    }
}

/// Turns the waiting OKs and questions into a few sentences Siri can read out.
enum NeedsMeSummary {
    static func spoken(_ snapshot: StateSnapshot) -> String {
        let bots = snapshot.bots.map(\.model)
        let waiting = snapshot.inbox.map(\.model).filter { $0.kind.needsYou }
        guard !waiting.isEmpty else {
            return "Nothing needs you right now."
        }
        var parts = [waiting.count == 1 ? "1 thing needs you." : "\(waiting.count) things need you."]
        for item in waiting.prefix(3) {
            let name = bots.first(where: { $0.id == item.botID })?.name ?? "A bot"
            switch item.kind {
            case .ask:
                parts.append("\(name) wants your OK: \(item.title).")
            default:
                parts.append("\(name) asks: \(item.title).")
            }
        }
        if waiting.count > 3 {
            parts.append("Open Squall for the rest.")
        }
        return parts.joined(separator: " ")
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
        AppShortcut(
            intent: WhatNeedsMeIntent(),
            phrases: [
                "What needs me in \(.applicationName)",
                "What's waiting in \(.applicationName)",
                "Check my \(.applicationName) inbox"
            ],
            shortTitle: "What needs me",
            systemImageName: "tray.full.fill"
        )
        AppShortcut(
            intent: TellChiefIntent(),
            phrases: [
                "Tell Chief in \(.applicationName)",
                "Send Chief a message in \(.applicationName)",
                "Give \(.applicationName) a job"
            ],
            shortTitle: "Tell Chief",
            systemImageName: "text.bubble.fill"
        )
        AppShortcut(
            intent: PauseTeamSiriIntent(),
            phrases: [
                "Pause my team in \(.applicationName)",
                "Pause my \(.applicationName) team",
                "Pause \(.applicationName)"
            ],
            shortTitle: "Pause team",
            systemImageName: "pause.circle.fill"
        )
        AppShortcut(
            intent: ResumeTeamSiriIntent(),
            phrases: [
                "Resume my team in \(.applicationName)",
                "Resume my \(.applicationName) team",
                "Resume \(.applicationName)"
            ],
            shortTitle: "Resume team",
            systemImageName: "play.circle.fill"
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
