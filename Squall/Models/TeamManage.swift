import Foundation

/// Manage teammate: rename, chief on or off, and remove. Squall on the computer does the work with the same checks as its
/// right-click menu (squall-computer docs/phone-teammates.md); the phone checks the same rules first so the buttons
/// say why something can't be done.
enum TeamManage {
    /// The team's limits and its chiefs, from the state's `team` block and `bots[].chief`.
    struct Info: Equatable {
        var size: Int
        var max: Int
        var chiefs: Int
        var maxChiefs: Int
        /// True when this computer can do the manage actions. An older one doesn't send the block at all.
        var manage: Bool
        var chiefIDs: Set<String>

        func isChief(_ botID: String) -> Bool { chiefIDs.contains(botID) }
    }

    /// The team block in a state reply, or nil when the computer doesn't send one.
    static func info(from data: Data?) -> Info? {
        guard let data,
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let team = root["team"] as? [String: Any] else { return nil }
        var chiefs = Set<String>()
        for bot in root["bots"] as? [[String: Any]] ?? [] {
            if let id = bot["id"] as? String, bot["chief"] as? Bool == true { chiefs.insert(id) }
        }
        func number(_ key: String, _ fallback: Int) -> Int {
            (team[key] as? NSNumber)?.intValue ?? fallback
        }
        return Info(
            size: number("size", 0),
            max: number("max", 12),
            chiefs: number("chiefs", chiefs.count),
            maxChiefs: number("maxChiefs", 4),
            manage: team["manage"] as? Bool ?? false,
            chiefIDs: chiefs
        )
    }

    // MARK: - Checks (the same as the computer's)

    /// Why a new name can't be used, or nil when it's fine. A new case of its own name is fine.
    static func nameProblem(_ raw: String, current: String, others: [String]) -> String? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty { return "Pick a name." }
        let letters = name.unicodeScalars
        guard let first = letters.first, isASCIILetter(first),
              letters.allSatisfy({ isASCIILetter($0) || ("0"..."9").contains($0) }),
              (2...20).contains(name.count) else {
            return "Use 2 to 20 letters and digits, starting with a letter."
        }
        if others.contains(where: { $0 != current && $0.lowercased() == name.lowercased() }) {
            return "\(name) is already on the team."
        }
        return nil
    }

    /// Why the chief switch can't be flipped right now, or nil.
    static func chiefBlock(isChief: Bool, info: Info) -> String? {
        if isChief, info.chiefs <= 1 { return "The team needs at least one chief." }
        if !isChief, info.chiefs >= info.maxChiefs { return "The team already has \(info.maxChiefs) chiefs." }
        return nil
    }

    /// Why this teammate can't be removed right now, or nil.
    static func removeBlock(isChief: Bool, info: Info) -> String? {
        if isChief, info.chiefs <= 1 { return "This is the only chief. Make someone else chief first." }
        return nil
    }

    // MARK: - Actions for the computer

    static func renameAction(botID: String, name: String) -> SyncAction {
        SyncAction(type: "bot.rename", fields: [
            "botId": .string(botID),
            "name": .string(name.trimmingCharacters(in: .whitespacesAndNewlines)),
        ])
    }

    static func chiefAction(botID: String, on: Bool) -> SyncAction {
        SyncAction(type: "bot.chief", fields: ["botId": .string(botID), "on": .bool(on)])
    }

    /// `confirm` is the name the phone showed, so a stale screen can't remove someone else.
    static func removeAction(botID: String, confirm: String) -> SyncAction {
        SyncAction(type: "bot.remove", fields: ["botId": .string(botID), "confirm": .string(confirm)])
    }

    private static func isASCIILetter(_ scalar: Unicode.Scalar) -> Bool {
        ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar)
    }
}
