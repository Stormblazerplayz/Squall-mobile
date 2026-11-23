import XCTest
@testable import Squall

// Tests for Siri and Shortcuts. They run `SquallSiri` against a stand-in computer (`FakeLink`)
// that answers with the same JSON the real Squall desktop sends. The stand-in only exists here,
// in the tests; the app itself always talks to the real paired computer.

@MainActor
final class FakeLink: SiriLink {
    var isPaired = true
    var computerName: String? = "Test-PC"
    /// Answers to GET /api/v1/state, in order. The last one keeps repeating.
    var states: [Result<StateSnapshot, Error>] = []
    var sendError: Error?
    var saved: (snapshot: StateSnapshot, savedAt: Date)?
    private(set) var sent: [SyncAction] = []
    private(set) var fetchCount = 0

    func fetchState() async throws -> StateSnapshot {
        fetchCount += 1
        guard let next = states.first else { throw PairingError.cantReach }
        if states.count > 1 { states.removeFirst() }
        return try next.get()
    }

    func send(_ action: SyncAction) async throws {
        if let sendError { throw sendError }
        sent.append(action)
    }

    func savedState() -> (snapshot: StateSnapshot, savedAt: Date)? {
        saved
    }
}

/// Builds a state the way the computer sends it.
enum TestState {
    static func make(
        chiefStatus: String = "idle",
        chiefTask: String? = nil,
        builderStatus: String = "idle",
        builderTask: String? = nil,
        typing: String? = nil,
        paused: Bool = false,
        chats: [String: [[String: Any]]] = [:],
        inbox: [[String: Any]] = []
    ) -> StateSnapshot {
        var chief: [String: Any] = ["id": "chief", "name": "Chief", "color": "#F5B83D", "role": "Team lead", "status": chiefStatus]
        if let chiefTask { chief["task"] = chiefTask }
        var builder: [String: Any] = ["id": "builder", "name": "Builder", "color": "#3A8DE0", "role": "Builds things", "status": builderStatus]
        if let builderTask { builder["task"] = builderTask }
        var json: [String: Any] = [
            "paused": paused,
            "bots": [builder, chief],
            "chats": chats,
            "inbox": inbox
        ]
        if let typing { json["typing"] = typing }
        return decode(json)
    }

    static func decode(_ json: [String: Any]) -> StateSnapshot {
        let data = try! JSONSerialization.data(withJSONObject: json)
        return try! JSONDecoder().decode(StateSnapshot.self, from: data)
    }

    static func me(_ id: String, _ text: String) -> [String: Any] {
        ["id": id, "kind": "me", "text": text]
    }

    static func bot(_ id: String, _ author: String, _ text: String, kind: String = "bot") -> [String: Any] {
        ["id": id, "kind": kind, "author": author, "text": text]
    }

    static func ask(_ id: String, bot: String, title: String, command: String? = nil) -> [String: Any] {
        var item: [String: Any] = ["id": id, "kind": "ask", "botId": bot, "title": title, "unread": true]
        if let command { item["command"] = command }
        return item
    }
}

@MainActor
final class SiriTests: XCTestCase {
    private func siri(_ link: FakeLink) -> SquallSiri {
        SquallSiri(link: link, pollEvery: .zero, waitFor: .milliseconds(40))
    }

    private func field(_ action: SyncAction, _ key: String) -> JSONValue? {
        action.fields[key]
    }

    // MARK: Ask

    func testAskChiefReadsTheRealAnswerOnceItIsDone() async {
        let link = FakeLink()
        let question = "Did the build pass?"
        let history: [[String: Any]] = [TestState.me("m1", "hi"), TestState.bot("m2", "chief", "Hey Storm.")]
        let writing = history + [TestState.me("m3", question), TestState.bot("m4", "chief", "The build")]
        let done = history + [TestState.me("m3", question), TestState.bot("m4", "chief", "The build **passed** on `main`.")]
        link.states = [
            .success(TestState.make(chats: ["chief": history])),
            .success(TestState.make(chiefStatus: "working", typing: "chief", chats: ["chief": writing])),
            .success(TestState.make(chats: ["chief": done]))
        ]

        let answer = await siri(link).ask(botID: "chief", question: "  \(question) ")

        XCTAssertEqual(answer.spoken, "The build passed on main.")
        guard case let .reply(bot, asked, text, finished) = answer.snippet else {
            return XCTFail("Expected a reply card, got \(answer.snippet)")
        }
        XCTAssertEqual(bot.id, "chief")
        XCTAssertEqual(asked, question)
        XCTAssertEqual(text, "The build **passed** on `main`.")
        XCTAssertTrue(finished)
        XCTAssertEqual(link.sent.count, 1)
        XCTAssertEqual(link.sent.first?.type, "chat.send")
        XCTAssertEqual(link.sent.first.flatMap { field($0, "chatId") }, .string("chief"))
        XCTAssertEqual(link.sent.first.flatMap { field($0, "text") }, .string(question))
    }

