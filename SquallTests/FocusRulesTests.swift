import XCTest
@testable import Squall

final class FocusRulesTests: XCTestCase {
    func testEverythingLetsAllThrough() {
        let rules = FocusRules()
        XCTAssertFalse(rules.isActive)
        XCTAssertTrue(rules.allows(.done, from: "rex"))
        XCTAssertTrue(rules.allows(.reply, from: "rex"))
    }

    func testNeedsYouOnly() {
        let rules = FocusRules(pings: .needsYou)
        XCTAssertTrue(rules.isActive)
        XCTAssertTrue(rules.allows(.needsYou, from: "rex"))
        XCTAssertFalse(rules.allows(.problem, from: Bot.chiefID))
        XCTAssertFalse(rules.allows(.done, from: "rex"))
        XCTAssertFalse(rules.allows(.reply, from: "rex"))
    }

    func testChiefOnlyAndNothing() {
        let chief = FocusRules(pings: .chief)
        XCTAssertTrue(chief.allows(.reply, from: Bot.chiefID))
        XCTAssertFalse(chief.allows(.needsYou, from: "rex"))
        XCTAssertFalse(FocusRules(pings: .nothing).allows(.needsYou, from: Bot.chiefID))
    }

    func testKinds() {
        XCTAssertEqual(FocusRules.ping(for: .ask), .needsYou)
        XCTAssertEqual(FocusRules.ping(for: .choice(["A"])), .needsYou)
        XCTAssertEqual(FocusRules.ping(for: .error), .problem)
        XCTAssertEqual(FocusRules.ping(for: .done(openLabel: "Open")), .done)
    }

    func testSummaries() {
        XCTAssertEqual(FocusRules().summary, "All Squall pings")
        XCTAssertEqual(FocusRules(silent: true).summary, "All Squall pings, without sound")
        XCTAssertEqual(FocusRules(pings: .nothing, silent: true).summary, "No Squall pings")
        XCTAssertEqual(FocusRules(pings: .chief, silent: true).summary, "Only Chief, without sound")
        XCTAssertEqual(FocusRules(pings: .needsYou).summary, "Only when a teammate needs me")
    }

    func testSavingAndEndingAFocus() {
        let defaults = UserDefaults(suiteName: "FocusRulesTests")!
        defaults.removePersistentDomain(forName: "FocusRulesTests")
        let rules = FocusRules(pings: .chief, silent: true, since: Date(timeIntervalSince1970: 1_000))
        FocusRules.save(rules, defaults: defaults)
        XCTAssertEqual(FocusRules.decode(defaults.data(forKey: FocusRules.key)), rules)
        // The Focus ending runs the filter again with the defaults, which clears it.
        FocusRules.save(FocusRules(), defaults: defaults)
        XCTAssertNil(defaults.data(forKey: FocusRules.key))
        XCTAssertEqual(FocusRules.decode(nil), FocusRules())
        XCTAssertEqual(FocusRules.decode(Data("nope".utf8)), FocusRules())
    }
}
