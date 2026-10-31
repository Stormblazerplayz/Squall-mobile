import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Kind: Equatable {
        case me
        case bot
        case error(count: Int)
        case handoff(fromName: String, fromHex: UInt32, note: String)
        case system
    }

    let id = UUID()
    var kind: Kind
    /// Bot id that wrote it, or "me".
    var author: String
    var text: String
    var text2: String? = nil
    var chips: [String] = []
    var time: String

    static let meID = "me"
}

enum TimeText {
    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    static func now() -> String {
        formatter.string(from: Date())
    }

    /// 1:05 style time for minutes after midnight.
    static func time(minutes: Int) -> String {
        let hour24 = (minutes / 60) % 24
        let minute = minutes % 60
        let suffix = hour24 >= 12 ? "PM" : "AM"
        let hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12
        return String(format: "%d:%02d %@", hour12, minute, suffix)
    }

    /// 04:12 style stopwatch text.
    static func stopwatch(_ seconds: Int) -> String {
        String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}
