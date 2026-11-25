import AppIntents

/// Squall's Focus filter: Settings > Focus > (a Focus) > Add Filter > Squall. While that Focus is on, only the pings
/// picked here get through. When the Focus ends, iOS runs this again with the defaults, which lets everything through.
struct SquallFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Squall pings"
    static let description: IntentDescription? = IntentDescription(
        "Pick which Squall pings get through while this Focus is on. Your team keeps working either way."
    )

    @Parameter(title: "Let through", default: .everything)
    var pings: FocusPingsOption

    @Parameter(title: "Without sound", default: false)
    var silent: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(FocusRules(pings: pings.rules, silent: silent).summary)")
    }

    func perform() async throws -> some IntentResult {
        FocusRules.save(FocusRules(pings: pings.rules, silent: silent, since: Date()))
        return .result()
    }
}

/// The choices in the Focus filter. A type of its own, declared in one piece, because the App Intents build step
/// reads these names at build time and can't read them from an extension of FocusRules.Pings.
enum FocusPingsOption: String, AppEnum {
    case everything
    case needsYou
    case chief
    case nothing

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Pings"

    static var caseDisplayRepresentations: [FocusPingsOption: DisplayRepresentation] = [
        .everything: DisplayRepresentation(title: "Everything", image: .init(systemName: "bell.fill")),
        .needsYou: DisplayRepresentation(title: "Only when a teammate needs me", image: .init(systemName: "exclamationmark.bubble.fill")),
        .chief: DisplayRepresentation(title: "Only Chief", image: .init(systemName: "bolt.fill")),
        .nothing: DisplayRepresentation(title: "Nothing", image: .init(systemName: "bell.slash.fill")),
    ]

    /// The same choice as Squall saves it.
    var rules: FocusRules.Pings {
        FocusRules.Pings(rawValue: rawValue) ?? .everything
    }
}
