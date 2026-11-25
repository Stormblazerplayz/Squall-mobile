import CoreGraphics
import Foundation

// Squall Uno's live screen moves with what Squall Uno really does: the mouse glides to where it really went,
// clicks ripple where they really landed, typed text and pressed keys show up near the mouse. Everything here is
// read from the PC's real events (docs/squall-uno.md); when an event doesn't say something, nothing is made up.
// Kept free of views so it can be tested.

/// Which way a scroll went.
enum UnoScrollDirection: String, Equatable {
    case up, down, left, right
}

/// The keycap chip for a key event, like [Ctrl] + [L].
struct UnoKeyChip: Equatable {
    /// One list per chord, pressed one after another: [["Ctrl", "L"], ["Enter"]].
    var keys: [[String]]
    var times: Int
    /// A key held down for a while ("hold_key").
    var hold: Bool

    /// "Ctrl + L, Enter ×2", for VoiceOver.
    var label: String {
        keys.map { $0.joined(separator: " + ") }.joined(separator: ", ") + (times > 1 ? " ×\(times)" : "")
    }
}

/// What the live screen shows for one real event.
enum UnoMotion: Equatable {
    /// A ripple where it clicked (count 2 or 3 for double and triple clicks); the mouse glides there.
    case click(at: CGPoint, count: Int)
    /// The mouse glides there.
    case move(to: CGPoint)
    /// A short trail from where the drag started to where it let go.
    case drag(from: CGPoint, to: CGPoint)
    /// The typed text appears letter by letter near the mouse.
    case type(text: String)
    /// A keycap chip near the mouse.
    case key(UnoKeyChip)
    /// An arrow at the spot (nil: where the mouse is).
    case scroll(direction: UnoScrollDirection, at: CGPoint?)
    /// A quick flash on the screen's edge; a zoom also outlines the part it looked at.
    case flash(zoom: CGRect?)

    /// The effect for an event, or nil when it has nothing to show on the screen.
    static func of(_ event: UnoEvent) -> UnoMotion? {
        let point = event.point
        var end: CGPoint?
        if let x2 = event.x2, let y2 = event.y2 { end = CGPoint(x: x2, y: y2) }
        switch event.kind {
        case "drag":
            if let point, let end { return .drag(from: point, to: end) }
            if let spot = end ?? point { return .move(to: spot) }
            return nil
        case "move", "cursor", "mouse_down", "mouse_up":
            return point.map { UnoMotion.move(to: $0) }
        case "type":
            return UnoMotionText.typedText(event).map { UnoMotion.type(text: $0) }
        case "key", "hold_key":
            return UnoMotionText.keyChip(event).map { UnoMotion.key($0) }
        case "scroll":
            return UnoMotionText.scrollDirection(event).map { UnoMotion.scroll(direction: $0, at: point) }
        case "screenshot":
            return .flash(zoom: nil)
        case "zoom":
            guard let point, let end else { return .flash(zoom: nil) }
            return .flash(zoom: CGRect(
                x: min(point.x, end.x),
                y: min(point.y, end.y),
                width: abs(end.x - point.x),
                height: abs(end.y - point.y)
            ))
        default:
            guard event.isClick, let point else { return nil }
            let count = event.kind == "double_click" ? 2 : event.kind == "triple_click" ? 3 : 1
            return .click(at: point, count: count)
        }
    }
}

enum UnoMotionText {
    /// Typed text always finishes within this many seconds...
    static let tickerMax: Double = 1.2
    /// ...and short text types at this pace (seconds per character).
    static let tickerPerChar: Double = 0.045

    /// What a "type" event typed: its text reads `Typed "hello"`. Nil when it can't tell.
    static func typedText(_ event: UnoEvent) -> String? {
        guard event.kind == "type" else { return nil }
        let text = event.text.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["Typed \"", "Typing \""] where text.hasPrefix(prefix) {
            let rest = text.dropFirst(prefix.count)
            guard rest.hasSuffix("\""), rest.count >= 2 else { return nil }
            let inner = String(rest.dropLast())
            return inner.isEmpty ? nil : inner
        }
        return nil
    }

    /// Which way a "scroll" event went: its text reads "Scrolled down 3 at (640, 400)".
    static func scrollDirection(_ event: UnoEvent) -> UnoScrollDirection? {
        guard event.kind == "scroll" else { return nil }
        let words = event.text.lowercased().components(separatedBy: CharacterSet.letters.inverted)
        for word in words {
            if let direction = UnoScrollDirection(rawValue: word) { return direction }
        }
        return nil
    }

