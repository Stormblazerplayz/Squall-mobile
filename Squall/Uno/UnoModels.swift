import CoreGraphics
import Foundation

// Squall Uno: every Squall agent (Chief and each bot) has its own small computer inside Squall on the PC,
// and Squall Uno can use it while you watch. These are the shapes the PC sends; the full contract is in
// docs/pairing.md ("Squall Uno"). Everything is read leniently: a missing field gets a plain default and an
// unknown state or kind is kept as text, so a newer PC never makes the phone fail to read the answer.

/// One agent's computer.
struct UnoComputer: Identifiable, Hashable, Decodable {
    var id: String
    var agentId: String
    var agentName: String
    var name: String
    /// "off", "starting", "on" or "error" (kept as text so new states never break reading).
    var state: String
    /// A plain sentence from the PC about the computer. May be empty.
    var stateText: String
    var width: Int
    var height: Int
    /// The session running on it right now.
    var sessionId: String?
    /// Newest frame number (0 = none yet).
    var frameSeq: Int

    var isOn: Bool { state == "on" }
    var isStarting: Bool { state == "starting" }
    var hasProblem: Bool { state == "error" }

    var stateLabel: String {
        switch state {
        case "on": return "On"
        case "starting": return "Turning on"
        case "error": return "Has a problem"
        case "off": return "Off"
        default: return state.isEmpty ? "Off" : state.capitalized
        }
    }

    var size: CGSize { CGSize(width: max(width, 1), height: max(height, 1)) }
}

/// One Squall Uno task on a computer.
struct UnoSession: Identifiable, Hashable, Decodable {
    var id: String
    var computerId: String
    var agentId: String
    var agentName: String
    var task: String
    /// "starting", "running", "you" (you have the wheel), "done", "stopped" or "error".
    var state: String
    /// Unix milliseconds.
    var startedAt: Double?
    var endedAt: Double?
    var steps: Int
    /// What it is doing right now (or last did).
    var now: String
    /// The newest thing Squall Uno said.
    var lastText: String
    var error: String?
    var inputTokens: Int
    var outputTokens: Int

    /// Still going: getting ready, working, or paused while you drive.
    var isActive: Bool { state == "starting" || state == "running" || state == "you" }
    /// You have the wheel right now.
    var youHaveTheWheel: Bool { state == "you" }

    var stateLabel: String {
        switch state {
        case "starting": return "Getting ready"
        case "running": return "Working"
        case "you": return "You have the wheel"
        case "done": return "Done"
        case "stopped": return "Stopped"
        case "error": return "Hit a problem"
        default: return state.isEmpty ? "Unknown" : state.capitalized
        }
    }

    var startedDate: Date? { startedAt.map { Date(timeIntervalSince1970: $0 / 1000) } }
    var endedDate: Date? { endedAt.map { Date(timeIntervalSince1970: $0 / 1000) } }
}

/// One thing that happened on a computer: the "WHAT IT DID" feed.
struct UnoEvent: Identifiable, Hashable, Decodable {
    var seq: Int
    /// Unix milliseconds.
    var at: Double
    var sessionId: String?
    var computerId: String
    /// "uno", "you" or "system".
    var who: String
    /// "click", "type", "screenshot" and so on (kept as text so new kinds never break reading).
    var kind: String
    var text: String
    /// Screen pixels, in the computer's width × height space.
    var x: Double?
    var y: Double?
    var x2: Double?
    var y2: Double?
    var step: Int?

    var id: Int { seq }
    var byYou: Bool { who == "you" }
    var date: Date { Date(timeIntervalSince1970: at / 1000) }

    /// Kinds that click somewhere, so the screen can show a ripple there.
    static let clickKinds: Set<String> = ["click", "left_click", "double_click", "triple_click", "right_click", "middle_click"]

    var isClick: Bool { Self.clickKinds.contains(kind) }

    var point: CGPoint? {
        guard let x, let y else { return nil }
        return CGPoint(x: x, y: y)
    }
}

/// Squall Uno's settings on the PC. The API key itself never comes to the phone, only a short hint.
struct UnoSettings: Hashable, Decodable {
    struct Tokens: Hashable, Decodable {
        var input: Int
        var output: Int
    }

