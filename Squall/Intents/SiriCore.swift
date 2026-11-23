import Foundation

// The brain behind Siri and Shortcuts. The intents in SquallAppIntents.swift are thin:
// they hand their job to `SquallSiri`, which talks to the paired computer through a
// `SiriLink` and returns what Siri says plus what its card shows.
// Everything comes from the computer. When it can't be reached, Siri says so plainly.

// MARK: - The connection

/// What Siri needs from the paired computer. The app uses `PairingLink`; tests use their own.
@MainActor
protocol SiriLink: AnyObject {
    var isPaired: Bool { get }
    var computerName: String? { get }
    /// A fresh copy of everything from GET /api/v1/state.
    func fetchState() async throws -> StateSnapshot
    /// One action to POST /api/v1/action.
    func send(_ action: SyncAction) async throws
    /// The last real copy saved on the phone, for when the computer isn't answering.
    func savedState() -> (snapshot: StateSnapshot, savedAt: Date)?
}

/// The real connection: the app's own pairing with the computer.
@MainActor
final class PairingLink: SiriLink {
    private let pairing: PairingStore

    init(pairing: PairingStore? = nil) {
        self.pairing = pairing ?? PairingStore()
    }

    var isPaired: Bool { pairing.isPaired }
    var computerName: String? { pairing.computer?.name }

    func fetchState() async throws -> StateSnapshot {
        try await pairing.fetchState()
    }

    func send(_ action: SyncAction) async throws {
        try await pairing.send(action)
    }

    func savedState() -> (snapshot: StateSnapshot, savedAt: Date)? {
        guard let computer = pairing.computer,
              let saved = SnapshotCache.load(for: computer),
              let snapshot = try? JSONDecoder().decode(StateSnapshot.self, from: saved.data) else { return nil }
        return (snapshot, saved.savedAt)
    }
}

// MARK: - What Siri says and shows

/// One bot, the way Siri's card draws it.
struct SiriBotRow: Equatable, Identifiable {
    let id: String
    var name: String
    var hex: UInt32
    var status: BotStatus
    var task: String

