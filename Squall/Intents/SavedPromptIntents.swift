import AppIntents
import Foundation

// "Ask with a saved prompt": a Shortcuts action that sends one of your saved prompts to Chief, or the bot you pick,
// and reads you the answer. {name} and {today} are filled in the same way as in a chat.

/// One saved prompt, as Shortcuts and Siri see it.
struct SavedPromptEntity: AppEntity, Identifiable {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Saved prompt"
    static let defaultQuery = SavedPromptQuery()

    let id: String
    let title: String
    let preview: String

    init(id: String, title: String, preview: String) {
        self.id = id
        self.title = title
        self.preview = preview
    }

    init(_ item: SavedPrompts.Item) {
        self.init(id: item.id, title: item.title, preview: SavedPromptPicker.preview(item.text))
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(title)", subtitle: "\(preview)", image: .init(systemName: "text.bubble.fill"))
    }
}

/// The plain rules behind the picker, kept apart so they can be tested.
enum SavedPromptPicker {
    static let previewLength = 60

    /// The first line of a prompt, cut to fit under its title.
    static func preview(_ text: String) -> String {
        let line = text.split(whereSeparator: \.isNewline).first.map(String.init) ?? ""
        let clean = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard clean.count > previewLength else { return clean }
        return String(clean.prefix(previewLength - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// The prompts to offer: most used first, like the Saved prompts screen.
    static func suggested(_ items: [SavedPrompts.Item]) -> [SavedPrompts.Item] {
        SavedPrompts.sorted(items, by: .mostUsed)
    }

    /// Prompts whose title or words contain what was said or typed.
    static func matching(_ words: String, in items: [SavedPrompts.Item]) -> [SavedPrompts.Item] {
        let needle = words.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return suggested(items) }
        return suggested(SavedPrompts.filter(items, words: needle))
    }

    /// What gets sent: the prompt filled in for the bot, counted as a use. Nil when it isn't saved anymore.
    static func question(promptID: String, botName: String, prompts: SavedPrompts, now: Date = Date()) -> String? {
        guard let text = prompts.use(promptID, name: botName, now: now) else { return nil }
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return clean.isEmpty ? nil : clean
    }

    static let goneText = "That prompt isn't saved anymore. Open Squall to pick another."
}

struct SavedPromptQuery: EntityStringQuery {
    init() {}

    @MainActor
    private func items() -> [SavedPrompts.Item] { SavedPrompts.shared.items }

    func entities(for identifiers: [String]) async throws -> [SavedPromptEntity] {
        let list = await items()
        return identifiers.compactMap { id in list.first(where: { $0.id == id }).map(SavedPromptEntity.init) }
    }

    func entities(matching string: String) async throws -> [SavedPromptEntity] {
        SavedPromptPicker.matching(string, in: await items()).map(SavedPromptEntity.init)
    }

    func suggestedEntities() async throws -> [SavedPromptEntity] {
        SavedPromptPicker.suggested(await items()).map(SavedPromptEntity.init)
    }
}

/// "Ask with a saved prompt": sends a saved prompt to Chief, or the bot you pick, and reads you the answer.
struct AskSavedPromptIntent: AppIntent {
    static let title: LocalizedStringResource = "Ask with a saved prompt"
    static let description = IntentDescription("Sends one of your saved prompts to Chief, or the bot you pick, and reads you its answer.")
    static let openAppWhenRun = false
    static let authenticationPolicy: IntentAuthenticationPolicy = .requiresAuthentication

    @Parameter(title: "Prompt", requestValueDialog: "Which saved prompt?")
    var prompt: SavedPromptEntity

    @Parameter(title: "Bot", description: "Leave empty to ask Chief.")
    var bot: BotEntity?

    init() {}

    init(prompt: SavedPromptEntity, bot: BotEntity? = nil) {
        self.prompt = prompt
        self.bot = bot
    }

    static var parameterSummary: some ParameterSummary {
        Summary("Ask \(\.$bot) with \(\.$prompt)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let link = PairingLink()
        guard link.isPaired else {
            let answer = SquallSiri.notPaired()
            return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
        }
        let botID = bot?.id ?? Bot.chiefID
        let botName = bot?.name ?? "Chief"
        guard let question = SavedPromptPicker.question(promptID: prompt.id, botName: botName, prompts: .shared) else {
            let gone = SiriSnippet.notice(title: "Prompt not found", detail: SavedPromptPicker.goneText, symbol: "text.bubble")
            return .result(dialog: "\(SavedPromptPicker.goneText)", view: SiriSnippetView(snippet: gone))
        }
        let answer = await SquallSiri(link: link).ask(botID: botID, question: question)
        return .result(dialog: "\(answer.spoken)", view: SiriSnippetView(snippet: answer.snippet))
    }
}