    func testAskNeverReadsAnOldAnswerToTheSameQuestion() async {
        let link = FakeLink()
        let question = "Status?"
        let old: [[String: Any]] = [TestState.me("a", question), TestState.bot("b", "chief", "Old answer.")]
        let fresh = old + [TestState.me("c", question), TestState.bot("d", "chief", "New answer.")]
        link.states = [
            .success(TestState.make(chats: ["chief": old])),
            // The computer hasn't shown the new message yet.
            .success(TestState.make(chats: ["chief": old])),
            .success(TestState.make(chats: ["chief": fresh]))
        ]

        let answer = await siri(link).ask(botID: "chief", question: question)

        XCTAssertEqual(answer.spoken, "New answer.")
    }

    func testAskABotIsNotFooledByAnotherBotTyping() async {
        let link = FakeLink()
        let question = "What are you on?"
        let chat: [[String: Any]] = [TestState.me("q", question), TestState.bot("r", "builder", "Fixing the login screen.")]
        link.states = [
            .success(TestState.make(chats: ["builder": []])),
            .success(TestState.make(chiefStatus: "working", typing: "chief", chats: ["builder": chat]))
        ]

        let answer = await siri(link).ask(botID: "builder", question: question)

        XCTAssertEqual(answer.spoken, "Fixing the login screen.")
        XCTAssertEqual(link.sent.first.flatMap { field($0, "chatId") }, .string("builder"))
    }

    func testAskWaitsWhileTheBotIsStillWriting() async {
        let link = FakeLink()
        let question = "Plan the week"
        let chat: [[String: Any]] = [TestState.me("q", question), TestState.bot("r", "chief", "First, the build.")]
        link.states = [
            .success(TestState.make(chats: ["chief": []])),
            .success(TestState.make(chiefStatus: "working", typing: "chief", chats: ["chief": chat]))
        ]

        let answer = await siri(link).ask(botID: "chief", question: question)

        XCTAssertTrue(answer.spoken.hasPrefix("First, the build."), answer.spoken)
        XCTAssertTrue(answer.spoken.contains("Chief is still going"), answer.spoken)
        guard case let .reply(_, _, text, finished) = answer.snippet else {
            return XCTFail("Expected a reply card")
        }
        XCTAssertEqual(text, "First, the build.")
        XCTAssertFalse(finished)
    }

    func testAskSaysWhenTheBotIsStillThinking() async {
        let link = FakeLink()
        link.states = [
            .success(TestState.make(chats: ["chief": []])),
            .success(TestState.make(chiefStatus: "working", typing: "chief", chats: ["chief": [TestState.me("q", "Hard one")]]))
        ]

        let answer = await siri(link).ask(botID: "chief", question: "Hard one")

        XCTAssertEqual(answer.spoken, "Chief got it and is still thinking. The answer will be in your chat with Chief in Squall.")
        guard case let .reply(_, _, text, finished) = answer.snippet else {
            return XCTFail("Expected a reply card")
        }
        XCTAssertEqual(text, "")
        XCTAssertFalse(finished)
    }

    func testAskReportsAProblemFromTheComputer() async {
        let link = FakeLink()
        let chat: [[String: Any]] = [TestState.me("q", "Go"), TestState.bot("e", "chief", "Claude isn't signed in.", kind: "error")]
        link.states = [
            .success(TestState.make(chats: ["chief": []])),
            .success(TestState.make(chats: ["chief": chat]))
        ]

        let answer = await siri(link).ask(botID: "chief", question: "Go")

        XCTAssertEqual(answer.spoken, "Chief hit a problem: Claude isn't signed in.")
    }

    func testAskWhenNotPairedSendsNothing() async {
        let link = FakeLink()
        link.isPaired = false

        let answer = await siri(link).ask(botID: "chief", question: "Hi")

        XCTAssertEqual(answer.spoken, SquallSiri.notPairedText)
        XCTAssertEqual(link.fetchCount, 0)
        XCTAssertTrue(link.sent.isEmpty)
    }

