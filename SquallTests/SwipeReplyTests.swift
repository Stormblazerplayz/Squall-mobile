import XCTest
@testable import Squall

// Tests for swipe right to reply.

final class SwipeReplyTests: XCTestCase {
    func testUpAndDownIsScrollingNotASwipe() {
        XCTAssertFalse(SwipeReply.isSwipe(CGSize(width: 40, height: 60)))
        XCTAssertFalse(SwipeReply.isSwipe(CGSize(width: -80, height: 0)))
        XCTAssertTrue(SwipeReply.isSwipe(CGSize(width: 40, height: 10)))
        XCTAssertEqual(SwipeReply.offset(for: CGSize(width: 40, height: 60)), 0)
        XCTAssertEqual(SwipeReply.offset(for: CGSize(width: -40, height: 0)), 0)
    }

    func testBubbleFollowsThenSlowsDown() {
        XCTAssertEqual(SwipeReply.offset(for: CGSize(width: 30, height: 0)), 30)
        XCTAssertEqual(SwipeReply.offset(for: CGSize(width: 60, height: 0)), 60)
        XCTAssertEqual(SwipeReply.offset(for: CGSize(width: 90, height: 0)), 70)
        XCTAssertEqual(SwipeReply.offset(for: CGSize(width: 400, height: 0)), SwipeReply.maxOffset)
    }

    func testOnlyAFarEnoughSwipeReplies() {
        XCTAssertFalse(SwipeReply.replies(CGSize(width: 59, height: 0)))
        XCTAssertTrue(SwipeReply.replies(CGSize(width: 60, height: 5)))
        XCTAssertFalse(SwipeReply.replies(CGSize(width: 80, height: 70)))
    }

    func testProgress() {
        XCTAssertEqual(SwipeReply.progress(0), 0)
        XCTAssertEqual(SwipeReply.progress(30), 0.5)
        XCTAssertEqual(SwipeReply.progress(84), 1)
        XCTAssertEqual(SwipeReply.progress(-5), 0)
    }
}