    var hasKey: Bool
    /// "env" (the SQUALL_UNO_KEY variable), "saved" (saved from Squall) or "none".
    var keySource: String
    /// Like "sk-ant-…a1b2". May be empty.
    var keyHint: String
    var dockerReady: Bool
    /// Docker's status, or what to do about it.
    var dockerText: String
    var imageReady: Bool
    var model: String
    var maxSteps: Int
    var tokensToday: Tokens
}

/// The answer to the `state` op.
struct UnoStateAnswer: Decodable {
    var ok: Bool?
    var error: String?
    var settings: UnoSettings?
    var computers: [UnoComputer]
    /// Newest first.
    var sessions: [UnoSession]
    /// Oldest first.
    var events: [UnoEvent]
    var lastSeq: Int?
}

/// The answer to every other op. Only the fields that op sends are there.
struct UnoReply: Decodable {
    var ok: Bool?
    var error: String?
    var sessionId: String?
    var computerId: String?
    var text: String?
    var stopped: Int?
    var settings: UnoSettings?
}

/// One JPEG of a computer's screen, from GET /api/v1/uno/frame.
struct UnoFrame {
    var computerId: String
    var seq: Int
    var width: Int
    var height: Int
    var cursor: CGPoint?
    var data: Data
}

// MARK: - Reading the JSON

extension UnoComputer {
    private enum CodingKeys: String, CodingKey {
        case id, agentId, agentName, name, state, stateText, width, height, sessionId, frameSeq
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.unoString(.id) ?? ""
        agentId = c.unoString(.agentId) ?? ""
        agentName = c.unoString(.agentName) ?? ""
        name = c.unoString(.name) ?? ""
        state = c.unoString(.state) ?? "off"
        stateText = c.unoString(.stateText) ?? ""
        width = max(c.unoInt(.width) ?? 1280, 1)
        height = max(c.unoInt(.height) ?? 800, 1)
        sessionId = c.unoNonEmptyString(.sessionId)
        frameSeq = c.unoInt(.frameSeq) ?? 0
    }
}

extension UnoSession {
    private enum CodingKeys: String, CodingKey {
        case id, computerId, agentId, agentName, task, state, startedAt, endedAt, steps, now, lastText, error
        case inputTokens, outputTokens
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.unoString(.id) ?? ""
        computerId = c.unoString(.computerId) ?? ""
        agentId = c.unoString(.agentId) ?? ""
        agentName = c.unoString(.agentName) ?? ""
        task = c.unoString(.task) ?? ""
        state = c.unoString(.state) ?? ""
        startedAt = c.unoDouble(.startedAt)
        endedAt = c.unoDouble(.endedAt)
        steps = c.unoInt(.steps) ?? 0
        now = c.unoString(.now) ?? ""
        lastText = c.unoString(.lastText) ?? ""
        error = c.unoNonEmptyString(.error)
        inputTokens = c.unoInt(.inputTokens) ?? 0
        outputTokens = c.unoInt(.outputTokens) ?? 0
    }
}

extension UnoEvent {
    private enum CodingKeys: String, CodingKey {
        case seq, at, sessionId, computerId, who, kind, text, x, y, x2, y2, step
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        seq = c.unoInt(.seq) ?? 0
        at = c.unoDouble(.at) ?? 0
        sessionId = c.unoNonEmptyString(.sessionId)
        computerId = c.unoString(.computerId) ?? ""
        who = c.unoString(.who) ?? "uno"
        kind = c.unoString(.kind) ?? ""
        text = c.unoString(.text) ?? ""
        x = c.unoDouble(.x)
        y = c.unoDouble(.y)
        x2 = c.unoDouble(.x2)
        y2 = c.unoDouble(.y2)
        step = c.unoInt(.step)
    }
}

extension UnoSettings.Tokens {
    private enum CodingKeys: String, CodingKey {
        case input, output
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        input = c.unoInt(.input) ?? 0
        output = c.unoInt(.output) ?? 0
    }
}

