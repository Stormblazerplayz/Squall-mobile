import XCTest
@testable import Squall

final class ChatListOrderTests: XCTestCase {
    private let bots = [
        Bot(id: "chief", name: "Chief", hex: 0xD8B747, role: "Team lead", status: .idle, task: "Plan the week"),
        Bot(id: "rex", name: "Rex", hex: 0x3FD0B0, role: "Coder", status: .working, task: "Login page"),
        Bot(id: "ava", name: "Ava", hex: 0x7C5CF6, role: "Designer", status: .idle, task: ""),
        Bot(id: "bo", name: "Bo", hex: 0x20B296, role: "Tester", status: .idle, task: ""),
    ]

    private let dates: [String: Date] = [
        "rex": Date(timeIntervalSince1970: 300),
        "ava": Date(timeIntervalSince1970: 500),
    ]

    func testRecentPutsNewestFirstAndKeepsTheRestInTeamOrder() {
        let out = ChatListOrder.sorted(bots, by: .recent) { dates[$0] }
        XCTAssertEqual(out.map(\.id), ["ava", "rex", "chief", "bo"])
    }

    func testNameAndTeam() {
        XCTAssertEqual(ChatListOrder.sorted(bots, by: .name) { _ in nil }.map(\.id), ["ava", "bo", "chief", "rex"])
        XCTAssertEqual(ChatListOrder.sorted(bots, by: .team) { _ in nil }.map(\.id), ["chief", "rex", "ava", "bo"])
    }

    func testFavoritesComeFirstInTheOrderAdded() {
        let sections = ChatListOrder.sections(bots, favorites: ["bo", "chief", "gone"], sort: .recent) { dates[$0] }
        XCTAssertEqual(sections.map(\.title), ["Favorites", "Chats"])
        XCTAssertEqual(sections[0].bots.map(\.id), ["bo", "chief"])
        XCTAssertEqual(sections[1].bots.map(\.id), ["ava", "rex"])
    }

    func testNoFavoritesIsOneUntitledSection() {
        let sections = ChatListOrder.sections(bots, favorites: [], sort: .team) { _ in nil }
        XCTAssertEqual(sections.map(\.title), [""])
        XCTAssertEqual(sections[0].bots.count, 4)
    }

    func testSearchByNameRoleOrTask() {
        XCTAssertEqual(ChatListOrder.sections(bots, favorites: [], sort: .team, query: "login") { _ in nil }
            .flatMap(\.bots).map(\.id), ["rex"])
        XCTAssertEqual(ChatListOrder.sections(bots, favorites: ["ava"], sort: .team, query: "DESIGN") { _ in nil }
            .flatMap(\.bots).map(\.id), ["ava"])
        XCTAssertEqual(ChatListOrder.sections(bots, favorites: [], sort: .team, query: "zebra") { _ in nil }, [])
    }

    func testFavoritesFirstForTheStrip() {
        XCTAssertEqual(ChatListOrder.favoritesFirst(bots, favorites: ["ava"]).map(\.id), ["ava", "chief", "rex", "bo"])
    }

    func testFavoritesStore() {
        let defaults = UserDefaults(suiteName: "ChatFavoritesTests-\(UUID().uuidString)")!
        let favorites = ChatFavorites(defaults: defaults)
        XCTAssertTrue(favorites.toggle("rex"))
        XCTAssertTrue(favorites.toggle("ava"))
        XCTAssertEqual(ChatFavorites(defaults: defaults).ids, ["rex", "ava"])
        XCTAssertFalse(favorites.toggle("rex"))
        XCTAssertEqual(favorites.ids, ["ava"])
        favorites.keepOnly(["rex"])
        XCTAssertEqual(favorites.ids, [])
        favorites.toggle("bo")
        favorites.clear()
        XCTAssertEqual(ChatFavorites(defaults: defaults).ids, [])
    }
}