    func testAskWhenTheComputerIsAwaySaysSo() async {
        let link = FakeLink()
        link.states = [.failure(PairingError.cantReach)]

        let answer = await siri(link).ask(botID: "chief", question: "Hi")

        XCTAssertEqual(answer.spoken, "Nothing was sent. \(PairingError.cantReach.message)")
        XCTAssertTrue(link.sent.isEmpty)
        guard case let .notice(title, _, _) = answer.snippet else {
            return XCTFail("Expected a notice card")
        }
        XCTAssertEqual(title, "Can't reach Test-PC")
    }

    func testAskWhenTheComputerForgotThisPhone() async {
        let link = FakeLink()
        link.states = [.failure(PairingError.tokenRejected)]

        let answer = await siri(link).ask(botID: "chief", question: "Hi")

        XCTAssertEqual(answer.spoken, "Nothing was sent. \(PairingError.tokenRejected.message)")
    }

    func testAskWhenTheSendIsRefused() async {
        let link = FakeLink()
        link.states = [.success(TestState.make())]
        link.sendError = SyncActionError(message: "Squall couldn't send that. Is it signed in to Claude?")

        let answer = await siri(link).ask(botID: "chief", question: "Hi")

        XCTAssertEqual(answer.spoken, "Chief didn't get it. Squall couldn't send that. Is it signed in to Claude?")
    }

    func testAskABotThatIsGone() async {
        let link = FakeLink()
        link.states = [.success(TestState.make())]

        let answer = await siri(link).ask(botID: "ghost", question: "Hi")

        XCTAssertEqual(answer.spoken, "That bot isn't on your computer right now.")
        XCTAssertTrue(link.sent.isEmpty)
    }

    func testAskWithNothingToAsk() async {
        let link = FakeLink()

        let answer = await siri(link).ask(botID: "chief", question: "   ")

        XCTAssertEqual(answer.spoken, "Nothing was sent.")
        XCTAssertEqual(link.fetchCount, 0)
    }

    // MARK: Start a task

    func testStartTaskGoesToChiefByDefault() async {
        let link = FakeLink()
        link.states = [.success(TestState.make())]

        let answer = await siri(link).startTask(botID: nil, job: "Make the shed model")

        XCTAssertEqual(answer.spoken, "Sent. Chief has the job.")
        XCTAssertEqual(link.sent.first?.type, "chat.send")
        XCTAssertEqual(link.sent.first.flatMap { field($0, "chatId") }, .string("chief"))
        XCTAssertEqual(link.sent.first.flatMap { field($0, "text") }, .string("Make the shed model"))
        guard case let .sent(bot, text) = answer.snippet else {
            return XCTFail("Expected a sent card")
        }
        XCTAssertEqual(bot.name, "Chief")
        XCTAssertEqual(text, "Make the shed model")
    }

    func testStartTaskForAnotherBotWhileThePausedTeamWaits() async {
        let link = FakeLink()
        link.states = [.success(TestState.make(paused: true))]

        let answer = await siri(link).startTask(botID: "builder", job: "Fix the tests")

        XCTAssertEqual(answer.spoken, "Sent. Builder has the job. Your team is paused, so it starts once you resume it.")
        XCTAssertEqual(link.sent.first.flatMap { field($0, "chatId") }, .string("builder"))
    }

    func testStartTaskWhenTheComputerIsAway() async {
        let link = FakeLink()
        link.states = [.failure(PairingError.cantReach)]

        let answer = await siri(link).startTask(botID: nil, job: "Anything")

        XCTAssertEqual(answer.spoken, "No job was sent. \(PairingError.cantReach.message)")
        XCTAssertTrue(link.sent.isEmpty)
    }

    // MARK: Team status and what needs me

    func testTeamStatusReadsTheLiveTeam() async {
        let link = FakeLink()
        link.states = [.success(TestState.make(chiefStatus: "working", chiefTask: "Splitting up the work", builderStatus: "working"))]

        let answer = await siri(link).teamStatus()

        XCTAssertEqual(answer.spoken, "Chief is working on Splitting up the work. Builder is working. Nothing needs you.")
        guard case let .team(bots, paused, needsYou, savedAt) = answer.snippet else {
            return XCTFail("Expected a team card")
        }
        XCTAssertEqual(bots.map(\.id), ["chief", "builder"])
        XCTAssertFalse(paused)
        XCTAssertEqual(needsYou, 0)
        XCTAssertNil(savedAt)
    }

