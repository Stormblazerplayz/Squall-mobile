import SwiftUI
import XCTest
@testable import Squall

final class BubbleStyleTests: XCTestCase {
    private func corners(_ r: RectangleCornerRadii) -> [CGFloat] {
        [r.topLeading, r.bottomLeading, r.bottomTrailing, r.topTrailing]
    }

    func testRoundKeepsTheOldLook() {
        XCTAssertEqual(corners(BubbleStyle.rounded.radii(mine: true)), [18, 18, 18, 18])
        XCTAssertEqual(corners(BubbleStyle.rounded.radii(mine: false)), [16, 16, 16, 16])
    }

    func testTailsPointAtWhoWroteIt() {
        XCTAssertEqual(corners(BubbleStyle.tails.radii(mine: true)), [18, 18, 5, 18])
        XCTAssertEqual(corners(BubbleStyle.tails.radii(mine: false)), [5, 16, 16, 16])
        XCTAssertEqual(corners(BubbleStyle.tails.radii(mine: false, continued: true)), [16, 16, 16, 16])
    }

    func testSquare() {
        XCTAssertEqual(corners(BubbleStyle.square.radii(mine: true)), [6, 6, 6, 6])
        XCTAssertEqual(corners(BubbleStyle.square.radii(mine: false, continued: true)), [6, 6, 6, 6])
    }

    func testLabelsAndSavedValues() {
        XCTAssertEqual(BubbleStyle.allCases.map(\.label), ["Round", "Tails", "Square"])
        XCTAssertEqual(BubbleStyle(rawValue: "tails"), .tails)
        XCTAssertNil(BubbleStyle(rawValue: "blob"))
    }
}
