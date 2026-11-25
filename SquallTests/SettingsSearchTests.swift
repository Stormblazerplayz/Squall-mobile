import XCTest
@testable import Squall

// Tests for search in Settings.

final class SettingsSearchTests: XCTestCase {
    func testNothingTypedShowsEverySection() {
        XCTAssertFalse(SettingsSearch.isSearching("   "))
        XCTAssertTrue(SettingsSearch.isSearching(" glow "))
        XCTAssertEqual(SettingsSearch.matches(""), SettingsSearch.sections.map(\.name))
    }

    func testFindsSectionsByTheirRows() {
        XCTAssertEqual(SettingsSearch.matches("glow"), ["Look"])
        XCTAssertEqual(SettingsSearch.matches("QUIET"), ["Notifications"])
        XCTAssertEqual(SettingsSearch.matches("face id"), ["Privacy"])
        XCTAssertEqual(SettingsSearch.matches("text size"), ["Chat"])
        XCTAssertEqual(SettingsSearch.matches("safety"), ["Safety"])
    }

    func testEveryWordHasToMatchAndOrderFollowsThePage() {
        XCTAssertEqual(SettingsSearch.matches("github"), ["Safety", "About"])
        XCTAssertEqual(SettingsSearch.matches("github push"), ["Safety"])
        XCTAssertEqual(SettingsSearch.matches("zebra"), [])
    }

    func testNamesAreUnique() {
        let names = SettingsSearch.sections.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
    }
}
