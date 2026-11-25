import Foundation

/// The model the team runs on (squall-computer docs/phone-models.md): "By role" or one model for every bot,
/// plus the model each teammate last ran on. Read from the state's `models` block and `bots[].model`.
enum TeamModel {
    struct Choice: Identifiable, Equatable {
        let id: String
        let name: String
        let note: String
    }

    struct Info: Equatable {
        var current: String
        var choices: [Choice]
        /// The model each teammate last ran on, by bot id.
        var running: [String: String]

        var currentName: String { TeamModel.name(current, in: choices) }
    }

    static func info(from data: Data?) -> Info? {
        guard let data,
              let root = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let models = root["models"] as? [String: Any] else { return nil }
        var seen = Set<String>()
        let choices: [Choice] = (models["choices"] as? [[String: Any]] ?? []).compactMap { raw in
            guard let id = raw["id"] as? String, seen.insert(id).inserted else { return nil }
            let name = (raw["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? (id.isEmpty ? "By role" : id)
            return Choice(id: id, name: name, note: raw["note"] as? String ?? "")
        }
        guard !choices.isEmpty else { return nil }
        var running: [String: String] = [:]
        for bot in root["bots"] as? [[String: Any]] ?? [] {
            if let id = bot["id"] as? String, let model = bot["model"] as? String, !model.isEmpty { running[id] = model }
        }
        let current = models["current"] as? String ?? ""
        return Info(current: choices.contains { $0.id == current } ? current : "", choices: choices, running: running)
    }

    /// The choice's name, or a tidy version of an id the list doesn't have ("claude-sonnet-5-5" reads "Sonnet 5.5").
    static func name(_ id: String, in choices: [Choice]) -> String {
        if let choice = choices.first(where: { $0.id == id }) { return choice.name }
        if id.isEmpty { return "By role" }
        var parts = id.split(separator: "-").map(String.init)
        if parts.first == "claude" { parts.removeFirst() }
        guard let family = parts.first else { return id }
        let numbers = parts.dropFirst().filter { Int($0) != nil }
        let version = numbers.prefix(2).joined(separator: ".")
        let title: String = family.prefix(1).uppercased() + String(family.dropFirst())
        return version.isEmpty ? title : "\(title) \(version)"
    }

    enum Kind {
        case byRole, haiku, sonnet, opus, fable, other

        init(_ id: String) {
            let lower = id.lowercased()
            if lower.isEmpty { self = .byRole }
            else if lower.contains("haiku") { self = .haiku }
            else if lower.contains("sonnet") { self = .sonnet }
            else if lower.contains("opus") { self = .opus }
            else if lower.contains("fable") { self = .fable }
            else { self = .other }
        }

        var icon: String {
            switch self {
            case .byRole: return "person.3.sequence.fill"
            case .haiku: return "hare.fill"
            case .sonnet: return "sparkles"
            case .opus: return "brain.head.profile"
            case .fable: return "wand.and.stars"
            case .other: return "cpu"
            }
        }

        /// How much of the plan it uses, 1 (light) to 4 (heavy); 0 when it depends.
        var weight: Int {
            switch self {
            case .byRole, .other: return 0
            case .haiku: return 1
            case .sonnet: return 2
            case .opus: return 3
            case .fable: return 4
            }
        }

        var hex: UInt32 {
            switch self {
            case .byRole: return 0x8B90A3
            case .haiku: return 0x4ADE80
            case .sonnet: return 0x3D9BE9
            case .opus: return 0xA78BFA
            case .fable: return 0xF5B83D
            case .other: return 0x8B90A3
            }
        }
    }

    static func action(_ id: String) -> SyncAction {
        SyncAction(type: "team.model", fields: ["model": .string(id)])
    }
}
