import Combine
import Foundation

/// Saved prompts: messages you send often, kept on this phone so you can drop one into any chat with a tap.
/// `{name}` in a prompt becomes the teammate's name and `{today}` becomes today's date when it's used.
final class SavedPrompts: ObservableObject {
    struct Item: Codable, Identifiable, Equatable {
        let id: String
        var title: String
        var text: String
        var uses: Int
        var lastUsed: Date?
        let created: Date
    }

    enum Order: String, CaseIterable, Identifiable {
        case mostUsed
        case recent
        case name

        var id: String { rawValue }

        var label: String {
            switch self {
            case .mostUsed: return "Most used"
            case .recent: return "Recent"
            case .name: return "A to Z"
            }
        }
    }

    static let shared = SavedPrompts()
    static let maxItems = 100
    static let maxTitle = 40
    static let maxText = 4000

    @Published private(set) var items: [Item] = []

    /// A prompt picked to go into a chat's message box. The chat takes it and sets this back to nil.
    struct Insert: Equatable {
        let chatID: String
        let text: String
    }

    @Published var insert: Insert?
    /// What's in the open chat's message box right now, so Saved prompts can offer to save it.
    var currentDraft = ""

    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "squall.savedPrompts") {
        self.defaults = defaults
        self.key = key
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode([Item].self, from: data) {
            items = Array(saved.prefix(Self.maxItems))
        }
    }

    // MARK: - Words

    /// The text to keep: trimmed and capped.
    static func cleanText(_ raw: String) -> String {
        String(raw.trimmingCharacters(in: .whitespacesAndNewlines).prefix(maxText))
    }

    /// The title to keep. An empty one is made from the prompt's first words.
    static func cleanTitle(_ raw: String, text: String) -> String {
        let typed = raw.replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
        if !typed.isEmpty { return String(typed.prefix(maxTitle)) }
        let firstLine = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let words = firstLine.split(separator: " ").prefix(6).joined(separator: " ")
        let title = String(words.prefix(maxTitle)).trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? "Prompt" : title
    }

    /// The prompt with `{name}` and `{today}` filled in.
    static func fill(_ text: String, name: String, now: Date = Date(), calendar: Calendar = .current) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEEE, MMM d"
        return text
            .replacingOccurrences(of: "{name}", with: name, options: .caseInsensitive)
            .replacingOccurrences(of: "{today}", with: formatter.string(from: now), options: .caseInsensitive)
    }

    /// True when the prompt has a blank that gets filled in.
    static func hasBlanks(_ text: String) -> Bool {
        let lower = text.lowercased()
        return lower.contains("{name}") || lower.contains("{today}")
    }

    // MARK: - Lists

    static func sorted(_ list: [Item], by order: Order) -> [Item] {
        switch order {
        case .mostUsed:
            return list.sorted {
                if $0.uses != $1.uses { return $0.uses > $1.uses }
                return $0.created > $1.created
            }
        case .recent:
            return list.sorted { ($0.lastUsed ?? $0.created) > ($1.lastUsed ?? $1.created) }
        case .name:
            return list.sorted {
                let order = $0.title.localizedCaseInsensitiveCompare($1.title)
                return order == .orderedSame ? $0.created < $1.created : order == .orderedAscending
            }
        }
    }

    static func filter(_ list: [Item], words: String) -> [Item] {
        let needle = words.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return list }
        return list.filter { $0.title.lowercased().contains(needle) || $0.text.lowercased().contains(needle) }
    }

    // MARK: - Changes

    /// Why a prompt can't be saved, or nil when it can.
    func problem(text: String, editing id: String? = nil) -> String? {
        let clean = Self.cleanText(text)
        if clean.isEmpty { return "Type the prompt first." }
        if id == nil, items.count >= Self.maxItems { return "You have \(Self.maxItems) prompts. Delete one first." }
        if items.contains(where: { $0.id != id && $0.text == clean }) { return "You already saved this prompt." }
        return nil
    }

    /// Saves a new prompt and returns it, or nil when it can't be saved.
    @discardableResult
    func add(title: String, text: String, now: Date = Date()) -> Item? {
        guard problem(text: text) == nil else { return nil }
        let clean = Self.cleanText(text)
        let item = Item(id: UUID().uuidString, title: Self.cleanTitle(title, text: clean), text: clean,
                        uses: 0, lastUsed: nil, created: now)
        items.insert(item, at: 0)
        save()
        return item
    }

    /// Changes a prompt's title and words. Returns false when it can't.
    @discardableResult
    func update(_ id: String, title: String, text: String) -> Bool {
        guard let index = items.firstIndex(where: { $0.id == id }), problem(text: text, editing: id) == nil else { return false }
        let clean = Self.cleanText(text)
        items[index].text = clean
        items[index].title = Self.cleanTitle(title, text: clean)
        save()
        return true
    }

    /// Counts a use and returns the prompt filled in for this teammate.
    func use(_ id: String, name: String, now: Date = Date()) -> String? {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return nil }
        items[index].uses += 1
        items[index].lastUsed = now
        save()
        return Self.fill(items[index].text, name: name, now: now)
    }

    func remove(_ id: String) {
        items.removeAll { $0.id == id }
        save()
    }

    func clear() {
        items = []
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            defaults.set(data, forKey: key)
        }
    }
}