    init(_ bot: Bot) {
        id = bot.id
        name = bot.name
        hex = bot.hex
        status = bot.status
        task = bot.task.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// One OK or question a bot is waiting on.
struct SiriRequestRow: Equatable, Identifiable {
    let id: String
    var bot: SiriBotRow?
    var botName: String
    var title: String
    var command: String?
    var isChoice: Bool
}

/// What Siri's card shows under the words.
enum SiriSnippet: Equatable {
    /// A short heads-up, like "Not connected to your computer".
    case notice(title: String, detail: String, symbol: String)
    /// A bot's answer to what you asked. `finished` is false when it was still going.
    case reply(bot: SiriBotRow, asked: String, text: String, finished: Bool)
    /// A message or job that went to a bot.
    case sent(bot: SiriBotRow, text: String)
    /// The whole team. `savedAt` is set when it's the saved copy.
    case team(bots: [SiriBotRow], paused: Bool, needsYou: Int, savedAt: Date?)
    /// What's waiting on you.
    case waiting([SiriRequestRow], more: Int)
    /// One request, before or after you answered it.
    case request(SiriRequestRow, answer: String?)
}

/// Siri's words plus its card.
struct SiriAnswer: Equatable {
    var spoken: String
    var snippet: SiriSnippet
}

/// Where an Allow or Deny stands before Siri asks you to confirm it.
enum SiriRequestPrep: Equatable {
    /// Found one. Siri reads `question` and waits for your yes.
    case ready(SiriRequestRow, question: String)
    /// Nothing to confirm: Siri just says this.
    case nothing(SiriAnswer)
}

// MARK: - The brain

@MainActor
struct SquallSiri {
    let link: SiriLink
    /// How often to look for a bot's answer, and for how long, after asking it something.
    var pollEvery: Duration = .milliseconds(1200)
    var waitFor: Duration = .seconds(24)

    init(link: SiriLink, pollEvery: Duration = .milliseconds(1200), waitFor: Duration = .seconds(24)) {
        self.link = link
        self.pollEvery = pollEvery
        self.waitFor = waitFor
    }

    static let notPairedText = "Squall isn't paired with your computer yet. Open Squall to pair."

    static func notPaired() -> SiriAnswer {
        SiriAnswer(spoken: notPairedText,
                   snippet: .notice(title: "Not paired", detail: "Open Squall to pair with your computer.", symbol: "link.badge.plus"))
    }

    /// The plain words for anything that went wrong talking to the computer.
    nonisolated static func reason(_ error: Error) -> String {
        if let error = error as? PairingError { return error.message }
        if let error = error as? SyncActionError { return error.message }
        if let error = error as? SquallDirect.Failure { return error.message }
        return PairingError.cantReach.message
    }

    private func unreachable(_ lead: String, _ error: Error) -> SiriAnswer {
        let reason = Self.reason(error)
        let spoken = lead.isEmpty ? reason : "\(lead) \(reason)"
        let name = link.computerName ?? "your computer"
        return SiriAnswer(spoken: spoken,
                          snippet: .notice(title: "Can't reach \(name)", detail: reason, symbol: "wifi.exclamationmark"))
    }

    private func missingBot(_ botID: String) -> SiriAnswer {
        let who = botID == Bot.chiefID ? "Chief isn't" : "That bot isn't"
        return SiriAnswer(spoken: "\(who) on your computer right now.",
                          snippet: .notice(title: "Bot not found", detail: "\(who) on your computer right now.", symbol: "person.crop.circle.badge.questionmark"))
    }

    // MARK: Ask a bot and hear the answer

    /// Sends `question` to a bot's chat, then waits for the bot's real reply and returns it.
    func ask(botID: String, question raw: String) async -> SiriAnswer {
        let question = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty else {
            return SiriAnswer(spoken: "Nothing was sent.", snippet: .notice(title: "Nothing sent", detail: "There was nothing to ask.", symbol: "text.bubble"))
        }
        guard link.isPaired else { return Self.notPaired() }

        let before: StateSnapshot
        do {
            before = try await link.fetchState()
        } catch {
            return unreachable("Nothing was sent.", error)
        }
        guard let bot = before.bots.map(\.model).first(where: { $0.id == botID }) else {
            return missingBot(botID)
        }
        let row = SiriBotRow(bot)
        let known = Set(SiriReplyReader.ids(in: before.chats[botID] ?? []))

        do {
            try await link.send(SyncAction(type: "chat.send", fields: [
                "chatId": .string(botID),
                "text": .string(question)
            ]))
        } catch {
            return unreachable("\(bot.name) didn't get it.", error)
        }

        // Look for the answer until it's done, or until Siri can't wait any longer.
        var lastText = ""
        var latest: SiriReplyReader.Reply?
        var elapsed: Duration = .zero
        while elapsed < waitFor {
            try? await Task.sleep(for: pollEvery)
            elapsed += max(pollEvery, .milliseconds(1))
            guard let state = try? await link.fetchState() else { continue }
            let reply = SiriReplyReader.reply(from: botID, to: question, in: state, known: known)
            latest = reply
            guard let reply, !reply.text.isEmpty else { continue }
            if reply.problem {
                let spoken = "\(bot.name) hit a problem: \(SiriSpeech.speakable(reply.text))"
                return SiriAnswer(spoken: spoken, snippet: .reply(bot: row, asked: question, text: SiriSpeech.card(reply.text), finished: true))
            }
            if !reply.stillWriting, reply.text == lastText {
                return SiriAnswer(spoken: SiriSpeech.speakable(reply.text),
                                  snippet: .reply(bot: row, asked: question, text: SiriSpeech.card(reply.text), finished: true))
            }
            lastText = reply.text
        }

        if let latest, !latest.text.isEmpty {
            let spoken = "\(SiriSpeech.speakable(latest.text, limit: 400)) \(bot.name) is still going. The rest will be in your chat in Squall."
            return SiriAnswer(spoken: spoken, snippet: .reply(bot: row, asked: question, text: SiriSpeech.card(latest.text), finished: false))
        }
        return SiriAnswer(spoken: "\(bot.name) got it and is still thinking. The answer will be in your chat with \(bot.name) in Squall.",
                          snippet: .reply(bot: row, asked: question, text: "", finished: false))
    }

    // MARK: Give a bot a job

    /// Sends a job to a bot (Chief when `botID` is nil) without waiting for an answer.
    func startTask(botID rawBot: String?, job raw: String) async -> SiriAnswer {
        let job = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !job.isEmpty else {
            return SiriAnswer(spoken: "Nothing was sent.", snippet: .notice(title: "Nothing sent", detail: "There was no job to send.", symbol: "text.bubble"))
        }
        guard link.isPaired else { return Self.notPaired() }
        let botID = rawBot ?? Bot.chiefID
        let state: StateSnapshot
        do {
            state = try await link.fetchState()
        } catch {
            return unreachable("No job was sent.", error)
        }
        guard let bot = state.bots.map(\.model).first(where: { $0.id == botID }) else {
            return missingBot(botID)
        }
        do {
            try await link.send(SyncAction(type: "chat.send", fields: [
                "chatId": .string(botID),
                "text": .string(job)
            ]))
        } catch {
            return unreachable("\(bot.name) didn't get the job.", error)
        }
        var spoken = "Sent. \(bot.name) has the job."
        if state.paused { spoken += " Your team is paused, so it starts once you resume it." }
        return SiriAnswer(spoken: spoken, snippet: .sent(bot: SiriBotRow(bot), text: job))
    }

    // MARK: Team status

    func teamStatus() async -> SiriAnswer {
        guard link.isPaired else { return Self.notPaired() }
        do {
            let state = try await link.fetchState()
            return SiriAnswer(spoken: TeamSummary.spoken(state), snippet: Self.teamCard(state, savedAt: nil))
        } catch {
            if let saved = link.savedState() {
                let age = saved.savedAt.formatted(.relative(presentation: .named))
                let name = link.computerName ?? "Your computer"
                return SiriAnswer(spoken: "\(name) isn't answering. As of \(age): \(TeamSummary.spoken(saved.snapshot))",
                                  snippet: Self.teamCard(saved.snapshot, savedAt: saved.savedAt))
            }
            return unreachable("", error)
        }
    }

    static func teamCard(_ state: StateSnapshot, savedAt: Date?) -> SiriSnippet {
        let bots = state.bots.map(\.model).sorted { $0.isChief && !$1.isChief }
        let waiting = state.inbox.map(\.model).filter { $0.kind.needsYou }.count
        return .team(bots: bots.map(SiriBotRow.init), paused: state.paused, needsYou: waiting, savedAt: savedAt)
    }

    // MARK: What needs me

    func whatNeedsMe() async -> SiriAnswer {
        guard link.isPaired else { return Self.notPaired() }
        let state: StateSnapshot
        do {
            state = try await link.fetchState()
        } catch {
            return unreachable("", error)
        }
        let rows = Self.requestRows(state)
        let shown = Array(rows.prefix(3))
        return SiriAnswer(spoken: NeedsMeSummary.spoken(state), snippet: .waiting(shown, more: rows.count - shown.count))
    }

    static func requestRows(_ state: StateSnapshot) -> [SiriRequestRow] {
        let bots = state.bots.map(\.model)
        return state.inbox.map(\.model).filter { $0.kind.needsYou }.map { item in
            let bot = bots.first(where: { $0.id == item.botID })
            var isChoice = false
            if case .choice = item.kind { isChoice = true }
            let command = item.command?.trimmingCharacters(in: .whitespacesAndNewlines)
            return SiriRequestRow(
                id: item.id,
                bot: bot.map(SiriBotRow.init),
                botName: bot?.name ?? "A bot",
                title: item.title,
                command: (command?.isEmpty ?? true) ? nil : command,
                isChoice: isChoice
            )
        }
    }

    // MARK: Allow or Deny

    /// Finds the OK to answer: the first one from `botID`, or the first one from anyone when it's nil.
    func prepareAnswer(botID: String?, allow: Bool) async -> SiriRequestPrep {
        let verb = allow ? "allowed" : "denied"
        guard link.isPaired else { return .nothing(Self.notPaired()) }
        let state: StateSnapshot
        do {
            state = try await link.fetchState()
        } catch {
            return .nothing(unreachable("Nothing was \(verb).", error))
        }
        let rows = Self.requestRows(state)
        let botName = botID.flatMap { id in state.bots.map(\.model).first(where: { $0.id == id })?.name }
        let mine = botID.map { id in rows.filter { $0.bot?.id == id } } ?? rows
        if let botID, botName == nil {
            return .nothing(missingBot(botID))
        }
        guard let first = mine.first(where: { !$0.isChoice }) else {
            let who = botName.map { "\($0) isn't" } ?? "No bot is"
            if let choice = mine.first(where: \.isChoice) {
                let text = "\(choice.botName) asked a question with choices: \(Self.sentence(choice.title)) Open Squall to pick an answer."
                return .nothing(SiriAnswer(spoken: text, snippet: .request(choice, answer: nil)))
            }
            if let other = rows.first(where: { !$0.isChoice }) {
                let text = "\(who) waiting on an OK. \(other.botName) is: \(Self.sentence(other.title)) Ask me to approve \(other.botName)'s request to answer it."
                return .nothing(SiriAnswer(spoken: text, snippet: .request(other, answer: nil)))
            }
            let text = "\(who) waiting on an OK right now."
            return .nothing(SiriAnswer(spoken: text, snippet: .notice(title: "Nothing waiting", detail: text, symbol: "checkmark.circle")))
        }
        return .ready(first, question: Self.question(for: first, allow: allow))
    }

    /// Ends a title with a full stop unless it already ends like a sentence.
    static func sentence(_ raw: String) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let last = text.last else { return "" }
        return ".?!".contains(last) ? text : text + "."
    }

    /// "Builder wants to run a command. The command is npm test. Allow it?"
    static func question(for row: SiriRequestRow, allow: Bool) -> String {
        let title = row.title.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ".?!")))
        var text: String
        if title.isEmpty {
            text = "\(row.botName) is waiting on your OK"
        } else if title.lowercased().hasPrefix(row.botName.lowercased()) {
            text = title
        } else {
            text = "\(row.botName) asks: \(title)"
        }
        if let command = row.command {
            let short = command.count > 120 ? String(command.prefix(120)) + "…" : command
            text += ". The command is \(short)"
        }
        return text + (allow ? ". Allow it?" : ". Deny it?")
    }

    /// Sends your Allow or Deny for a request you just confirmed.
    func answer(_ row: SiriRequestRow, allow: Bool) async -> SiriAnswer {
        guard link.isPaired else { return Self.notPaired() }
        do {
            try await link.send(SyncAction(type: "inbox.answer", fields: [
                "itemId": .string(row.id),
                "answer": .string(allow ? "allow" : "deny")
            ]))
        } catch {
            return unreachable("It wasn't sent.", error)
        }
        let spoken = allow ? "Allowed. \(row.botName) can go ahead." : "Denied. \(row.botName) won't do it."
        return SiriAnswer(spoken: spoken, snippet: .request(row, answer: allow ? "Allowed" : "Denied"))
    }
}

