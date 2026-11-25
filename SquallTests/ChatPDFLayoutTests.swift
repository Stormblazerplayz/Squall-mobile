import XCTest
@testable import Squall

final class ChatPDFLayoutTests: XCTestCase {
    func testBlocksStackWithGaps() {
        let out = ChatPDFLayout.place([100, 50, 30], pageHeight: 400, gap: 10)
        XCTAssertEqual(out, [
            .init(index: 0, page: 0, top: 0),
            .init(index: 1, page: 0, top: 110),
            .init(index: 2, page: 0, top: 170),
        ])
        XCTAssertEqual(ChatPDFLayout.pageCount(out), 1)
    }

    func testABlockThatDoesNotFitStartsANewPage() {
        let out = ChatPDFLayout.place([300, 150, 20], pageHeight: 400, gap: 10)
        XCTAssertEqual(out.map(\.page), [0, 1, 1])
        XCTAssertEqual(out[1].top, 0)
        XCTAssertEqual(out[2].top, 160)
        XCTAssertEqual(ChatPDFLayout.pageCount(out), 2)
    }

    func testATallBlockGetsItsOwnPage() {
        let out = ChatPDFLayout.place([50, 900, 50], pageHeight: 400, gap: 10)
        XCTAssertEqual(out.map(\.page), [0, 1, 2])
        XCTAssertEqual(out.map(\.top), [0, 0, 0])
    }

    func testEmptyAndSizes() {
        XCTAssertEqual(ChatPDFLayout.place([]), [])
        XCTAssertEqual(ChatPDFLayout.pageCount([]), 0)
        XCTAssertEqual(ChatPDFLayout.contentWidth, 540)
        XCTAssertEqual(ChatPDFLayout.contentHeight, 720)
    }

    func testFileName() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = ISO8601DateFormatter().date(from: "2026-11-25T12:00:00Z")!
        XCTAssertEqual(ChatPDFLayout.fileName(title: "Chat with Rex", now: now, calendar: calendar), "Chat with Rex 2026-11-25.pdf")
    }
}
