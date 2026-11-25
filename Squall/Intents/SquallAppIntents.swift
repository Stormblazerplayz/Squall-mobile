import AppIntents
import Foundation
import SwiftUI

// Siri and Shortcuts. Everything here asks the paired computer for real data and sends real
// actions; the work itself is in SiriCore.swift (`SquallSiri`), so it can be tested.
// When the computer can't be reached, Siri says so instead of guessing.

// MARK: - Ask a bot and hear its answer

/// "Ask Chief in Squall": Siri asks what to say, sends it to Chief, and reads Chief's real answer.
struct AskChiefIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask Chief"
    static let description = IntentDescription("Asks Chief something on your computer and reads you Chief's answer.")
    static let openAppWhenRun = false
    // Chief can start real work from a message, so the phone has to be unlocked.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Question", requestValueDialog: "What should I ask Chief?")
    var question: String

    init() {}

    init(question: String) {
        self.question = question
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Ask Chief \(\.$question)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let answer = await SquallSiri(link: PairingLink()).ask(botID: Bot.chiefID, question: question)
        return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
    }
}

/// "Ask Builder in Squall": Siri asks which bot (if you didn't say) and what to ask, then reads the answer.
struct AskBotIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask a bot"
    static let description = IntentDescription("Asks one of your bots something and reads you its answer.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Bot", requestValueDialog: "Which bot?")
    var bot: BotEntity

    @Parameter(title: "Question", requestValueDialog: "What should I ask?")
    var question: String

    init() {}

    init(bot: BotEntity, question: String) {
        self.bot = bot
        self.question = question
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Ask \(\.$bot) \(\.$question)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let answer = await SquallSiri(link: PairingLink()).ask(botID: bot.id, question: question)
        return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
    }
}

// MARK: - Give a bot a job

/// "Start a task in Squall": Siri asks for the job and sends it to Chief, or to the bot you pick.
struct StartTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "Start a task"
    static let description = IntentDescription("Gives Chief, or the bot you pick, a new job on your computer.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Job", requestValueDialog: "What's the job?")
    var job: String

    @Parameter(title: "Bot", description: "Who does it. Chief does it when you don't pick anyone.")
    var bot: BotEntity?

    init() {}

    init(job: String, bot: BotEntity? = nil) {
        self.job = job
        self.bot = bot
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Give \(\.$job) to \(\.$bot)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let answer = await SquallSiri(link: PairingLink()).startTask(botID: bot?.id, job: job)
        return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
    }
}

/// The older "Tell Chief" action, kept so Shortcuts people already made keep working.
struct TellChiefIntent: AppIntent {
    static let title: LocalizedStringResource = "Tell Chief"
    static let description = IntentDescription("Sends Chief a message on your computer, like a new job for the team.")
    static let openAppWhenRun = false
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Message", requestValueDialog: "What should I tell Chief?")
    var message: String

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let answer = await SquallSiri(link: PairingLink()).startTask(botID: Bot.chiefID, job: message)
        return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
    }
}

// MARK: - The To do list

/// "Add to my To do list" in Shortcuts: puts something on Squall's shared To do list,
/// and gives it to a bot right away if you pick one.
struct AddTodoIntent: AppIntent {
    static let title: LocalizedStringResource = "Add to my To do list"
    static let description = IntentDescription("Adds something to Squall's To do list on your computer. Pick a bot to have it start right away.")
    static let openAppWhenRun = false
    // Giving it to a bot can start real work, so the phone has to be unlocked.
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "To-do", requestValueDialog: "What should I add?")
    var text: String

    @Parameter(title: "Bot", description: "Who does it now. Nobody starts it when you don't pick anyone.")
    var bot: BotEntity?

    init() {}

    init(text: String, bot: BotEntity? = nil) {
        self.text = text
        self.bot = bot
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Add \(\.$text) to my To do list") {
            \.$bot
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let answer = await SquallSiri(link: PairingLink()).addTodo(text, botID: bot?.id)
        return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
    }
}

/// "What's on my To do list" in Shortcuts: reads out the shared list.
struct TodoListIntent: AppIntent {
    static let title: LocalizedStringResource = "What's on my To do list"
    static let description = IntentDescription("Tells you what's on Squall's To do list: what needs you, what's being done and what's next.")
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let answer = await SquallSiri(link: PairingLink()).todoList()
        return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
    }
}

// MARK: - What's going on

/// "What's my team doing in Squall": says what Chief and the team are up to.
struct TeamStatusIntent: AppIntent {
    static let title: LocalizedStringResource = "What's my team doing"
    static let description = IntentDescription("Tells you what Chief and your bots are doing, and what needs you.")
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let answer = await SquallSiri(link: PairingLink()).teamStatus()
        return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
    }
}

