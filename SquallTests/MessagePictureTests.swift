import XCTest
@testable import Squall

final class MessagePictureTests: XCTestCase {
    func testShortTextStaysWhole() {
        XCTAssertEqual(MessagePicture.clip("  Done! Tests pass.  "), "Done! Tests pass.")
    }

    func testLongTextIsCutAtAWord() {
        let long = String(repeating: "word ", count: 400)
        let clipped = MessagePicture.clip(long)
        XCTAssertTrue(clipped.hasSuffix("…"))
        XCTAssertLessThanOrEqual(clipped.count, MessagePicture.maxCharacters + 1)
        XCTAssertFalse(clipped.dropLast().hasSuffix(" "))
        XCTAssertTrue(clipped.dropLast().hasSuffix("word"))
    }

    func testLongTextWithNoSpacesIsCutAnyway() {
        let long = String(repeating: "x", count: 2000)
        let clipped = MessagePicture.clip(long)
        XCTAssertEqual(clipped.count, MessagePicture.maxCharacters + 1)
        XCTAssertTrue(clipped.hasSuffix("…"))
    }
}
