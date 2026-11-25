import Combine
import Foundation

/// Go to a day: a list of the days a chat has messages on, newest first, each with how many messages and how it starts.
/// Picking one scrolls the chat to that day's first message and lights it up.
enum ChatDayJump {
    struct Day: Equatable, Identifiable {
        let start: Date
        /// The day's first message, to scroll to.
        let firstID: String
        let count: Int
        /// The day's first words, plain, on one line.
        let preview: String

        var id: Date { start }
    }

    static let previewLength = 90

    /// Days with messages that have a time, newest first. Lines like "Rex joined" scroll but don't count.
    static func days(_ list: [ChatMessage], calendar: Calendar = .current) -> [Day] {
        var order: [Date] = []
        var first: [Date: ChatMessage] = [:]
        var counts: [Date: Int] = [:]
        var previews: [Date: String] = [:]
        for message in list {
            guard let at = message.at else { continue }
            let day = calendar.startOfDay(for: at)
            if first[day] == nil {
                order.append(day)
                first[day] = message
            }
            guard message.kind != .system else { continue }
            counts[day, default: 0] += 1
            if previews[day] == nil {
                let line = preview(StarredMessages.words(of: message))
                if !line.isEmpty { previews[day] = line }
            }
        }
        return order.reversed().compactMap { day in
            guard let message = first[day] else { return nil }
            return Day(start: day, firstID: message.id, count: counts[day] ?? 0, preview: previews[day] ?? "")
        }
    }

    /// The first line of a message's words without Markdown, cut to fit.
    static func preview(_ text: String) -> String {
        let plain = Markdown.plain(text)
        let line = plain.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        guard line.count > previewLength else { return line }
        return String(line.prefix(previewLength - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// "Today", "Yesterday", "Monday, Nov 23", with the year when it isn't this year.
    static func title(_ day: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let base = TeamHistory.dayTitle(day, now: now, calendar: calendar)
        guard base != "Today", base != "Yesterday",
              calendar.component(.year, from: day) != calendar.component(.year, from: now) else { return base }
        return "\(base), \(calendar.component(.year, from: day))"
    }

    /// "1 message", "12 messages".
    static func countText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "message" : "messages")"
    }

    /// A day picked in the list, for the chat to scroll to, and the message lit up after.
    final class Model: ObservableObject {
        static let shared = Model()

        struct Request: Equatable {
            let chatID: String
            let messageID: String
        }

        @Published var request: Request?
        /// The list of days is up.
        @Published var showList = false
        @Published private(set) var flashID: String?

        func go(chatID: String, messageID: String) {
            request = Request(chatID: chatID, messageID: messageID)
        }

        /// Lights the message up for a moment.
        @MainActor
        func flash(_ messageID: String) {
            flashID = messageID
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.8))
                if self.flashID == messageID { self.flashID = nil }
            }
        }
    }
}
