import AppIntents

/// Squall's Focus filter: Settings > Focus > (a Focus) > Add Filter > Squall. While that Focus is on, only the pings
/// picked here get through. When the Focus ends, iOS runs this again with the defaults, which lets everything through.
struct SquallFocusFilter: SetFocusFilterIntent {
    static let title: LocalizedStringResource = "Squall pings"
    static let description: IntentDescription? = IntentDescription(
        "Pick which Squall pings get through while this Focus is on. Your team keeps working either way."
    )

    @Parameter(title: "Let through", default: .everything)
    var pings: FocusRules.Pings

    @Parameter(title: "Without sound", default: false)
    var silent: Bool

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(FocusRules(pings: pings, silent: silent).summary)")
    }

    func perform() async throws -> some IntentResult {
        FocusRules.save(FocusRules(pings: pings, silent: silent, since: Date()))
        return .result()
    }
}

extension FocusRules.Pings: AppEnum {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Pings"
    static let caseDisplayRepresentations: [FocusRules.Pings: DisplayRepresentation] = [
        .everything: DisplayRepresentation(title: "Everything", image: .init(systemName: "bell.fill")),
        .needsYou: DisplayRepresentation(title: "Only when a teammate needs me", image: .init(systemName: "exclamationmark.bubble.fill")),
        .chief: DisplayRepresentation(title: "Only Chief", image: .init(systemName: "bolt.fill")),
        .nothing: DisplayRepresentation(title: "Nothing", image: .init(systemName: "bell.slash.fill")),
    ]
}
