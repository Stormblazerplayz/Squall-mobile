import AppIntents
import Foundation

/// A bot on your computer, so Siri and Shortcuts can ask "Which bot?" and you can say its name.
/// The list always comes from the paired computer (or the last real copy saved from it).
struct BotEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Bot"
    static let defaultQuery = BotQuery()

    let id: String
    let name: String
    let role: String

    init(id: String, name: String, role: String) {
        self.id = id
        self.name = name
        self.role = role
    }

    init(_ bot: Bot) {
        self.init(id: bot.id, name: bot.name, role: bot.role)
    }

    var displayRepresentation: DisplayRepresentation {
        let subtitle: LocalizedStringResource? = role.isEmpty ? nil : "\(role)"
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: subtitle,
            image: .init(systemName: id == Bot.chiefID ? "bolt.fill" : "person.fill")
        )
    }
}

/// Finds bots for Siri: the ones on the computer now, or the last real copy when it isn't answering.
struct BotQuery: EntityStringQuery {
    init() {}

    @MainActor
    static func currentBots(link given: SiriLink? = nil) async -> [Bot] {
        let link = given ?? PairingLink()
        guard link.isPaired else { return [] }
        if let state = try? await link.fetchState() {
            return state.bots.map(\.model).sorted { $0.isChief && !$1.isChief }
        }
        return (link.savedState()?.snapshot.bots.map(\.model) ?? []).sorted { $0.isChief && !$1.isChief }
    }

    func entities(for identifiers: [String]) async throws -> [BotEntity] {
        let bots = await Self.currentBots()
        return identifiers.compactMap { id in bots.first(where: { $0.id == id }).map(BotEntity.init) }
    }

    func entities(matching string: String) async throws -> [BotEntity] {
        BotMatcher.matches(string, in: await Self.currentBots()).map(BotEntity.init)
    }

    func suggestedEntities() async throws -> [BotEntity] {
        await Self.currentBots().map(BotEntity.init)
    }
}