/// "What needs me in Squall": reads out what's waiting on you.
struct WhatNeedsMeIntent: AppIntent {
    static let title: LocalizedStringResource = "What needs me"
    static let description = IntentDescription("Reads out the OKs and questions your bots are waiting on.")
    static let openAppWhenRun = false

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let answer = await SquallSiri(link: PairingLink()).whatNeedsMe()
        return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
    }
}

// MARK: - Allow and Deny

/// Shared by Approve and Decline: find the request, read it out, wait for a yes, then send the answer.
@MainActor
enum RequestAnswerFlow {
    static func run<Intent: AppIntent>(_ intent: Intent, botID: String?, allow: Bool) async throws -> SiriAnswer {
        let siri = SquallSiri(link: PairingLink())
        switch await siri.prepareAnswer(botID: botID, allow: allow) {
        case .nothing(let answer):
            return answer
        case .ready(let row, let question):
            // Siri reads the request and waits for a yes. A no stops here and sends nothing.
            try await intent.requestConfirmation(
                result: .result(dialog: "\(question)", view: SiriSnippetView(snippet: .request(row, answer: nil)))
            )
            return await siri.answer(row, allow: allow)
        }
    }
}

/// "Approve a request in Squall": allows the OK a bot is waiting on, after you confirm.
struct ApproveRequestIntent: AppIntent {
    static let title: LocalizedStringResource = "Approve a request"
    static let description = IntentDescription("Allows the OK a bot is waiting on. Reads it to you and asks before sending.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Bot", description: "Whose request. The first one waiting when you don't pick.")
    var bot: BotEntity?

    init() {}

    init(bot: BotEntity?) {
        self.bot = bot
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Approve the request from \(\.$bot)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let answer = try await RequestAnswerFlow.run(self, botID: bot?.id, allow: true)
        return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
    }
}

/// "Decline a request in Squall": denies the OK a bot is waiting on, after you confirm.
struct DeclineRequestIntent: AppIntent {
    static let title: LocalizedStringResource = "Decline a request"
    static let description = IntentDescription("Denies the OK a bot is waiting on. Reads it to you and asks before sending.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Bot", description: "Whose request. The first one waiting when you don't pick.")
    var bot: BotEntity?

    init() {}

    init(bot: BotEntity?) {
        self.bot = bot
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Decline the request from \(\.$bot)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let answer = try await RequestAnswerFlow.run(self, botID: bot?.id, allow: false)
        return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
    }
}

/// The older "Approve Chief's request" action, kept so Shortcuts people already made keep working.
struct ApproveChiefIntent: AppIntent {
    static let title: LocalizedStringResource = "Approve Chief's request"
    static let description = IntentDescription("Allows the OK that Chief is waiting on. Reads it to you and asks before sending.")
    static let openAppWhenRun = false
    static let isDiscoverable = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let answer = try await RequestAnswerFlow.run(self, botID: Bot.chiefID, allow: true)
        return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
    }
}

// MARK: - Calls and the whole team

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

/// Turns a failed send into one sentence Siri can say.
enum SiriText {
    static func failure(_ error: Error, _ lead: String) -> String {
        "\(lead) \(SquallSiri.reason(error))"
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

// MARK: - Phrases

/// The phrases Siri knows without any setup. Each must say the app's name.
/// Apple allows 10 of these per app, and Squall uses all 10.
struct SquallShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: AskChiefIntent(),
            phrases: [
                "Ask Chief in \(.applicationName)",
                "Ask Chief something in \(.applicationName)",
                "Ask Chief a question in \(.applicationName)"
            ],
            shortTitle: "Ask Chief",
            systemImageName: "bolt.fill"
        )
        AppShortcut(
            intent: AskBotIntent(),
            phrases: [
                "Ask \(\.$bot) in \(.applicationName)",
                "Ask \(\.$bot) something in \(.applicationName)",
                "Ask a bot in \(.applicationName)",
                "Ask my \(.applicationName) bot"
            ],
            shortTitle: "Ask a bot",
            systemImageName: "bubble.left.and.text.bubble.right.fill"
        )
        AppShortcut(
            intent: StartTaskIntent(),
            phrases: [
                "Start a task in \(.applicationName)",
                "Start a \(.applicationName) task",
                "Give \(.applicationName) a job",
                "Tell Chief in \(.applicationName)"
            ],
            shortTitle: "Start a task",
            systemImageName: "plus.bubble.fill"
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
            intent: ApproveRequestIntent(),
            phrases: [
                "Approve a request in \(.applicationName)",
                "Approve the request in \(.applicationName)",
                "Allow the request in \(.applicationName)"
            ],
            shortTitle: "Approve",
            systemImageName: "checkmark.shield.fill"
        )
        AppShortcut(
            intent: DeclineRequestIntent(),
            phrases: [
                "Decline a request in \(.applicationName)",
                "Decline the request in \(.applicationName)",
                "Deny the request in \(.applicationName)"
            ],
            shortTitle: "Decline",
            systemImageName: "xmark.shield.fill"
        )
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
