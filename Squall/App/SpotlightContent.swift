import Combine
import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// Starred messages and saved prompts in iPhone Search. Tapping a starred message opens its chat; tapping a saved prompt
/// opens Chief's chat with the prompt in the message box.
/// Everything here is already on this phone; nothing new comes from or goes to the computer.
/// It's off while App Lock is on, because Search would show your words without asking for Face ID.
@MainActor
enum SpotlightContent {
    static let starredDomain = "com.stormblazerplayz.squall.starred"
    static let promptsDomain = "com.stormblazerplayz.squall.prompts"
    static let starPrefix = "star:"
    static let promptPrefix = "prompt:"
    /// Settings switch. Missing means on.
    static let onKey = "squall.spotlight.content"
    static let maxStarred = 200
    static let maxText = 600

    /// What one Spotlight result shows.
    struct Entry: Equatable {
        let id: String
        let domain: String
        let title: String
        let text: String
        let keywords: [String]
    }

    /// Where a tapped result goes.
    enum Target: Equatable {
        case chat(String)
        case prompt(String)
    }

    private static var lastSignature: String?
    private static var watching: Set<AnyCancellable> = []

    // MARK: - Rules

    static func isOn(defaults: UserDefaults = .standard) -> Bool {
        let wanted = defaults.object(forKey: onKey) as? Bool ?? true
        return wanted && !defaults.bool(forKey: Prefs.appLock)
    }

    /// The results to show: newest starred messages first, then every saved prompt.
    static func entries(starred: [StarredMessages.Item], prompts: [SavedPrompts.Item], chatNames: [String: String]) -> [Entry] {
        let stars = starred
            .sorted { $0.savedAt > $1.savedAt }
            .prefix(maxStarred)
            .map { item -> Entry in
                let chat = chatNames[item.chatID] ?? item.authorName
                let mine = item.author == ChatMessage.meID
                return Entry(
                    id: starPrefix + item.id,
                    domain: starredDomain,
                    title: mine ? "You to \(chat)" : item.authorName,
                    text: clip(Markdown.plain(item.text)),
                    keywords: ["Squall", "starred", chat].filter { !$0.isEmpty }
                )
            }
        let saved = SavedPrompts.sorted(prompts, by: .mostUsed).map { item in
            Entry(id: promptPrefix + item.id, domain: promptsDomain, title: item.title,
                  text: clip(item.text), keywords: ["Squall", "prompt", "saved prompt"])
        }
        return stars + saved
    }

    /// Where a Spotlight id goes, or nil when it isn't one of these.
    static func target(fromSpotlightID id: String, starred: [StarredMessages.Item]) -> Target? {
        if id.hasPrefix(starPrefix) {
            let starID = String(id.dropFirst(starPrefix.count))
            if let item = starred.first(where: { $0.id == starID }) { return .chat(item.chatID) }
            // Unstarred since: the chat id is the part before the slash.
            guard let chatID = starID.split(separator: "/", maxSplits: 1).first, !chatID.isEmpty else { return nil }
            return .chat(String(chatID))
        }
        if id.hasPrefix(promptPrefix) {
            let promptID = String(id.dropFirst(promptPrefix.count))
            return promptID.isEmpty ? nil : .prompt(promptID)
        }
        return nil
    }

    static func signature(_ entries: [Entry]) -> String {
        entries.map { "\($0.id)|\($0.title)|\($0.text)" }.joined(separator: "\n")
    }

    static func clip(_ text: String) -> String {
        let flat = text.split(whereSeparator: { $0.isWhitespace || $0.isNewline }).joined(separator: " ")
        guard flat.count > maxText else { return flat }
        return String(flat.prefix(maxText - 1)) + "…"
    }

    // MARK: - Spotlight

    /// Starts keeping Search in step with starred messages and saved prompts. Called once at launch.
    static func start(store: SquallStore) {
        guard watching.isEmpty else { return }
        StarredMessages.shared.$items
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak store] _ in
                let current = store
                Task { @MainActor in update(store: current) }
            }
            .store(in: &watching)
        SavedPrompts.shared.$items
            .dropFirst()
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak store] _ in
                let current = store
                Task { @MainActor in update(store: current) }
            }
            .store(in: &watching)
        update(store: store)
    }

    /// Puts the current starred messages and saved prompts in Search, or takes them out when it's off.
    static func update(store: SquallStore?, force: Bool = false) {
        guard isOn() else {
            if lastSignature != "" || force {
                lastSignature = ""
                remove()
            }
            return
        }
        var names: [String: String] = [:]
        for bot in store?.bots ?? [] { names[bot.id] = bot.name }
        let list = entries(starred: StarredMessages.shared.items, prompts: SavedPrompts.shared.items, chatNames: names)
        let signature = signature(list)
        guard force || signature != lastSignature else { return }
        lastSignature = signature
        let items = list.map { entry -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = entry.title
            attributes.contentDescription = entry.text
            attributes.keywords = entry.keywords
            return CSSearchableItem(uniqueIdentifier: entry.id, domainIdentifier: entry.domain, attributeSet: attributes)
        }
        let index = CSSearchableIndex.default()
        // Start clean, so something unstarred or deleted leaves Search too.
        index.deleteSearchableItems(withDomainIdentifiers: [starredDomain, promptsDomain]) { _ in
            guard !items.isEmpty else { return }
            index.indexSearchableItems(items) { _ in }
        }
    }

    /// Takes everything out of Search.
    static func remove() {
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [starredDomain, promptsDomain]) { _ in }
    }

    /// Opens what a tapped result points at. Returns false when the id isn't one of these.
    @discardableResult
    static func open(spotlightID id: String, store: SquallStore) -> Bool {
        guard let target = target(fromSpotlightID: id, starred: StarredMessages.shared.items) else { return false }
        switch target {
        case .chat(let chatID):
            if let url = URL(string: "squall://chat/\(chatID)") { store.open(url) }
        case .prompt(let promptID):
            let chief = store.bot(Bot.chiefID)
            if let text = SavedPrompts.shared.use(promptID, name: chief?.name ?? "Chief") {
                SavedPrompts.shared.insert = SavedPrompts.Insert(chatID: Bot.chiefID, text: text)
            } else {
                store.showToast("That prompt isn't saved anymore.")
            }
            if let url = URL(string: "squall://chat/\(Bot.chiefID)") { store.open(url) }
        }
        return true
    }
}
