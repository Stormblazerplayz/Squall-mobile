import XCTest
@testable import Squall

final class ConfettiTests: XCTestCase {
    func testSameSeedSameBurst() {
        XCTAssertEqual(Confetti.pieces(seed: 3), Confetti.pieces(seed: 3))
        XCTAssertNotEqual(Confetti.pieces(seed: 3), Confetti.pieces(seed: 4))
        XCTAssertEqual(Confetti.pieces(count: 10, seed: 1).count, 10)
        XCTAssertEqual(Confetti.pieces(count: -2, seed: 1).count, 0)
    }

    func testPiecesStartGoingUp() {
        for piece in Confetti.pieces(seed: 9) {
            XCTAssertLessThan(piece.dy, 0)
        }
    }

    func testMotion() {
        let piece = Confetti.Piece(dx: 100, dy: -200, spin: 2, size: CGSize(width: 4, height: 3), hex: 0xF5C84B)
        let origin = CGPoint(x: 50, y: 50)
        let start = Confetti.spot(piece, at: 0, from: origin)
        XCTAssertEqual(start.point, origin)
        XCTAssertEqual(start.opacity, 1)
        let half = Confetti.spot(piece, at: 0.5, from: origin)
        XCTAssertEqual(half.point.x, 100, accuracy: 0.001)
        XCTAssertEqual(half.point.y, 50 - 100 + 0.5 * Confetti.gravity * 0.25, accuracy: 0.001)
        XCTAssertEqual(half.angle, 1, accuracy: 0.001)
        XCTAssertEqual(Confetti.spot(piece, at: Confetti.duration, from: origin).opacity, 0, accuracy: 0.001)
        // Past the end it stays where it finished.
        XCTAssertEqual(Confetti.spot(piece, at: 99, from: origin), Confetti.spot(piece, at: Confetti.duration, from: origin))
    }
}
