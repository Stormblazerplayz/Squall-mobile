import Foundation
import UserNotifications

/// Pings when a teammate answers you in a one-on-one chat while Squall isn't open, with a Reply box right in the
/// notification. Every ping is a real reply the computer sent; the first look at a computer only remembers what's there,
/// so pairing never pings for old messages. Follows Settings > Notifications (this switch, sound, quiet hours and muted bots).
enum ReplyAlerts {
    static let category = "squall.reply"
    static let replyAction = "squall.reply.send"
    static let chatKey = "chatId"
    /// The Settings switch. On until it's turned off.
    static let onKey = "squall.alerts.replies"

    private static let seenKey = "squall.alerts.seenReplies"
    private static let computerKey = "squall.alerts.repliesComputer"
    static let maxSeen = 3000
    /// At most this many pings from one look, newest first, so a long absence doesn't flood the phone.
    static let maxPings = 4
    static let maxBody = 300

    struct Reply: Equatable {
        let key: String
        let chatID: String
        let author: String
        let text: String
    }

    static var isOn: Bool {
        UserDefaults.standard.object(forKey: onKey) as? Bool ?? true
    }

    /// The key that tells one message from another: "<chat id>/<message id>".
    static func key(chatID: String, messageID: String) -> String { "\(chatID)/\(messageID)" }

    /// Every teammate reply in a one-on-one chat that has an id and words, oldest first within each chat.
    static func replies(in chats: [String: [MessageDTO]], botIDs: Set<String>) -> [Reply] {
        var out: [Reply] = []
        for chatID in chats.keys.sorted() where botIDs.contains(chatID) {
            for message in chats[chatID] ?? [] {
                guard let id = message.id, !id.isEmpty else { continue }
                let kind = message.kind ?? "bot"
                guard kind == "bot" else { continue }
                let author = message.author ?? chatID
                guard author != ChatMessage.meID else { continue }
                let text = clean([message.text, message.text2].compactMap { $0 }.joined(separator: " "))
                guard !text.isEmpty else { continue }
                out.append(Reply(key: key(chatID: chatID, messageID: id), chatID: chatID, author: author, text: text))
            }
        }
        return out
    }

    /// The replies that are new since the last look (newest last), capped at `maxPings`.
    static func fresh(_ replies: [Reply], seen: Set<String>) -> [Reply] {
        Array(replies.filter { !seen.contains($0.key) }.suffix(maxPings))
    }

    /// One line of plain words: code blocks become "(code)", and the rest of the Markdown marks go.
    static func clean(_ raw: String) -> String {
        var text = raw.replacingOccurrences(of: #"```[\s\S]*?```"#, with: " (code) ", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\[([^\]]+)\]\([^)]+\)"#, with: "$1", options: .regularExpression)
        text = text.replacingOccurrences(of: #"[`*_#>]+"#, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.count > maxBody {
            text = String(text.prefix(maxBody - 1)).trimmingCharacters(in: .whitespaces) + "…"
        }
        return text
    }

    // MARK: - Looking at new data

    /// Remembers every reply it sees, and pings for the new ones while Squall is in the background.
    @MainActor
    static func process(chats: [String: [MessageDTO]], bots: [Bot], settings: AppSettings, computerKey: String, inForeground: Bool) {
        let defaults = UserDefaults.standard
        let all = replies(in: chats, botIDs: Set(bots.map(\.id)))
        let sameComputer = defaults.string(forKey: Self.computerKey) == computerKey
        let seenList = defaults.stringArray(forKey: seenKey)
        let seen = Set(seenList ?? [])
        defaults.set(computerKey, forKey: Self.computerKey)
        defaults.set(Array(all.map(\.key).suffix(maxSeen)), forKey: seenKey)

        guard sameComputer, seenList != nil, !inForeground, isOn else { return }
        for reply in fresh(all, seen: seen) {
            guard !settings.mutedBots.contains(reply.author) else { continue }
            let name = bots.first(where: { $0.id == reply.author })?.name ?? "A teammate"
            post(reply, name: name, settings: settings)
        }
    }

    @MainActor
    private static func post(_ reply: Reply, name: String, settings: AppSettings) {
        let focus = FocusRules.current
        guard focus.allows(.reply, from: reply.author) else { return }
        let content = UNMutableNotificationContent()
        content.title = name
        content.body = reply.text
        content.categoryIdentifier = category
        content.threadIdentifier = "reply.\(reply.chatID)"
        content.userInfo = [AlertIDs.routeKey: "chat/\(reply.chatID)", chatKey: reply.chatID]
        if (settings.quietHours && SquallAlerts.isQuietTime(settings)) || focus.silent {
            content.interruptionLevel = .passive
        } else if settings.notifySound {
            content.sound = .default
        }
        let request = UNNotificationRequest(identifier: "squall.reply.\(reply.key)", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { _ in }
    }

    /// After Unpair: the next computer starts fresh.
    static func forget() {
        UserDefaults.standard.removeObject(forKey: seenKey)
        UserDefaults.standard.removeObject(forKey: computerKey)
    }

    // MARK: - The Reply box

    static var notificationCategory: UNNotificationCategory {
        let reply = UNTextInputNotificationAction(
            identifier: replyAction,
            title: "Reply",
            options: [.authenticationRequired],
            textInputButtonTitle: "Send",
            textInputPlaceholder: "Message"
        )
        return UNNotificationCategory(identifier: category, actions: [reply], intentIdentifiers: [], options: [])
    }

    /// The words to send from the Reply box, or nil when there are none.
    static func message(_ raw: String) -> String? {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text.prefix(20_000))
    }
}