    /// The keycap chip for a "key" or "hold_key" event, from its text ("Pressed ctrl+l, Return 2 times",
    /// "Held shift for 1 second"). A key the feed cut short ("Ret…") is left out.
    static func keyChip(_ event: UnoEvent) -> UnoKeyChip? {
        guard event.kind == "key" || event.kind == "hold_key" else { return nil }
        let text = event.text.trimmingCharacters(in: .whitespacesAndNewlines)
        let hold = event.kind == "hold_key"
        var keys = ""
        var times = 1
        if hold {
            for prefix in ["Held ", "Holding "] where text.hasPrefix(prefix) {
                let rest = String(text.dropFirst(prefix.count))
                keys = rest.range(of: " for ").map { String(rest[..<$0.lowerBound]) } ?? ""
            }
        } else {
            for prefix in ["Pressed ", "Pressing "] where text.hasPrefix(prefix) {
                var words = String(text.dropFirst(prefix.count)).split(separator: " ").map(String.init)
                if words.count >= 3, words[words.count - 1] == "times", let count = Int(words[words.count - 2]) {
                    times = max(1, count)
                    words.removeLast(2)
                }
                keys = words.joined(separator: " ")
            }
        }
        let chords = keys
            .components(separatedBy: CharacterSet(charactersIn: ", ").union(.whitespacesAndNewlines))
            .filter { !$0.isEmpty && !$0.contains("…") }
            .map(prettyKey)
            .filter { !$0.isEmpty }
        guard !chords.isEmpty else { return nil }
        return UnoKeyChip(keys: chords.map { $0.components(separatedBy: " + ") }, times: times, hold: hold)
    }

    private static let keyNames: [String: String] = [
        "ctrl": "Ctrl", "control": "Ctrl", "alt": "Alt", "option": "Alt", "shift": "Shift",
        "super": "Win", "meta": "Win", "win": "Win", "cmd": "Win", "command": "Win",
        "return": "Enter", "enter": "Enter", "kp_enter": "Enter", "escape": "Esc", "esc": "Esc",
        "backspace": "Backspace", "delete": "Delete", "del": "Delete", "tab": "Tab", "iso_left_tab": "Tab",
        "space": "Space", "up": "↑", "down": "↓", "left": "←", "right": "→",
        "page_up": "Page Up", "prior": "Page Up", "pageup": "Page Up",
        "page_down": "Page Down", "next": "Page Down", "pagedown": "Page Down",
        "home": "Home", "end": "End", "insert": "Insert", "caps_lock": "Caps Lock", "print": "Print Screen", "menu": "Menu",
        "minus": "-", "plus": "+", "equal": "=", "period": ".", "comma": ",", "slash": "/", "backslash": "\\",
        "semicolon": ";", "apostrophe": "'", "grave": "`", "bracketleft": "[", "bracketright": "]"
    ]

    /// One key or chord, the way it looks on a keyboard: "ctrl+l" → "Ctrl + L", "Return" → "Enter", "ctrl++" → "Ctrl + +".
    static func prettyKey(_ chord: String) -> String {
        let text = chord.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return "" }
        // Split at each "+" that has something after it, so a "+" key at the end stays a key.
        var parts: [String] = []
        var current = ""
        let chars = Array(text)
        for (index, char) in chars.enumerated() {
            if char == "+", index < chars.count - 1 {
                parts.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        parts.append(current)
        return parts.map { part -> String in
            let raw = part.trimmingCharacters(in: .whitespaces)
            if raw.isEmpty { return "+" }
            let low = raw.lowercased()
            if let name = keyNames[low] { return name }
            if low.hasSuffix("_l") || low.hasSuffix("_r"), let name = keyNames[String(low.dropLast(2))] { return name }
            if low.count >= 2, low.count <= 3, low.hasPrefix("f"), Int(low.dropFirst()) != nil { return raw.uppercased() }
            if raw.count == 1 { return raw.uppercased() }
            return raw.prefix(1).uppercased() + raw.dropFirst()
        }
        .joined(separator: " + ")
    }

    /// Keys pressed one after another ("ctrl+l Return" or "ctrl+l, Return"): "Ctrl + L, Enter".
    static func prettyKeys(_ text: String) -> String {
        text.components(separatedBy: CharacterSet(charactersIn: ", ").union(.whitespacesAndNewlines))
            .filter { !$0.isEmpty }
            .map(prettyKey)
            .joined(separator: ", ")
    }

    /// Seconds per character for typed text of this length: steady for short text, faster for long text
    /// so it always finishes within `tickerMax`.
    static func tickerStep(length: Int) -> Double {
        guard length > 0 else { return 0 }
        return min(tickerPerChar, tickerMax / Double(length))
    }

    /// How many characters show `elapsed` seconds after the typing starts (the first one right away).
    static func tickerShown(length: Int, elapsed: Double) -> Int {
        guard length > 0 else { return 0 }
        guard elapsed.isFinite, elapsed >= 0 else { return 1 }
        let step = tickerStep(length: length)
        guard step > 0 else { return length }
        let shown = Int((elapsed / step).rounded(.down)) + 1
        return min(length, max(1, shown))
    }

    /// How long the typing takes, in seconds.
    static func tickerTotal(length: Int) -> Double {
        tickerStep(length: length) * Double(max(length, 0))
    }
}

/// Lets a light tap through at most `perSecond` times a second, so a burst of clicks doesn't buzz nonstop.
struct UnoHapticGate {
    let minInterval: TimeInterval
    private(set) var last: Date?

    init(perSecond: Double = 4) {
        minInterval = perSecond > 0 ? 1 / perSecond : 0
    }

    mutating func allow(at now: Date = Date()) -> Bool {
        if let last, now.timeIntervalSince(last) < minInterval, now >= last { return false }
        last = now
        return true
    }
}