// MARK: - Reading a bot's reply

enum SiriReplyReader {
    struct Reply: Equatable {
        var text: String
        /// The bot is still typing or busy, so more may come.
        var stillWriting: Bool
        /// The reply is an error message from the computer.
        var problem: Bool
    }

    /// Stable keys for the messages in a chat. The computer always sends ids; the index is a backup.
    static func ids(in list: [MessageDTO]) -> [String] {
        list.enumerated().map { index, message in
            message.id ?? "\(index):\(message.text ?? "")"
        }
    }

    /// The bot's answer to `question`: its messages after the one you sent.
    static func reply(from botID: String, to question: String, in state: StateSnapshot, known: Set<String>) -> Reply? {
        let list = state.chats[botID] ?? []
        let keys = ids(in: list)
        // Best: everything after your new message. Backup: anything new since you asked.
        // An older message with the same words doesn't count, so an old answer is never read out.
        var start: Int?
        for index in list.indices.reversed() where !known.contains(keys[index]) {
            let message = list[index]
            if message.kind == "me",
               (message.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) == question {
                start = index + 1
                break
            }
        }
        let candidates: [MessageDTO]
        if let start {
            candidates = Array(list[start...])
        } else {
            candidates = zip(list, keys).filter { !known.contains($0.1) }.map(\.0)
        }
        let answers = candidates.filter { message in
            let kind = message.kind ?? "bot"
            guard kind == "bot" || kind == "error" else { return false }
            if let author = message.author, !author.isEmpty, author != botID { return false }
            return !(message.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        let bot = state.bots.first(where: { $0.id == botID })
        let busy = state.typing == botID || SyncText.status(bot?.status) == .working
        guard !answers.isEmpty else {
            return busy ? Reply(text: "", stillWriting: true, problem: false) : nil
        }
        let text = answers.map { ($0.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines) }.joined(separator: "\n\n")
        let problem = answers.allSatisfy { $0.kind == "error" }
        return Reply(text: text, stillWriting: busy, problem: problem)
    }
}

// MARK: - Words Siri can say

enum SiriSpeech {
    /// What a bot wrote, made speakable: no code blocks, links or markdown, and not too long.
    static func speakable(_ raw: String, limit: Int = 600) -> String {
        var text = raw
        text = text.replacingOccurrences(of: "```[\\s\\S]*?```", with: " (I put the code in the chat.) ", options: .regularExpression)
        text = text.replacingOccurrences(of: "`([^`]+)`", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: "https?://\\S+", with: "a link", options: .regularExpression)
        text = text.replacingOccurrences(of: "(?m)^\\s*([-•*]|\\d+[.)])\\s+", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "[*_#>~|]+", with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > limit else { return text }
        let cut = String(text.prefix(limit))
        let ends = [". ", "! ", "? "].compactMap { cut.range(of: $0, options: .backwards)?.lowerBound }
        if let end = ends.max(), cut.distance(from: cut.startIndex, to: end) > limit / 3 {
            return String(cut[...end]) + " The rest is in the chat."
        }
        return cut + "… The rest is in the chat."
    }

    /// What the card shows: the bot's own words, trimmed to fit.
    static func card(_ raw: String, limit: Int = 900) -> String {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard text.count > limit else { return text }
        return String(text.prefix(limit)) + "…"
    }
}

// MARK: - Finding a bot by name

enum BotMatcher {
    /// Lowercase, no accents, letters and digits only.
    static func normalize(_ text: String) -> String {
        let folded = text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: .current)
        let kept = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(kept).split(separator: " ").joined(separator: " ")
    }

    /// The bots whose name (or id) fits what was said, best first.
    static func matches(_ spoken: String, in bots: [Bot]) -> [Bot] {
        let target = normalize(spoken)
        guard !target.isEmpty else { return [] }
        var scored: [(Int, Bot)] = []
        for bot in bots {
            let name = normalize(bot.name)
            let id = normalize(bot.id)
            let score: Int
            if name == target || id == target {
                score = 3
            } else if name.hasPrefix(target) || target.hasPrefix(name) {
                score = 2
            } else if name.contains(target) || target.contains(name) || id.contains(target) {
                score = 1
            } else if bot.isChief, target.contains("chief") || target.contains("lead") {
                score = 1
            } else {
                continue
            }
            scored.append((score, bot))
        }
        return scored.sorted { $0.0 > $1.0 }.map(\.1)
    }
}

// MARK: - Spoken summaries

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
                parts.append(teammates.count == 1 ? "Your 1 teammate isn't working." : "None of your \(teammates.count) teammates are working.")
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
