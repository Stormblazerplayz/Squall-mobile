import SwiftUI

/// The moving light around Chief on a call. It shows what the call is doing:
/// - listening: a wavy ring that grows with your voice
/// - thinking: three dots that circle Chief
/// - speaking: rings that ripple out to a beat
/// - anything else: a soft, slow glow
/// It holds still (just a plain ring) when Reduce Motion is on.
struct VoiceOrb: View {
    enum Mood: Equatable {
        case idle, listening, thinking, speaking
    }

    let mood: Mood
    /// How loud you are, 0 to 1 (only used while listening).
    let level: Double
    let size: CGFloat
    let listenColor: Color
    let chiefColor: Color
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Circle()
                    .stroke((mood == .listening ? listenColor : chiefColor).opacity(0.5), lineWidth: 3)
                    .frame(width: size, height: size)
            } else {
                TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
                    let time = context.date.timeIntervalSinceReferenceDate
                    Canvas { canvas, area in
                        draw(in: &canvas, area: area, time: time)
                    }
                    .frame(width: size * 1.35, height: size * 1.35)
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(in canvas: inout GraphicsContext, area: CGSize, time: Double) {
        let center = CGPoint(x: area.width / 2, y: area.height / 2)
        let base = Double(size) / 2
        switch mood {
        case .listening:
            // Two wavy rings that bulge more the louder you talk.
            let loud = min(max(level, 0), 1)
            for layer in 0..<2 {
                let path = wavyCircle(center: center, radius: base * (0.92 + 0.06 * Double(layer)),
                                      bumps: 6 + layer * 3, height: base * (0.03 + 0.16 * loud),
                                      turn: time * (layer == 0 ? 1.4 : -1.0))
                canvas.stroke(path, with: .color(listenColor.opacity(layer == 0 ? 0.75 : 0.35)), lineWidth: layer == 0 ? 3 : 2)
            }
            let glow = Path(ellipseIn: CGRect(x: center.x - base, y: center.y - base, width: base * 2, height: base * 2))
            canvas.fill(glow, with: .radialGradient(Gradient(colors: [listenColor.opacity(0.10 + 0.25 * loud), .clear]),
                                                    center: center, startRadius: base * 0.6, endRadius: base * 1.25))
        case .thinking:
            // Three dots chasing each other around Chief.
            for index in 0..<3 {
                let angle = time * 2.4 + Double(index) * 0.55
                let radius = base * 0.98
                let point = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                let dot = 7.0 - Double(index) * 1.5
                canvas.fill(Path(ellipseIn: CGRect(x: point.x - dot / 2, y: point.y - dot / 2, width: dot, height: dot)),
                            with: .color(chiefColor.opacity(1 - Double(index) * 0.25)))
            }
            let ring = Path(ellipseIn: CGRect(x: center.x - base * 0.98, y: center.y - base * 0.98, width: base * 1.96, height: base * 1.96))
            canvas.stroke(ring, with: .color(chiefColor.opacity(0.15)), lineWidth: 1.5)
        case .speaking:
            // Ripples that leave Chief to the beat of talking.
            for index in 0..<3 {
                let phase = (time * 0.9 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                let radius = base * (0.9 + 0.38 * phase)
                let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                canvas.stroke(ring, with: .color(chiefColor.opacity(0.55 * (1 - phase))), lineWidth: 2.5)
            }
            let beat = 0.5 + 0.5 * sin(time * 9) * sin(time * 2.3)
            let path = wavyCircle(center: center, radius: base * 0.94, bumps: 5, height: base * (0.02 + 0.06 * beat), turn: time * 0.8)
            canvas.stroke(path, with: .color(chiefColor.opacity(0.8)), lineWidth: 3)
        case .idle:
            // A slow breathing glow.
            let breathe = 0.5 + 0.5 * sin(time * 1.3)
            let radius = base * (0.95 + 0.05 * breathe)
            let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            canvas.stroke(ring, with: .color(chiefColor.opacity(0.25 + 0.2 * breathe)), lineWidth: 2)
            let glow = Path(ellipseIn: CGRect(x: center.x - base * 1.3, y: center.y - base * 1.3, width: base * 2.6, height: base * 2.6))
            canvas.fill(glow, with: .radialGradient(Gradient(colors: [chiefColor.opacity(0.10 + 0.08 * breathe), .clear]),
                                                    center: center, startRadius: base * 0.7, endRadius: base * 1.3))
        }
    }

    /// A circle with soft bumps around it, turned by `turn` radians.
    private func wavyCircle(center: CGPoint, radius: Double, bumps: Int, height: Double, turn: Double) -> Path {
        var path = Path()
        let steps = 120
        for step in 0...steps {
            let angle = Double(step) / Double(steps) * 2 * .pi
            let wobble = sin(angle * Double(bumps) + turn) * height + sin(angle * Double(bumps + 2) - turn * 1.3) * height * 0.4
            let r = radius + wobble
            let point = CGPoint(x: center.x + cos(angle) * r, y: center.y + sin(angle) * r)
            if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

extension VoiceOrb.Mood {
    init(_ state: VoiceCall.State) {
        switch state {
        case .listening: self = .listening
        case .thinking, .connecting: self = .thinking
        case .speaking: self = .speaking
        case .idle, .ended, .failed: self = .idle
        }
    }
}
