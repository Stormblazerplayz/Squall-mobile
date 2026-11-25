import Foundation

// What Squall on the computer sends the phone, and what the phone sends back.
// The full protocol is under "Live data" in docs/pairing.md.
// Decoding is forgiving: a field that's missing gets a sensible default,
// and one broken item is skipped instead of breaking the whole update.

/// Everything the app shows, from GET /api/v1/state.
struct StateSnapshot: Decodable {
    var version: String?
    var paused: Bool
    var typing: String?
    var bots: [BotDTO]
    var chats: [String: [MessageDTO]]
    var groups: [GroupDTO]
    var inbox: [InboxDTO]
    var routines: [RoutineDTO]
    var work: [WorkDTO]
    var handoffs: [HandoffDTO]
    var claudeCode: ClaudeCodeDTO?
    /// Squall on the computer itself. Older desktops don't send it.
    var desktop: DesktopInfo?
    /// The plan's usage and today's jobs. Older desktops don't send it.
    var usage: UsageDTO?

    private enum CodingKeys: String, CodingKey {
        case version, paused, typing, bots, chats, groups, inbox, routines, work, handoffs, claudeCode, desktop, usage
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.lenientString(.version)
        paused = (try? c.decodeIfPresent(Bool.self, forKey: .paused)) ?? false
        typing = c.lenientString(.typing)
        bots = c.lossyArray(BotDTO.self, forKey: .bots)
        groups = c.lossyArray(GroupDTO.self, forKey: .groups)
        inbox = c.lossyArray(InboxDTO.self, forKey: .inbox)
        routines = c.lossyArray(RoutineDTO.self, forKey: .routines)
        work = c.lossyArray(WorkDTO.self, forKey: .work)
        handoffs = c.lossyArray(HandoffDTO.self, forKey: .handoffs)
        claudeCode = try? c.decodeIfPresent(ClaudeCodeDTO.self, forKey: .claudeCode)
        desktop = (try? c.decodeIfPresent(DesktopInfo.self, forKey: .desktop)) ?? nil
        usage = (try? c.decodeIfPresent(UsageDTO.self, forKey: .usage)) ?? nil
        let rawChats = (try? c.decodeIfPresent([String: [Lossy<MessageDTO>]].self, forKey: .chats)) ?? [:]
        var cleanChats: [String: [MessageDTO]] = [:]
        for (key, list) in rawChats {
            cleanChats[key] = list.compactMap(\.value)
        }
        chats = cleanChats
    }
}

/// `"desktop": {"version": "1.4.0", "latest": "1.5.0", "updating": false}` in the state.
struct DesktopInfo: Decodable, Equatable {
    var version: String?
    /// The newest version on GitHub Releases, when the desktop has checked.
    var latest: String?
    /// True while the desktop is downloading or installing an update.
    var updating: Bool

    private enum CodingKeys: String, CodingKey {
        case version, latest, updating
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = c.lenientString(.version)
        latest = c.lenientString(.latest)
        updating = (try? c.decodeIfPresent(Bool.self, forKey: .updating)) ?? false
    }

    /// "1.4.0", "1.4.0 · 1.5.0 is ready" or "1.4.0 · updating".
    var summary: String? {
        guard let version, !version.isEmpty else { return nil }
        if updating { return "\(version) · updating" }
        if let latest, !latest.isEmpty, latest != version { return "\(version) · \(latest) is ready" }
        return version
    }
}

struct BotDTO: Decodable {
    var id: String
    var name: String
    var color: String?
    var role: String?
    var status: String?
    var task: String?
    var unread: Int?
    var log: [String]?
    var progress: Double?
    var steps: [String]?

    var model: Bot {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return Bot(
            id: id,
            name: cleanName.isEmpty ? id : cleanName,
            hex: SyncText.hex(color) ?? SyncText.fallbackHex(for: id),
            role: role ?? (id == Bot.chiefID ? "Team lead" : "Teammate"),
            status: SyncText.status(status),
            task: task ?? "",
            unread: SyncText.unread(unread),
            log: log ?? [],
            progress: min(max(progress ?? 0, 0), 1),
            steps: steps ?? []
        )
    }
}