    func testTeamStatusUsesTheSavedCopyWhenTheComputerIsAway() async {
        let link = FakeLink()
        link.states = [.failure(PairingError.cantReach)]
        let savedAt = Date().addingTimeInterval(-600)
        link.saved = (TestState.make(), savedAt)

        let answer = await siri(link).teamStatus()

        XCTAssertTrue(answer.spoken.hasPrefix("Test-PC isn't answering. As of "), answer.spoken)
        XCTAssertTrue(answer.spoken.hasSuffix("Chief is idle. Your 1 teammate isn't working. Nothing needs you."), answer.spoken)
        guard case let .team(_, _, _, cardSavedAt) = answer.snippet else {
            return XCTFail("Expected a team card")
        }
        XCTAssertEqual(cardSavedAt, savedAt)
    }

    func testTeamStatusWithNothingSaved() async {
        let link = FakeLink()
        link.states = [.failure(PairingError.cantReach)]

        let answer = await siri(link).teamStatus()

        XCTAssertEqual(answer.spoken, PairingError.cantReach.message)
    }

    func testWhatNeedsMeListsThreeAndCountsTheRest() async {
        let link = FakeLink()
        let inbox = (1...4).map { TestState.ask("i\($0)", bot: "builder", title: "Builder wants to run a command") }
        link.states = [.success(TestState.make(inbox: inbox))]

        let answer = await siri(link).whatNeedsMe()

        XCTAssertTrue(answer.spoken.hasPrefix("4 things need you."), answer.spoken)
        XCTAssertTrue(answer.spoken.hasSuffix("Open Squall for the rest."), answer.spoken)
        guard case let .waiting(rows, more) = answer.snippet else {
            return XCTFail("Expected a waiting card")
        }
        XCTAssertEqual(rows.map(\.id), ["i1", "i2", "i3"])
        XCTAssertEqual(more, 1)
    }

    func testWhatNeedsMeWhenNothingDoes() async {
        let link = FakeLink()
        link.states = [.success(TestState.make())]

        let answer = await siri(link).whatNeedsMe()

        XCTAssertEqual(answer.spoken, "Nothing needs you right now.")
    }

    // MARK: Approve and decline

    func testApproveReadsTheRequestThenSendsAllow() async {
        let link = FakeLink()
        link.states = [.success(TestState.make(inbox: [TestState.ask("req-1", bot: "builder", title: "Builder wants to run a command", command: "npm test")]))]
        let brain = siri(link)

        let prep = await brain.prepareAnswer(botID: nil, allow: true)
        guard case let .ready(row, question) = prep else {
            return XCTFail("Expected a request to confirm, got \(prep)")
        }
        XCTAssertEqual(question, "Builder wants to run a command. The command is npm test. Allow it?")
        XCTAssertTrue(link.sent.isEmpty, "Nothing is sent before you say yes")

        let answer = await brain.answer(row, allow: true)

        XCTAssertEqual(answer.spoken, "Allowed. Builder can go ahead.")
        XCTAssertEqual(link.sent.first?.type, "inbox.answer")
        XCTAssertEqual(link.sent.first.flatMap { field($0, "itemId") }, .string("req-1"))
        XCTAssertEqual(link.sent.first.flatMap { field($0, "answer") }, .string("allow"))
    }

    func testDeclineSendsDeny() async {
        let link = FakeLink()
        link.states = [.success(TestState.make(inbox: [TestState.ask("req-2", bot: "chief", title: "Push the fix?")]))]
        let brain = siri(link)

        let prep = await brain.prepareAnswer(botID: "chief", allow: false)
        guard case let .ready(row, question) = prep else {
            return XCTFail("Expected a request to confirm")
        }
        XCTAssertEqual(question, "Chief asks: Push the fix. Deny it?")

        let answer = await brain.answer(row, allow: false)

        XCTAssertEqual(answer.spoken, "Denied. Chief won't do it.")
        XCTAssertEqual(link.sent.first.flatMap { field($0, "answer") }, .string("deny"))
    }

    func testApproveForABotThatIsNotWaiting() async {
        let link = FakeLink()
        link.states = [.success(TestState.make(inbox: [TestState.ask("req-1", bot: "builder", title: "Builder wants to change a file")]))]

        let prep = await siri(link).prepareAnswer(botID: "chief", allow: true)

        guard case let .nothing(answer) = prep else {
            return XCTFail("Expected nothing to confirm")
        }
        XCTAssertEqual(answer.spoken, "Chief isn't waiting on an OK. Builder is: Builder wants to change a file. Ask me to approve Builder's request to answer it.")
        XCTAssertTrue(link.sent.isEmpty)
    }

    func testApproveWhenNothingIsWaiting() async {
        let link = FakeLink()
        link.states = [.success(TestState.make())]

        let prep = await siri(link).prepareAnswer(botID: nil, allow: true)

        guard case let .nothing(answer) = prep else {
            return XCTFail("Expected nothing to confirm")
        }
        XCTAssertEqual(answer.spoken, "No bot is waiting on an OK right now.")
    }

