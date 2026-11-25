import CoreGraphics
import XCTest
@testable import Squall

// Tests for the big screen's zoom and pan math (Squall/Uno/UnoZoom.swift): zoom stays between 1x and 4x,
// the picture can't be moved off the view, and a double tap zooms around the tapped spot.

final class UnoZoomTests: XCTestCase {
    // A 1280×800 screen fitted into a 400-wide phone view: 400×250.
    private let box = CGSize(width: 400, height: 600)
    private let content = CGSize(width: 400, height: 250)

    private func assertClose(_ a: CGFloat, _ b: CGFloat, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a, b, accuracy: 0.0001, file: file, line: line)
    }

    // MARK: Zoom

    func testScaleStaysBetweenOneAndFour() {
        XCTAssertEqual(UnoZoomMath.clampScale(0.3), 1)
        XCTAssertEqual(UnoZoomMath.clampScale(1), 1)
        XCTAssertEqual(UnoZoomMath.clampScale(2.2), 2.2)
        XCTAssertEqual(UnoZoomMath.clampScale(4), 4)
        XCTAssertEqual(UnoZoomMath.clampScale(9), 4)
        XCTAssertEqual(UnoZoomMath.clampScale(-2), 1)
        XCTAssertEqual(UnoZoomMath.clampScale(.nan), 1)
        XCTAssertEqual(UnoZoomMath.clampScale(.infinity), 1)
    }

    func testZoomingAroundTheMiddleDoesNotMove() {
        let state = UnoZoomMath.zoom(.identity, to: 3, around: CGPoint(x: 200, y: 300), content: content, box: box)
        XCTAssertEqual(state.scale, 3)
        assertClose(state.offset.width, 0)
        assertClose(state.offset.height, 0)
    }

    func testZoomKeepsTheSpotUnderTheFinger() {
        let point = CGPoint(x: 300, y: 340)
        let state = UnoZoomMath.zoom(.identity, to: 2, around: point, content: content, box: box)
        XCTAssertEqual(state.scale, 2)
        // Picture at 2x is 800×500: it can move 200 left/right and none up/down (500 < 600).
        assertClose(state.offset.width, -100)
        assertClose(state.offset.height, 0)
        // The spot 100 right of the middle stays under the finger.
        assertClose(200 + state.offset.width + 100 * state.scale, point.x)
    }

    func testZoomPastFourStopsAtFour() {
        let state = UnoZoomMath.zoom(.identity, to: 12, around: CGPoint(x: 200, y: 300), content: content, box: box)
        XCTAssertEqual(state.scale, 4)
    }

    // MARK: Pan

    func testAtOneTimesThePictureStaysCentered() {
        let offset = UnoZoomMath.clampOffset(CGSize(width: 80, height: -40), scale: 1, content: content, box: box)
        XCTAssertEqual(offset, .zero)
        let panned = UnoZoomMath.pan(.identity, by: CGSize(width: 50, height: 50), content: content, box: box)
        XCTAssertEqual(panned, .identity)
    }

    func testPanCantPullAnEdgeIntoTheView() {
        // At 4x the picture is 1600×1000 in a 400×600 view: 600 each way sideways, 200 up and down.
        let limit = UnoZoomMath.maxOffset(scale: 4, content: content, box: box)
        assertClose(limit.width, 600)
        assertClose(limit.height, 200)
        let start = UnoZoomState(scale: 4, offset: .zero)
        let far = UnoZoomMath.pan(start, by: CGSize(width: 5000, height: -5000), content: content, box: box)
        assertClose(far.offset.width, 600)
        assertClose(far.offset.height, -200)
        let near = UnoZoomMath.pan(start, by: CGSize(width: -120, height: 30), content: content, box: box)
        assertClose(near.offset.width, -120)
        assertClose(near.offset.height, 30)
    }

    func testPanStartsFromWhereTheDragBegan() {
        let start = UnoZoomState(scale: 2, offset: CGSize(width: 50, height: 0))
        let moved = UnoZoomMath.pan(start, by: CGSize(width: 30, height: 0), content: content, box: box)
        assertClose(moved.offset.width, 80)
    }

    func testZoomingOutPullsThePictureBackIn() {
        let state = UnoZoomState(scale: 4, offset: CGSize(width: 600, height: 200))
        let out = UnoZoomMath.zoom(state, to: 1, around: CGPoint(x: 10, y: 10), content: content, box: box)
        XCTAssertEqual(out.scale, 1)
        XCTAssertEqual(out.offset, .zero)
    }

    func testTurningTheViewReclampsTheMove() {
        // A turn to landscape makes the view wider; a move that fit before is pulled back in.
        let state = UnoZoomState(scale: 2, offset: CGSize(width: 200, height: 0))
        let wide = CGSize(width: 844, height: 390)
        let fitted = CGSize(width: 624, height: 390)
        let clamped = UnoZoomMath.clamp(state, content: fitted, box: wide)
        // 1248 wide in 844: 202 each way, so 200 still fits; 780 tall in 390: 195 each way.
        assertClose(clamped.offset.width, 200)
        let small = UnoZoomMath.clamp(UnoZoomState(scale: 1.2, offset: CGSize(width: 200, height: 90)), content: fitted, box: wide)
        assertClose(small.offset.width, 0)
        assertClose(small.offset.height, 39)
    }

    func testBadNumbersDontMoveThePicture() {
        let offset = UnoZoomMath.clampOffset(CGSize(width: CGFloat.nan, height: .infinity), scale: 2, content: content, box: box)
        XCTAssertEqual(offset, .zero)
    }

    // MARK: Double tap

    func testDoubleTapZoomsToTwoAndAHalfAroundTheTap() {
        let point = CGPoint(x: 300, y: 300)
        let state = UnoZoomMath.doubleTap(.identity, at: point, content: content, box: box)
        XCTAssertEqual(state.scale, 2.5)
        assertClose(state.offset.width, -150)
        assertClose(state.offset.height, 0)
        assertClose(200 + state.offset.width + 100 * state.scale, point.x)
    }

    func testDoubleTapNearAnEdgeStaysInBounds() {
        let state = UnoZoomMath.doubleTap(.identity, at: CGPoint(x: 0, y: 300), content: content, box: box)
        // 1000 wide in 400: at most 300 each way.
        assertClose(state.offset.width, 300)
    }

    func testDoubleTapWhenZoomedGoesBackToOne() {
        let zoomed = UnoZoomState(scale: 3.2, offset: CGSize(width: 40, height: 10))
        XCTAssertTrue(zoomed.isZoomed)
        let state = UnoZoomMath.doubleTap(zoomed, at: CGPoint(x: 100, y: 100), content: content, box: box)
        XCTAssertEqual(state, .identity)
        XCTAssertFalse(state.isZoomed)
    }
}
