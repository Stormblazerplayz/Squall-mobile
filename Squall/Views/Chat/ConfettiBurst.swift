import SwiftUI

/// Confetti that bursts up from the middle of the view each time `trigger` goes up, then clears away. Nothing shows
/// with Reduce Motion on.
struct ConfettiBurst: View {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var startedAt: Date?

    var body: some View {
        ZStack {
            if let startedAt, !reduceMotion {
                let pieces = Confetti.pieces(seed: UInt64(max(trigger, 0)))
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let time = timeline.date.timeIntervalSince(startedAt)
                        let origin = CGPoint(x: size.width / 2, y: size.height / 2)
                        for piece in pieces {
                            let spot = Confetti.spot(piece, at: time, from: origin)
                            guard spot.opacity > 0 else { continue }
                            var copy = context
                            copy.opacity = spot.opacity
                            copy.translateBy(x: spot.point.x, y: spot.point.y)
                            copy.rotate(by: .radians(spot.angle))
                            let rect = CGRect(x: -piece.size.width / 2, y: -piece.size.height / 2,
                                              width: piece.size.width, height: piece.size.height)
                            copy.fill(Path(roundedRect: rect, cornerRadius: 1), with: .color(Color(hex: piece.hex)))
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onChange(of: trigger) {
            let started = Date()
            startedAt = started
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(Confetti.duration + 0.1))
                if startedAt == started { startedAt = nil }
            }
        }
    }
}
