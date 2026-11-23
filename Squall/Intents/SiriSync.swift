import AppIntents
import CoreSpotlight
import Foundation
import UniformTypeIdentifiers

/// Keeps Siri and Spotlight in step with the real team on the computer:
/// - Siri learns each bot's name, so "Ask Builder in Squall" works without setup;
/// - Spotlight lists each bot, and tapping one opens its chat.
/// Only real bots from the computer go in, and everything comes out again on Unpair.
@MainActor
enum SiriSync {
    /// Spotlight's group for Squall's bots.
    static let domain = "com.stormblazerplayz.squall.bots"
    /// Each bot's Spotlight id starts with this, then the bot's id.
    static let itemPrefix = "bot:"

    private static var lastSignature: String?

    /// A short fingerprint of what Siri and Spotlight show, so nothing is redone every few seconds.
    static func signature(for bots: [Bot]) -> String {
        bots.map { "\($0.id)|\($0.name)|\($0.role)" }.sorted().joined(separator: "\n")
    }

    /// The bot id inside a Spotlight item id, or nil when it isn't one of Squall's.
    static func botID(fromSpotlightID id: String) -> String? {
        guard id.hasPrefix(itemPrefix) else { return nil }
        let botID = String(id.dropFirst(itemPrefix.count))
        return botID.isEmpty ? nil : botID
    }

    /// Called with each live update from the computer.
    static func update(bots: [Bot]) {
        let signature = signature(for: bots)
        guard signature != lastSignature else { return }
        lastSignature = signature

        // Lets Siri match bot names in phrases like "Ask Builder in Squall".
        SquallShortcuts.updateAppShortcutParameters()

        let items = bots.map { bot -> CSSearchableItem in
            let attributes = CSSearchableItemAttributeSet(contentType: .text)
            attributes.title = bot.name
            attributes.contentDescription = bot.isChief
                ? "Chief, your team lead in Squall"
                : (bot.role.isEmpty ? "Your bot in Squall" : "\(bot.role) in Squall")
            attributes.keywords = ["Squall", "bot", bot.name, bot.role].filter { !$0.isEmpty }
            return CSSearchableItem(uniqueIdentifier: itemPrefix + bot.id, domainIdentifier: domain, attributeSet: attributes)
        }
        let index = CSSearchableIndex.default()
        // Start clean, so a bot that was removed on the computer leaves Spotlight too.
        index.deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in
            guard !items.isEmpty else { return }
            index.indexSearchableItems(items) { _ in }
        }
    }

    /// Called on Unpair: Squall's bots leave Spotlight and Siri forgets their names.
    static func clear() {
        lastSignature = nil
        CSSearchableIndex.default().deleteSearchableItems(withDomainIdentifiers: [domain]) { _ in }
        SquallShortcuts.updateAppShortcutParameters()
    }
}
