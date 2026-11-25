import XCTest
@testable import Squall

final class ChatWallpapersTests: XCTestCase {
    private func freshDefaults() -> UserDefaults {
        UserDefaults(suiteName: "ChatWallpapersTests-\(UUID().uuidString)")!
    }

    func testStartsWithNone() {
        let wallpapers = ChatWallpapers(defaults: freshDefaults())
        XCTAssertEqual(wallpapers.style(for: "rex"), ChatWallpapers.Style.none)
        XCTAssertFalse(wallpapers.hasOwn("rex"))
    }

    func testOwnPickAndEveryChat() {
        let defaults = freshDefaults()
        let wallpapers = ChatWallpapers(defaults: defaults)
        wallpapers.set(.stars, for: "rex")
        XCTAssertEqual(wallpapers.style(for: "rex"), .stars)
        XCTAssertEqual(wallpapers.style(for: "chief"), ChatWallpapers.Style.none)
        XCTAssertTrue(wallpapers.hasOwn("rex"))

        // Saved between launches.
        let again = ChatWallpapers(defaults: defaults)
        XCTAssertEqual(again.style(for: "rex"), .stars)

        // Every chat takes off each chat's own pick.
        wallpapers.setEveryChat(.waves)
        XCTAssertEqual(wallpapers.style(for: "rex"), .waves)
        XCTAssertEqual(wallpapers.style(for: "chief"), .waves)
        XCTAssertFalse(wallpapers.hasOwn("rex"))
        XCTAssertEqual(ChatWallpapers(defaults: defaults).style(for: "anyone"), .waves)

        // Picking the every-chat one for a chat doesn't make it its own.
        wallpapers.set(.waves, for: "rex")
        XCTAssertFalse(wallpapers.hasOwn("rex"))
        wallpapers.set(ChatWallpapers.Style.none, for: "rex")
        XCTAssertTrue(wallpapers.hasOwn("rex"))
        XCTAssertEqual(wallpapers.style(for: "rex"), ChatWallpapers.Style.none)
    }

    func testKeepOnlyAndClear() {
        let wallpapers = ChatWallpapers(defaults: freshDefaults())
        wallpapers.set(.dots, for: "rex")
        wallpapers.set(.grid, for: "gone")
        wallpapers.keepOnly(chats: ["rex"])
        XCTAssertEqual(Set(wallpapers.styles.keys), ["rex"])
        wallpapers.setEveryChat(.stripes)
        wallpapers.clear()
        XCTAssertEqual(wallpapers.style(for: "rex"), ChatWallpapers.Style.none)
        XCTAssertEqual(wallpapers.everyChat, ChatWallpapers.Style.none)
    }

    func testUnknownSavedStylesAreSkipped() {
        let defaults = freshDefaults()
        defaults.set(["rex": "lava", "chief": "dots"], forKey: ChatWallpapers.key)
        let wallpapers = ChatWallpapers(defaults: defaults)
        XCTAssertEqual(wallpapers.styles, ["chief": .dots])
    }

    func testStarsAreTheSameEveryTimeAndInside() {
        let size = CGSize(width: 390, height: 844)
        let first = ChatWallpapers.stars(in: size)
        XCTAssertEqual(first, ChatWallpapers.stars(in: size))
        XCTAssertFalse(first.isEmpty)
        XCTAssertTrue(first.allSatisfy { $0.point.x >= 0 && $0.point.x <= size.width && $0.point.y >= 0 && $0.point.y <= size.height })
        XCTAssertTrue(first.contains { $0.sparkle })
        XCTAssertEqual(ChatWallpapers.stars(in: .zero), [])
    }

    func testWaveCoversTheWidth() {
        let points = ChatWallpapers.wave(y: 50, width: 100)
        XCTAssertEqual(points.first?.x, 0)
        XCTAssertGreaterThanOrEqual(points.last?.x ?? 0, 100)
        XCTAssertTrue(points.allSatisfy { abs($0.y - 50) <= 6.0001 })
    }
}
