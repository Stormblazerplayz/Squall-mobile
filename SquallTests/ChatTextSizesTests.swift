import XCTest
@testable import Squall

// Tests for pinching a chat to change the message text size.

final class ChatTextSizesTests: XCTestCase {
    func testNearestStep() {
        XCTAssertEqual(ChatTextSizes.nearest(15).label, "Normal")
        XCTAssertEqual(ChatTextSizes.nearest(12).label, "Small")
        XCTAssertEqual(ChatTextSizes.nearest(22).label, "Huge")
        XCTAssertEqual(ChatTextSizes.nearest(16.4).size, 17)
        XCTAssertEqual(ChatTextSizes.label(13.5), "Small")
    }

    func testPinching() {
        XCTAssertEqual(ChatTextSizes.size(start: 15, scale: 1), 15)
        XCTAssertEqual(ChatTextSizes.size(start: 15, scale: 1.05), 15, "A tiny pinch stays put")
        XCTAssertEqual(ChatTextSizes.size(start: 15, scale: 1.25), 17)
        XCTAssertEqual(ChatTextSizes.size(start: 15, scale: 2), 19)
        XCTAssertEqual(ChatTextSizes.size(start: 15, scale: 0.8), 13.5)
        XCTAssertEqual(ChatTextSizes.size(start: 15, scale: 0.1), 13.5)
        XCTAssertEqual(ChatTextSizes.size(start: 15, scale: 0), 15)
        XCTAssertEqual(ChatTextSizes.size(start: 15, scale: .nan), 15)
    }

    func testStepsMatchSettings() {
        XCTAssertEqual(ChatTextSizes.steps.map(\.label), ["Small", "Normal", "Big", "Huge"])
        XCTAssertTrue(ChatTextSizes.steps.allSatisfy { (12...22).contains($0.size) }, "Inside what a backup can restore")
    }
}
