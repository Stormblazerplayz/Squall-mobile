import XCTest
@testable import Squall

final class SquallBackupTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "SquallBackupTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    private let now = ISO8601DateFormatter().date(from: "2026-11-25T12:00:00Z")!

    private func star(_ id: String, at seconds: TimeInterval) -> StarredMessages.Item {
        StarredMessages.Item(id: "rex/\(id)", chatID: "rex", messageID: id, author: "rex", authorName: "Rex",
                             text: "Message \(id)", time: "9:41 AM", savedAt: Date(timeIntervalSince1970: seconds))
    }

    private func prompt(_ id: String, _ text: String) -> SavedPrompts.Item {
        SavedPrompts.Item(id: id, title: "", text: text, uses: 2, lastUsed: nil, created: now)
    }

    func testMakeKeepsOnlyKnownSettingsOfTheRightKind() {
        defaults.set(true, forKey: Prefs.haptics)
        defaults.set(40.0, forKey: Prefs.chatTextSize)
        defaults.set("  Storm  ", forKey: Prefs.teamName)
        defaults.set("nope", forKey: Prefs.openChat)
        defaults.set(true, forKey: Prefs.appLock)
        defaults.set("x", forKey: "squall.somethingElse")
        var settings = AppSettings()
        settings.quietHours = true
        settings.mutedBots = ["rex", "nova"]
        let backup = SquallBackup.make(defaults: defaults, accentHex: 0x2F6FD0, settings: settings,
                                       starred: [star("1", at: 10)], prompts: [prompt("p", "Run the tests")], now: now)
        XCTAssertEqual(backup.settings, [
            Prefs.haptics: .bool(true),
            Prefs.chatTextSize: .number(22),
            Prefs.teamName: .text("Storm"),
        ])
        XCTAssertEqual(backup.accentHex, 0x2F6FD0)
        XCTAssertEqual(backup.notifications?.quietHours, true)
        XCTAssertEqual(backup.notifications?.mutedBots, ["nova", "rex"])
        XCTAssertEqual(backup.summary.text, "1 starred message, 1 saved prompt and your settings")
    }

    func testFileRoundTrip() throws {
        let backup = SquallBackup.make(defaults: defaults, accentHex: nil, settings: nil,
                                       starred: [star("1", at: 10)], prompts: [prompt("p", "Hi {name}")], now: now)
        let data = try SquallBackup.encode(backup)
        XCTAssertEqual(try SquallBackup.decode(data), backup)
    }

    func testBadFiles() {
        XCTAssertThrowsError(try SquallBackup.decode(Data("nope".utf8))) { error in
            XCTAssertEqual(error as? SquallBackup.Problem, SquallBackup.Problem(message: "That file isn't a Squall backup."))
        }
        let other = #"{"app":"Other","version":1,"made":"2026-11-25T12:00:00Z","settings":{},"starred":[],"prompts":[]}"#
        XCTAssertThrowsError(try SquallBackup.decode(Data(other.utf8)))
        let newer = #"{"app":"Squall","version":9,"made":"2026-11-25T12:00:00Z","settings":{},"starred":[],"prompts":[]}"#
        XCTAssertThrowsError(try SquallBackup.decode(Data(newer.utf8))) { error in
            XCTAssertEqual((error as? SquallBackup.Problem)?.message,
                           "That backup is from a newer Squall. Update the app, then try again.")
        }
    }

    func testCheckedAndWriteSettings() {
        XCTAssertEqual(SquallBackup.checked(.number(5), for: Prefs.chatTextSize), .number(12))
        XCTAssertNil(SquallBackup.checked(.number(.nan), for: Prefs.chatTextSize))
        XCTAssertNil(SquallBackup.checked(.text("yes"), for: Prefs.haptics))
        XCTAssertNil(SquallBackup.checked(.bool(true), for: Prefs.appLock))
        XCTAssertEqual(SquallBackup.checked(.text("last"), for: Prefs.openChat), .text("last"))
        SquallBackup.writeSettings([Prefs.haptics: .bool(false), Prefs.appLock: .bool(true), Prefs.teamName: .text("Ace")],
                                   to: defaults)
        XCTAssertEqual(defaults.object(forKey: Prefs.haptics) as? Bool, false)
        XCTAssertNil(defaults.object(forKey: Prefs.appLock))
        XCTAssertEqual(defaults.string(forKey: Prefs.teamName), "Ace")
    }

    func testNotificationsOnlyChangeNotificationChoices() {
        var phone = AppSettings()
        phone.askBeforePush = false
        let saved = SquallBackup.Notifications(needsMe: false, errors: true, done: true, sound: false, quietHours: true,
                                               quietStart: 99_999, quietEnd: -5, mutedBots: ["rex"])
        let out = SquallBackup.applying(saved, to: phone)
        XCTAssertFalse(out.notifyNeedsMe)
        XCTAssertTrue(out.notifyDone)
        XCTAssertEqual(out.quietStart, 24 * 60 - 1)
        XCTAssertEqual(out.quietEnd, 0)
        XCTAssertEqual(out.mutedBots, ["rex"])
        XCTAssertFalse(out.askBeforePush)
        XCTAssertNil(SquallBackup.accent(0))
        XCTAssertNil(SquallBackup.accent(0x1000000))
        XCTAssertEqual(SquallBackup.accent(0x2F6FD0), 0x2F6FD0)
    }

    func testMergesSkipWhatsAlreadyHere() {
        let stars = StarredMessages(defaults: defaults, key: "stars")
        XCTAssertEqual(stars.merge([star("1", at: 10), star("2", at: 30)]), 2)
        XCTAssertEqual(stars.merge([star("2", at: 30), star("3", at: 20)]), 1)
        XCTAssertEqual(stars.items.map(\.messageID), ["2", "3", "1"])

        let prompts = SavedPrompts(defaults: defaults, key: "prompts")
        prompts.add(title: "", text: "Run the tests")
        XCTAssertEqual(prompts.merge([prompt("a", " Run the tests "), prompt("b", "Deploy it"), prompt("c", "")]), 1)
        XCTAssertEqual(prompts.items.map(\.text), ["Run the tests", "Deploy it"])
        XCTAssertEqual(prompts.items.last?.uses, 2)
    }

    func testFileName() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(SquallBackup.fileName(now, calendar: utc), "Squall backup Nov 25 2026")
    }
}
