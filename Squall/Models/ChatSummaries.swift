import Foundation

/// Summaries and Catch up (squall-computer docs/phone-summaries.md): the computer writes a short version of a long teammate
/// message, or of a chat's latest messages. The phone asks with an action, and the answer comes in the next state: the
/// message's `summary`, and `summaries { jobs, catchUps }`.
enum ChatSummaries {
    /// Only teammate messages at least this long get a Summary button, the same as on the computer.
    static let minLength = 500
    /// The Catch me up button shows once a chat has this many messages.
    static let catchUpFrom = 8

    struct Job: Equatable {
        let chatID: String
        /// nil for a catch up.
        let messageID: String?
        let failed: Bool
        let error: String?
    }

    struct CatchUp: Equatable {
        let chatID: String
        let text: String
        let at: Date?
        /// The id of the newest message it covers.
        let upTo: String?
        let count: Int
    }

    struct Chat: Equatable {
        /// Message id to its summary.
        var summaries: [String: String] = [:]
        /// The newest message from you or a teammate.
        var lastID: String?
        /// How many messages from you or teammates the chat has.
        var count = 0
    }

    struct Info: Equatable {
        var chats: [String: Chat] = [:]
        var jobs: [Job] = []
        var catchUps: [String: CatchUp] = [:]

        func summary(chatID: String, messageID: String) -> String? {
            chats[chatID]?.summaries[messageID]
        }

        /// The job for one message, or for the chat's catch up when messageID is nil.
        func job(chatID: String, messageID: String?) -> Job? {
            jobs.first { $0.chatID == chatID && $0.messageID == messageID }
        }

        func catchUp(for chatID: String) -> CatchUp? { catchUps[chatID] }

        /// True when the chat has messages the catch up doesn't cover yet.
        func hasNew(chatID: String) -> Bool {
            guard let last = chats[chatID]?.lastID else { return false }
            return catchUps[chatID]?.upTo != last
        }
    }

    /// nil when the computer doesn't send `summaries` (an older one, or one that can't summarize).
    static func info(from data: Data?) -> Info? {
        guard let data,
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let block = root["summaries"] as? [String: Any] else { return nil }
        var info = Info()
        for (chatID, value) in root["chats"] as? [String: Any] ?? [:] {
            var chat = Chat()
            for message in value as? [[String: Any]] ?? [] {
                guard let id = message["id"] as? String else { continue }
                let kind = message["kind"] as? String ?? "bot"
                let text = (message["text"] as? String ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                guard kind == "me" || kind == "bot", !text.isEmpty else { continue }
                chat.count += 1
                chat.lastID = id
                if kind == "bot", let summary = message["summary"] as? String,
                   !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    chat.summaries[id] = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            info.chats[chatID] = chat
        }
        for raw in block["jobs"] as? [[String: Any]] ?? [] {
            guard let chatID = raw["chatId"] as? String else { continue }
            info.jobs.append(Job(
                chatID: chatID,
                messageID: raw["messageId"] as? String,
                failed: raw["state"] as? String == "failed",
                error: raw["error"] as? String
            ))
        }
        for raw in block["catchUps"] as? [[String: Any]] ?? [] {
            guard let chatID = raw["chatId"] as? String,
                  let text = raw["text"] as? String,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            info.catchUps[chatID] = CatchUp(
                chatID: chatID,
                text: text.trimmingCharacters(in: .whitespacesAndNewlines),
                at: SyncText.date(raw["at"] as? String),
                upTo: raw["upTo"] as? String,
                count: (raw["count"] as? NSNumber)?.intValue ?? 0
            )
        }
        return info
    }

    /// The latest state's info, worked out once per update so every message on screen can ask cheaply.
    @MainActor
    static func current() -> Info? {
        let feed = HistoryFeed.shared
        if let cached, cached.stamp == feed.stamp { return cached.info }
        let info = info(from: feed.latest)
        cached = (feed.stamp, info)
        return info
    }

    @MainActor private static var cached: (stamp: Int, info: Info?)?

    /// True for a teammate message long enough to summarize.
    static func canSummarize(_ message: ChatMessage) -> Bool {
        message.kind == .bot && message.text.count >= minLength
    }

    // MARK: - Words

    /// "Couldn’t summarize: Not signed in." or "Couldn’t summarize." when the computer gave no reason.
    static func failed(_ lead: String, _ error: String?) -> String {
        let reason = (error ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return reason.isEmpty ? "\(lead)." : "\(lead): \(reason)"
    }

    /// "Last 12 messages" or "Last message".
    static func covers(_ count: Int) -> String {
        count == 1 ? "Last message" : "Last \(count) messages"
    }

    // MARK: - Actions

    static func messageAction(chatID: String, messageID: String) -> SyncAction {
        SyncAction(type: "summary.message", fields: ["chatId": .string(chatID), "messageId": .string(messageID)])
    }

    static func catchUpAction(chatID: String) -> SyncAction {
        SyncAction(type: "summary.catchUp", fields: ["chatId": .string(chatID)])
    }
}

/// Which catch ups you closed, so a closed one stays closed until there's something new.
@MainActor
final class CatchUpMemory: ObservableObject {
    static let shared = CatchUpMemory()

    /// Chat id to the newest message id you'd seen when you closed it.
    @Published private(set) var closed: [String: String] = [:]

    func close(_ chatID: String, at messageID: String?) {
        closed[chatID] = messageID ?? ""
    }

    func isClosed(_ chatID: String, at messageID: String?) -> Bool {
        guard let seen = closed[chatID] else { return false }
        return seen == (messageID ?? "")
    }

    func clear() { closed = [:] }
}
