import CoreGraphics
import Foundation

/// A small burst of confetti, for when a task list in a reply is all ticked. The pieces are worked out from a seed so the
/// same burst looks the same every time, and each piece's place at a moment is plain math (easy to test).
enum Confetti {
    static let duration: Double = 1.3
    static let gravity: Double = 520
    static let colors: [UInt32] = [0xF5C84B, 0x4ADE80, 0x60A5FA, 0xF472B6, 0xA78BFA, 0xFB923C]

    struct Piece: Equatable {
        /// Start speed, in points a second. Up is negative.
        let dx: Double
        let dy: Double
        let spin: Double
        let size: CGSize
        let hex: UInt32
    }

    struct Spot: Equatable {
        let point: CGPoint
        let angle: Double
        let opacity: Double
    }

    static func pieces(count: Int = 26, seed: UInt64) -> [Piece] {
        var state = seed &+ 0x9E3779B97F4A7C15
        func next() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
        return (0..<max(0, count)).map { index in
            // Fanned upward, from left to right.
            let angle = (-150 + 120 * next()) * Double.pi / 180
            let speed = 180 + 170 * next()
            return Piece(
                dx: cos(angle) * speed,
                dy: sin(angle) * speed,
                spin: (next() - 0.5) * 14,
                size: CGSize(width: 4 + 4 * next(), height: 2.5 + 3 * next()),
                hex: colors[index % colors.count]
            )
        }
    }

    /// Where a piece is `time` seconds after the burst, from where it started. It fades out over the last third.
    static func spot(_ piece: Piece, at time: Double, from origin: CGPoint) -> Spot {
        let t = min(max(time, 0), duration)
        let x = origin.x + piece.dx * t
        let y = origin.y + piece.dy * t + 0.5 * gravity * t * t
        let fadeFrom = duration * 2 / 3
        let opacity = t <= fadeFrom ? 1 : max(0, 1 - (t - fadeFrom) / (duration - fadeFrom))
        return Spot(point: CGPoint(x: x, y: y), angle: piece.spin * t, opacity: opacity)
    }
}
