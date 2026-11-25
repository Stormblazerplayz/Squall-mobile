import SwiftUI

/// In demo mode, a burst of confetti falls whenever a pretend job finishes, so you
/// can see that something happened. Never shows outside the demo or with Reduce Motion.
struct DemoConfetti: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var finished: Set<String> = []
    @State private var burstStart: Date?

    private static let length: TimeInterval = 2.6

    var body: some View {
        ZStack {
            if let burstStart, store.isDemo, !reduceMotion {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                    let age = context.date.timeIntervalSince(burstStart)
                    Canvas { canvas, size in
                        ConfettiPieces.draw(in: &canvas, size: size, age: age, length: Self.length)
                    }
                }
                .transition(.opacity)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { finished = doneIDs }
        .onChange(of: store.work) {
            let now = doneIDs
            let fresh = now.subtracting(finished)
            finished = now
            guard store.isDemo, !fresh.isEmpty else { return }
            burst()
        }
        .onChange(of: store.isDemo) {
            finished = doneIDs
            if !store.isDemo { burstStart = nil }
        }
    }

    private var doneIDs: Set<String> {
        Set(store.work.filter { $0.state == .done }.map(\.id))
    }

    private func burst() {
        let start = Date()
        burstStart = start
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(Self.length))
            if burstStart == start { burstStart = nil }
        }
    }
}

/// The pieces of one burst. Their spots and colors are fixed, so every burst looks
/// the same and nothing changes between frames except time.
enum ConfettiPieces {
    struct Piece {
        let x: Double
        let delay: Double
        let speed: Double
        let sway: Double
        let spin: Double
        let width: Double
        let height: Double
        let hex: UInt32
    }

    static let colors: [UInt32] = [Theme.demoHex, Theme.goldHex, 0x4ADE80, 0x60A5FA, 0xF472B6, 0xFDE68A]

    static let pieces: [Piece] = {
        var seed: UInt64 = 0xC0FF_EE11
        func next() -> Double {
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            return Double(seed >> 33) / Double(UInt32.max >> 1)
        }
        return (0..<70).map { index in
            Piece(x: next(),
                  delay: next() * 0.5,
                  speed: 0.45 + next() * 0.5,
                  sway: 10 + next() * 26,
                  spin: 2 + next() * 6,
                  width: 6 + next() * 5,
                  height: 3 + next() * 3,
                  hex: colors[index % colors.count])
        }
    }()

    /// Draws every piece `age` seconds into a burst that lasts `length` seconds.
    static func draw(in canvas: inout GraphicsContext, size: CGSize, age: Double, length: Double) {
        let fade = max(0, min(1, (length - age) / 0.6))
        for piece in pieces {
            let t = age - piece.delay
            guard t > 0 else { continue }
            // Falls from just above the top, faster as it goes.
            let y = -20 + (t * piece.speed + 0.18 * t * t) * Double(size.height) * 0.75
            guard y < Double(size.height) + 20 else { continue }
            let x = piece.x * Double(size.width) + sin(t * 3 + piece.x * 10) * piece.sway
            var copy = canvas
            copy.translateBy(x: x, y: y)
            copy.rotate(by: .radians(t * piece.spin))
            copy.opacity = fade
            let rect = CGRect(x: -piece.width / 2, y: -piece.height / 2, width: piece.width, height: piece.height)
            copy.fill(Path(roundedRect: rect, cornerRadius: 1.5), with: .color(Color(hex: piece.hex)))
        }
    }
}