extension UnoSettings {
    private enum CodingKeys: String, CodingKey {
        case hasKey, keySource, keyHint, dockerReady, dockerText, imageReady, model, maxSteps, tokensToday
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        hasKey = c.unoBool(.hasKey) ?? false
        keySource = c.unoString(.keySource) ?? (hasKey ? "saved" : "none")
        keyHint = c.unoString(.keyHint) ?? ""
        dockerReady = c.unoBool(.dockerReady) ?? false
        dockerText = c.unoString(.dockerText) ?? ""
        imageReady = c.unoBool(.imageReady) ?? false
        model = c.unoString(.model) ?? ""
        maxSteps = c.unoInt(.maxSteps) ?? 80
        tokensToday = (try? c.decodeIfPresent(Tokens.self, forKey: .tokensToday)) ?? Tokens(input: 0, output: 0)
    }
}

extension UnoStateAnswer {
    private enum CodingKeys: String, CodingKey {
        case ok, error, settings, computers, sessions, events, lastSeq
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.unoBool(.ok)
        error = c.unoNonEmptyString(.error)
        settings = try? c.decodeIfPresent(UnoSettings.self, forKey: .settings)
        computers = c.unoList(UnoComputer.self, .computers)
        sessions = c.unoList(UnoSession.self, .sessions)
        events = c.unoList(UnoEvent.self, .events)
        lastSeq = c.unoInt(.lastSeq)
    }
}

extension UnoReply {
    private enum CodingKeys: String, CodingKey {
        case ok, error, sessionId, computerId, text, stopped, settings
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        ok = c.unoBool(.ok)
        error = c.unoNonEmptyString(.error)
        sessionId = c.unoNonEmptyString(.sessionId)
        computerId = c.unoNonEmptyString(.computerId)
        text = c.unoString(.text)
        stopped = c.unoInt(.stopped)
        settings = try? c.decodeIfPresent(UnoSettings.self, forKey: .settings)
    }
}

/// Reads a field without ever failing: a wrong type counts as missing.
private extension KeyedDecodingContainer {
    func unoString(_ key: Key) -> String? {
        if let value = try? decodeIfPresent(String.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return String(value) }
        return nil
    }

    func unoNonEmptyString(_ key: Key) -> String? {
        guard let value = unoString(key), !value.isEmpty else { return nil }
        return value
    }

    func unoDouble(_ key: Key) -> Double? {
        if let value = try? decodeIfPresent(Double.self, forKey: key), value.isFinite { return value }
        if let text = try? decodeIfPresent(String.self, forKey: key), let value = Double(text), value.isFinite { return value }
        return nil
    }

    func unoInt(_ key: Key) -> Int? {
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value }
        if let value = unoDouble(key), abs(value) < 9.0e15 { return Int(value.rounded()) }
        return nil
    }

    func unoBool(_ key: Key) -> Bool? {
        if let value = try? decodeIfPresent(Bool.self, forKey: key) { return value }
        if let value = try? decodeIfPresent(Int.self, forKey: key) { return value != 0 }
        return nil
    }

    func unoList<Item: Decodable>(_ type: Item.Type, _ key: Key) -> [Item] {
        (try? decodeIfPresent([Item].self, forKey: key)) ?? []
    }
}

// MARK: - Errors and words

/// What can go wrong with Squall Uno, in words a person can act on.
enum UnoError: Error, Equatable {
    /// The phone isn't paired with a PC.
    case notPaired
    /// Squall on the PC is older and doesn't know Squall Uno.
    case needsUpdate
    /// The computer is off, so there's no screen to show.
    case computerOff
    /// The PC said no, with its reason.
    case refused(String)

    var message: String {
        switch self {
        case .notPaired: return UnoText.notPaired
        case .needsUpdate: return UnoText.needsUpdate
        case .computerOff: return "This computer is off right now."
        case .refused(let reason): return reason
        }
    }
}

extension UnoError: LocalizedError {
    var errorDescription: String? { message }
}

enum UnoText {
    static let needsUpdate = "Update Squall on your PC to use Squall Uno."
    static let notPaired = "Pair your PC first to use Squall Uno."
    static let didntWork = "Your PC couldn't do that. Try again."

