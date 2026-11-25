import Foundation

// Words for Squall Uno's token counts and for starting a task straight from the Uno tab.
// Kept free of views so they can be tested (SquallTests/UnoQuickStartTests.swift).
//
// There's no dollar price on purpose: a session's `inputTokens` from the PC adds plain input, cache writes and
// cache reads together, and those cost different amounts, so a price worked out from the total would be wrong.

enum UnoTokens {
    /// A token count, short: 680, 1.2k, 12.3k, 123k, 1.2M.
    static func short(_ count: Int) -> String {
        let value = max(0, count)
        if value < 1000 { return "\(value)" }
        let thousandsTenths = (Double(value) / 100).rounded() / 10
        if thousandsTenths < 100 { return oneDecimal(thousandsTenths) + "k" }
        let thousands = (Double(value) / 1000).rounded()
        if thousands < 1000 { return "\(Int(thousands))k" }
        let millionsTenths = (Double(value) / 100_000).rounded() / 10
        if millionsTenths < 100 { return oneDecimal(millionsTenths) + "M" }
        return "\(Int((Double(value) / 1_000_000).rounded()))M"
    }

    /// "12.3k tokens in · 680 out", or nil before the task has used any.
    static func line(input: Int, output: Int) -> String? {
        let inCount = max(0, input)
        let outCount = max(0, output)
        guard inCount > 0 || outCount > 0 else { return nil }
        return "\(short(inCount)) tokens in · \(short(outCount)) out"
    }

    static func line(for session: UnoSession?) -> String? {
        guard let session else { return nil }
        return line(input: session.inputTokens, output: session.outputTokens)
    }

    /// "Today: 124k tokens" for the Uno tab's header, or nil before the PC sent its settings.
    static func today(_ settings: UnoSettings?) -> String? {
        guard let settings else { return nil }
        let total = max(0, settings.tokensToday.input) + max(0, settings.tokensToday.output)
        return total > 0 ? "Today: \(short(total)) tokens" : "Today: no tokens yet"
    }

    private static func oneDecimal(_ value: Double) -> String {
        value == value.rounded() ? "\(Int(value))" : String(format: "%.1f", value)
    }
}

enum UnoQuickStart {
    /// Whether a new task can start on an agent's computer, and if not, why in plain words.
    struct Check: Equatable {
        enum Kind: Equatable {
            case ready
            /// The computer is already running a task. "Tell it instead" sends to `sessionId`.
            case busy
            case needsKey
            case needsDocker
        }

        var kind: Kind
        var why: String
        var sessionId: String?

        var canStart: Bool { kind == .ready }
    }

    /// `settings` nil means the PC hasn't said yet, so the PC decides when you press Start.
    /// `running` is the session going on that computer right now, if any.
    static func check(settings: UnoSettings?, running: UnoSession?, agentName: String) -> Check {
        let name = agentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let who = name.isEmpty ? "This agent" : name
        if let running, running.isActive {
            return Check(
                kind: .busy,
                why: "\(who)'s computer is busy with a task. Tell it something instead, or stop it first.",
                sessionId: running.id
            )
        }
        if let settings {
            if !settings.hasKey {
                return Check(kind: .needsKey, why: "Squall Uno needs an Anthropic API key first. Add it in Squall Uno settings.", sessionId: nil)
            }
            if !settings.dockerReady {
                let text = settings.dockerText.trimmingCharacters(in: .whitespacesAndNewlines)
                return Check(kind: .needsDocker, why: text.isEmpty ? "Docker Desktop isn't running on your PC yet." : text, sessionId: nil)
            }
        }
        return Check(kind: .ready, why: "", sessionId: nil)
    }

    /// "Run again" is for tasks that ended (done, stopped or hit a problem) and had words.
    static func canRunAgain(_ session: UnoSession) -> Bool {
        ["done", "stopped", "error"].contains(session.state)
            && !session.task.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