    func testApproveLeavesQuestionsWithChoicesToTheApp() async {
        let link = FakeLink()
        let choice: [String: Any] = ["id": "c1", "kind": "choice", "botId": "chief", "title": "Which branch?", "options": ["main", "dev"]]
        link.states = [.success(TestState.make(inbox: [choice]))]

        let prep = await siri(link).prepareAnswer(botID: nil, allow: true)

        guard case let .nothing(answer) = prep else {
            return XCTFail("Expected nothing to confirm")
        }
        XCTAssertEqual(answer.spoken, "Chief asked a question with choices: Which branch? Open Squall to pick an answer.")
    }

    func testApproveWhenTheComputerIsAway() async {
        let link = FakeLink()
        link.states = [.failure(PairingError.cantReach)]

        let prep = await siri(link).prepareAnswer(botID: nil, allow: true)

        guard case let .nothing(answer) = prep else {
            return XCTFail("Expected nothing to confirm")
        }
        XCTAssertEqual(answer.spoken, "Nothing was allowed. \(PairingError.cantReach.message)")
    }

    func testAnswerThatFailsToSend() async {
        let link = FakeLink()
        link.sendError = SyncActionError(message: "That question had already gone on the computer.")
        let row = SiriRequestRow(id: "x", bot: nil, botName: "Chief", title: "Push?", command: nil, isChoice: false)

        let answer = await siri(link).answer(row, allow: true)

        XCTAssertEqual(answer.spoken, "It wasn't sent. That question had already gone on the computer.")
    }

    // MARK: Words and names

    func testSpeakableDropsCodeLinksAndMarkdown() {
        let text = "## Done\n- Fixed **two** bugs\n- See [the PR](https://github.com/x/y/pull/1)\n```swift\nlet a = 1\n```\nMore at https://example.com now"
        let spoken = SiriSpeech.speakable(text)
        XCTAssertFalse(spoken.contains("```"))
        XCTAssertFalse(spoken.contains("**"))
        XCTAssertFalse(spoken.contains("https://"))
        XCTAssertTrue(spoken.contains("Fixed two bugs"), spoken)
        XCTAssertTrue(spoken.contains("See the PR"), spoken)
        XCTAssertTrue(spoken.contains("(I put the code in the chat.)"), spoken)
        XCTAssertTrue(spoken.contains("More at a link now"), spoken)
    }

    func testSpeakableKeepsLongAnswersShort() {
        let sentence = "This is one sentence about the build. "
        let long = String(repeating: sentence, count: 40)
        let spoken = SiriSpeech.speakable(long)
        XCTAssertLessThanOrEqual(spoken.count, 650)
        XCTAssertTrue(spoken.hasSuffix("The rest is in the chat."), spoken)
    }

    func testBotMatcherFindsBotsBySpokenName() {
        let bots = TestState.make().bots.map(\.model)
        XCTAssertEqual(BotMatcher.matches("builder", in: bots).first?.id, "builder")
        XCTAssertEqual(BotMatcher.matches("BÜILDER", in: bots).first?.id, "builder")
        XCTAssertEqual(BotMatcher.matches("Build", in: bots).first?.id, "builder")
        XCTAssertEqual(BotMatcher.matches("the chief", in: bots).first?.id, "chief")
        XCTAssertTrue(BotMatcher.matches("Zed", in: bots).isEmpty)
        XCTAssertTrue(BotMatcher.matches("  ", in: bots).isEmpty)
    }

    func testSpotlightIdsRoundTrip() {
        XCTAssertEqual(SiriSync.botID(fromSpotlightID: "bot:builder"), "builder")
        XCTAssertNil(SiriSync.botID(fromSpotlightID: "bot:"))
        XCTAssertNil(SiriSync.botID(fromSpotlightID: "builder"))
    }

    func testSpotlightSignatureIgnoresOrder() {
        let bots = TestState.make().bots.map(\.model)
        XCTAssertEqual(SiriSync.signature(for: bots), SiriSync.signature(for: Array(bots.reversed())))
        var renamed = bots
        renamed[0].name = "Builder 2"
        XCTAssertNotEqual(SiriSync.signature(for: bots), SiriSync.signature(for: renamed))
    }

    func testSiriPhrasesStayWithinApplesLimit() {
        XCTAssertLessThanOrEqual(SquallShortcuts.appShortcuts.count, 10)
        XCTAssertEqual(SquallShortcuts.appShortcuts.count, 10)
    }
}