struct MessageDTO: Decodable {
    var id: String?
    var kind: String?
    var author: String?
    var text: String?
    var text2: String?
    var chips: [String]?
    var at: String?
    var time: String?
    var count: Int?
    var fromName: String?
    var fromColor: String?
    var note: String?

    func model(chatID: String, index: Int) -> ChatMessage {
        let messageKind: ChatMessage.Kind
        switch kind ?? "bot" {
        case "me": messageKind = .me
        case "error": messageKind = .error(count: max(count ?? 1, 1))
        case "handoff":
            let name = fromName ?? "a teammate"
            messageKind = .handoff(fromName: name, fromHex: SyncText.hex(fromColor) ?? SyncText.fallbackHex(for: name), note: note ?? "")
        case "system": messageKind = .system
        default: messageKind = .bot
        }
        let who: String
        if case .me = messageKind {
            who = ChatMessage.meID
        } else {
            who = author ?? chatID
        }
        return ChatMessage(
            id: id ?? "\(chatID)-\(index)",
            kind: messageKind,
            author: who,
            text: text ?? "",
            text2: (text2?.isEmpty ?? true) ? nil : text2,
            chips: chips ?? [],
            time: SyncText.clock(at: at, fallback: time),
            at: SyncText.date(at)
        )
    }
}

struct GroupDTO: Decodable {
    var id: String
    var name: String?
    var members: [String]?
    var chiefLeads: Bool?

    var model: BotGroup {
        BotGroup(id: id, name: name ?? "Group", members: members ?? [], chiefLeads: chiefLeads ?? true)
    }
}

struct InboxDTO: Decodable {
    var id: String
    var kind: String?
    var botId: String?
    var title: String?
    var body: String?
    var options: [String]?
    var openLabel: String?
    var opens: String?
    var workId: String?
    var at: String?
    var time: String?
    var unread: Bool?
    var details: String?
    var command: String?

    var model: InboxItem {
        let itemKind: InboxItem.Kind
        switch kind ?? "done" {
        case "ask": itemKind = .ask
        case "choice": itemKind = .choice(options ?? [])
        case "error": itemKind = .error
        default: itemKind = .done(openLabel: openLabel ?? "Open")
        }
        return InboxItem(
            id: id,
            kind: itemKind,
            botID: botId ?? Bot.chiefID,
            title: title ?? "",
            body: body ?? "",
            time: SyncText.ago(at: at, fallback: time),
            unread: unread ?? false,
            fresh: false,
            opens: opens == "live" ? .live : .chat,
            details: details,
            command: command,
            workID: workId
        )
    }
}

struct RoutineDTO: Decodable {
    struct RunDTO: Decodable {
        var done: Int?
        var total: Int?
        var label: String?
    }

    private enum CodingKeys: String, CodingKey {
        case id, botId, task, days, minutes, isOn, pingWhenDone, askBeforePush, skipIfBusy, run
        case repeatMode = "repeat"
    }

    var id: String
    var botId: String?
    var task: String?
    var repeatMode: String?
    var days: [Bool]?
    var minutes: Int?
    var isOn: Bool?
    var pingWhenDone: Bool?
    var askBeforePush: Bool?
    var skipIfBusy: Bool?
    var run: RunDTO?

    var model: Routine {
        let mode = Routine.Repeat(rawValue: repeatMode ?? "daily") ?? .daily
        var dayList = days ?? mode.presetDays ?? Array(repeating: true, count: 7)
        if dayList.count != 7 {
            dayList = Array((dayList + Array(repeating: false, count: 7)).prefix(7))
        }
        let routineRun = run.map { raw -> Routine.Run in
            let total = max(raw.total ?? 0, 0)
            return Routine.Run(done: min(max(raw.done ?? 0, 0), max(total, 0)), total: total, label: raw.label ?? "Working")
        }
        return Routine(
            id: id,
            botID: botId ?? Bot.chiefID,
            task: task ?? "",
            repeatMode: mode,
            days: dayList,
            minutes: min(max(minutes ?? 9 * 60, 0), 24 * 60 - 1),
            isOn: isOn ?? true,
            pingWhenDone: pingWhenDone ?? true,
            askBeforePush: askBeforePush ?? true,
            skipIfBusy: skipIfBusy ?? false,
            run: routineRun
        )
    }
}

