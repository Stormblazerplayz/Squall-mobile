import Foundation

/// Add teammate (squall-computer docs/phone-add-teammate.md): bring a new teammate to life from the phone, with the same
/// checks and starting points as Add teammate on the computer.
enum TeamAdd {
    struct Preset: Identifiable, Equatable {
        let id: String
        let label: String
        let role: String
        let brief: String
        let hex: UInt32
    }

    struct Info: Equatable {
        var size: Int
        var max: Int
        var presets: [Preset]
        /// Everyone on the team now, for the name check.
        var names: [String]

        var isFull: Bool { size >= max }
    }

    /// The colors the computer offers.
    static let colors: [UInt32] = [0x4FE3C1, 0x3D9BE9, 0xA78BFA, 0xF59E4B, 0xF6D860, 0xF87171, 0xF472B6, 0x86EFAC]
    static let roleMax = 60
    static let briefMax = 2000
    /// The names the dice picks from, the same as on the computer.
    static let names = ["Nova", "Gale", "Zephyr", "Cirrus", "Volt", "Ember", "Haze", "Mistral", "Sirocco", "Flare", "Drift",
                        "Comet", "Aurora", "Nimbo", "Frost", "Rime", "Pulse", "Echo", "Strata", "Monsoon", "Halo", "Spark",
                        "Vortex", "Breeze", "Tundra", "Sleet", "Ion", "Lumen", "Orion", "Cyclone"]

    /// nil when this computer can't add teammates from the phone.
    static func info(from data: Data?) -> Info? {
        guard let data,
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let team = root["team"] as? [String: Any],
              team["add"] as? Bool == true else { return nil }
        let presets: [Preset] = (team["presets"] as? [[String: Any]] ?? []).compactMap { raw in
            guard let id = raw["id"] as? String, let hex = hexValue(raw["color"] as? String) else { return nil }
            let role = raw["role"] as? String ?? ""
            return Preset(id: id, label: raw["label"] as? String ?? (role.isEmpty ? id : role), role: role,
                          brief: raw["brief"] as? String ?? "", hex: hex)
        }
        let names = (root["bots"] as? [[String: Any]] ?? []).compactMap { $0["name"] as? String }
        return Info(
            size: (team["size"] as? NSNumber)?.intValue ?? names.count,
            max: (team["max"] as? NSNumber)?.intValue ?? 12,
            presets: presets,
            names: names
        )
    }

    // MARK: - Checks (the same as the computer's)

    /// Why this name, role or brief can't be used, or nil when it's all fine.
    static func problem(name: String, role: String, brief: String, info: Info) -> String? {
        if info.isFull { return "The team is full (\(info.max) teammates)." }
        if let bad = TeamManage.nameProblem(name, current: "", others: info.names) { return bad }
        if role.trimmingCharacters(in: .whitespacesAndNewlines).count > roleMax { return "Keep the role to \(roleMax) characters." }
        if brief.trimmingCharacters(in: .whitespacesAndNewlines).count > briefMax { return "Keep what they do to 2,000 characters." }
        return nil
    }

    /// A free name from the list, not `not`. `pick` chooses an index (random unless a test says otherwise).
    static func suggestName(taken: [String], not: String? = nil, pick: (Int) -> Int = { Int.random(in: 0..<$0) }) -> String {
        var used = Set(taken.map { $0.lowercased() })
        if let not { used.insert(not.lowercased()) }
        let free = names.filter { !used.contains($0.lowercased()) }
        guard !free.isEmpty else { return "Bot\(taken.count + 1)" }
        return free[min(max(0, pick(free.count)), free.count - 1)]
    }

    // MARK: - Colors

    static func hexValue(_ text: String?) -> UInt32? {
        guard let text, text.count == 7, text.hasPrefix("#") else { return nil }
        return UInt32(text.dropFirst(), radix: 16)
    }

    static func hexString(_ hex: UInt32) -> String {
        String(format: "#%06X", hex & 0xFFFFFF)
    }

    // MARK: - Action

    static func action(name: String, role: String, hex: UInt32, brief: String) -> SyncAction {
        SyncAction(type: "bot.add", fields: [
            "name": .string(name.trimmingCharacters(in: .whitespacesAndNewlines)),
            "role": .string(role.trimmingCharacters(in: .whitespacesAndNewlines)),
            "color": .string(hexString(hex)),
            "prompt": .string(brief.trimmingCharacters(in: .whitespacesAndNewlines)),
        ])
    }
}