    /// A friendly sentence for any error from a Squall Uno call.
    static func message(for error: Error) -> String {
        if let uno = error as? UnoError { return uno.message }
        if let pairing = error as? PairingError {
            switch pairing {
            case .liveDataNotSupported, .voiceNotSupported: return needsUpdate
            default: return pairing.message
            }
        }
        if let refused = error as? SyncActionError { return refused.message }
        return PairingError.cantReach.message
    }
}

// MARK: - Math and helpers (kept free of views so they can be tested)

enum UnoMath {
    /// Where a `content`-sized picture sits when it's fitted (aspect fit, centered) inside `box`.
    static func fitRect(content: CGSize, in box: CGSize) -> CGRect {
        guard content.width > 0, content.height > 0, box.width > 0, box.height > 0 else {
            return CGRect(origin: .zero, size: box)
        }
        let scale = min(box.width / content.width, box.height / content.height)
        let size = CGSize(width: content.width * scale, height: content.height * scale)
        return CGRect(
            x: (box.width - size.width) / 2,
            y: (box.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    /// A point on the computer (in its pixels) to a point on the phone's screen view.
    static func toView(_ point: CGPoint, computer: CGSize, rect: CGRect) -> CGPoint {
        guard computer.width > 0, computer.height > 0 else { return CGPoint(x: rect.midX, y: rect.midY) }
        return CGPoint(
            x: rect.minX + point.x * rect.width / computer.width,
            y: rect.minY + point.y * rect.height / computer.height
        )
    }

    /// A tap on the phone's screen view to the computer pixel under it, or nil when the tap missed the picture.
    static func toComputer(_ point: CGPoint, computer: CGSize, rect: CGRect) -> CGPoint? {
        guard computer.width >= 1, computer.height >= 1, rect.width > 0, rect.height > 0,
              rect.contains(point) else { return nil }
        let x = ((point.x - rect.minX) * computer.width / rect.width).rounded(.down)
        let y = ((point.y - rect.minY) * computer.height / rect.height).rounded(.down)
        return CGPoint(
            x: min(max(x, 0), computer.width - 1),
            y: min(max(y, 0), computer.height - 1)
        )
    }

    /// Reads the `X-Uno-Cursor: <x>,<y>` header.
    static func cursor(from header: String?) -> CGPoint? {
        guard let header else { return nil }
        let parts = header.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2, let x = Double(parts[0]), let y = Double(parts[1]),
              x.isFinite, y.isFinite else { return nil }
        return CGPoint(x: x, y: y)
    }

    /// The PC's name for an agent's computer: "pc-" + the agent id, lower-cased, with anything outside
    /// a-z, 0-9 and "-" turned into "-", at most 40 characters. Used until the PC lists the computer itself.
    static func computerId(for agentId: String) -> String {
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789-")
        let cleaned = String(("pc-" + agentId.lowercased()).map { allowed.contains($0) ? $0 : "-" })
        return String(cleaned.prefix(40))
    }
}

enum UnoFeed {
    /// Adds `new` events to `old`, one per seq (newer copies win), oldest first, keeping the last `limit`.
    static func merge(_ old: [UnoEvent], _ new: [UnoEvent], limit: Int) -> [UnoEvent] {
        guard !new.isEmpty else { return Array(old.suffix(max(limit, 0))) }
        var bySeq: [Int: UnoEvent] = [:]
        for event in old { bySeq[event.seq] = event }
        for event in new { bySeq[event.seq] = event }
        let sorted = bySeq.values.sorted { $0.seq < $1.seq }
        return Array(sorted.suffix(max(limit, 0)))
    }

    /// "just now", "12s ago", "3 min ago", "2 hr ago", "4 days ago".
    static func ago(_ date: Date, now: Date = Date()) -> String {
        let seconds = Int(now.timeIntervalSince(date))
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        let minutes = seconds / 60
        if minutes < 60 { return "\(minutes) min ago" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) hr ago" }
        let days = hours / 24
        return days == 1 ? "1 day ago" : "\(days) days ago"
    }
}