struct LineDTO: Decodable {
    var text: String?
    var kind: String?

    var model: LiveLine {
        LiveLine(text: text ?? "", kind: LiveLine.Kind(rawValue: kind ?? "dim") ?? .dim)
    }
}

struct WorkDTO: Decodable {
    struct StepDTO: Decodable {
        var title: String?
        var state: String?
        var took: String?
        var lines: [LineDTO]?
    }

    struct FileDTO: Decodable {
        var path: String?
        var change: String?
        var edited: Bool?
    }

    var id: String
    var botId: String?
    var title: String?
    var from: String?
    var state: String?
    var startedAt: String?
    var now: String?
    var steps: [StepDTO]?
    var terminal: [LineDTO]?
    var files: [FileDTO]?
    var askId: String?

    var model: LiveWork {
        LiveWork(
            id: id,
            botID: botId ?? Bot.chiefID,
            title: title ?? "Working",
            from: from ?? "",
            state: LiveWork.State(rawValue: state ?? "working") ?? .working,
            startedAt: SyncText.date(startedAt),
            now: now ?? "",
            steps: (steps ?? []).map {
                LiveWork.Step(
                    title: $0.title ?? "Step",
                    state: LiveWork.StepState(rawValue: $0.state ?? "todo") ?? .todo,
                    took: $0.took ?? "",
                    lines: ($0.lines ?? []).map(\.model)
                )
            },
            terminal: (terminal ?? []).map(\.model),
            files: (files ?? []).compactMap { file in
                guard let path = file.path, !path.isEmpty else { return nil }
                return LiveWork.File(path: path, change: file.change ?? "", edited: file.edited ?? false)
            },
            askID: (askId?.isEmpty ?? true) ? nil : askId
        )
    }
}

struct HandoffDTO: Decodable {
    var id: String?
    var from: String?
    var to: String?
    var what: String?
    var at: String?
    var time: String?

    func model(index: Int) -> Handoff {
        Handoff(
            id: id ?? "handoff-\(index)",
            from: from ?? "",
            to: to ?? Bot.chiefID,
            what: what ?? "",
            time: SyncText.ago(at: at, fallback: time)
        )
    }
}

struct ClaudeCodeDTO: Decodable {
    var version: String?
    var latest: String?
    var needsUpdate: Bool?
    var updating: Double?

    var model: ClaudeCodeInfo {
        ClaudeCodeInfo(
            version: version ?? "?",
            latest: latest,
            needsUpdate: needsUpdate ?? false,
            updating: updating.map { min(max($0, 0), 1) }
        )
    }
}

// MARK: - Phone to computer

/// Something you did on the phone, sent to POST /api/v1/action.
struct SyncAction {
    let type: String
    var fields: [String: JSONValue] = [:]

    var body: JSONValue {
        var all = fields
        all["type"] = .string(type)
        all["id"] = .string(UUID().uuidString)
        return .object(all)
    }
}

/// What the computer says back to an action.
struct SyncActionReply: Decodable {
    var ok: Bool?
    var id: String?
    var error: String?
}

/// Any JSON value, so actions can carry different fields.
enum JSONValue: Encodable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case array([JSONValue])
    case object([String: JSONValue])
    case null

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch self {
        case .string(let value): try c.encode(value)
        case .int(let value): try c.encode(value)
        case .double(let value): try c.encode(value)
        case .bool(let value): try c.encode(value)
        case .array(let value): try c.encode(value)
        case .object(let value): try c.encode(value)
        case .null: try c.encodeNil()
        }
    }

    /// Turns anything Encodable (like the settings) into a JSONValue.
    static func from<T: Encodable>(_ value: T) -> JSONValue {
        guard let data = try? JSONEncoder().encode(value),
              let any = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else { return .null }
        return from(any: any)
    }

    private static func from(any: Any) -> JSONValue {
        switch any {
        case let value as NSNumber:
            // Bools come back as NSNumber too.
            if CFGetTypeID(value as CFTypeRef) == CFBooleanGetTypeID() { return .bool(value.boolValue) }
            if CFNumberIsFloatType(value as CFNumber) { return .double(value.doubleValue) }
            return .int(value.intValue)
        case let value as String:
            return .string(value)
        case let value as [Any]:
            return .array(value.map { from(any: $0) })
        case let value as [String: Any]:
            return .object(value.mapValues { from(any: $0) })
        default:
            return .null
        }
    }
}

// MARK: - Helpers

/// Reads each item on its own, so one bad item doesn't break the rest.
struct Lossy<T: Decodable>: Decodable {
    let value: T?

    init(from decoder: Decoder) throws {
        value = try? T(from: decoder)
    }
}

extension KeyedDecodingContainer {
    func lossyArray<T: Decodable>(_ type: T.Type, forKey key: Key) -> [T] {
        let list = try? decodeIfPresent([Lossy<T>].self, forKey: key)
        return list?.compactMap(\.value) ?? []
    }

    func lenientString(_ key: Key) -> String? {
        if let text = try? decodeIfPresent(String.self, forKey: key) { return text }
        if let number = try? decodeIfPresent(Int.self, forKey: key) { return String(number) }
        return nil
    }
}

/// Turns the computer's text into what the screens show.
enum SyncText {
    private static let isoWithFraction: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    private static let iso = ISO8601DateFormatter()

    private static let clockFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, h:mm a"
        return formatter
    }()

    static func date(_ text: String?) -> Date? {
        guard let text, !text.isEmpty else { return nil }
        return isoWithFraction.date(from: text) ?? iso.date(from: text)
    }

    /// "2:41 PM" today, "Nov 12, 2:41 PM" before that.
    static func clock(at: String?, fallback: String?) -> String {
        guard let date = date(at) else { return fallback ?? "" }
        if Calendar.current.isDateInToday(date) {
            return clockFormatter.string(from: date)
        }
        return dayFormatter.string(from: date)
    }

    /// "now", "5m", "3h", "Yesterday" or a date.
    static func ago(at: String?, fallback: String?, now: Date = Date()) -> String {
        guard let date = date(at) else { return fallback ?? "" }
        let seconds = max(0, Int(now.timeIntervalSince(date)))
        if seconds < 60 { return "now" }
        if seconds < 3600 { return "\(seconds / 60)m" }
        if seconds < 86_400 { return "\(seconds / 3600)h" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return dayFormatter.string(from: date)
    }

    /// "#3B87D6" or "3B87D6".
    static func hex(_ text: String?) -> UInt32? {
        guard var clean = text?.trimmingCharacters(in: .whitespacesAndNewlines), !clean.isEmpty else { return nil }
        if clean.hasPrefix("#") { clean.removeFirst() }
        guard clean.count == 6, let value = UInt32(clean, radix: 16) else { return nil }
        return value
    }

    /// A steady color for a bot the computer didn't give one.
    static func fallbackHex(for id: String) -> UInt32 {
        let colors: [UInt32] = [0x3FD0B0, 0x3A8DE0, 0x8C72DC, 0xF0913A, 0xE8CF4A, 0xF06A6A, 0xF06AB8, 0x6EE08A]
        let sum = id.unicodeScalars.reduce(0) { ($0 &* 31 &+ Int($1.value)) & 0xFFFF }
        return id == Bot.chiefID ? 0xD8B747 : colors[sum % colors.count]
    }

    static func status(_ text: String?) -> BotStatus {
        switch text ?? "idle" {
        case "working": return .working
        case "napping": return .napping
        case "waiting": return .waiting
        case "handed": return .handed
        case "paused": return .paused
        default: return .idle
        }
    }

    static func unread(_ count: Int?) -> String? {
        guard let count, count > 0 else { return nil }
        return count > 9 ? "9+" : "\(count)"
    }
}
