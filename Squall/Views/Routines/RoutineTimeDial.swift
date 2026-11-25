import SwiftUI

/// A 24-hour dial to pick when a routine runs. Drag the knob around (it snaps to
/// 15 minutes); the ring goes from night blue through sunrise to day and back.
/// Midnight is at the top and noon at the bottom. VoiceOver can swipe up and down
/// to move it 15 minutes at a time.
struct RoutineTimeDial: View {
    @Binding var minutes: Int
    var tint: Color
    var size: CGFloat = 230
    @State private var dragging = false
    @AppStorage(Prefs.haptics) private var haptics = true

    private static let day = 24 * 60
    private static let snap = 15

    var body: some View {
        let line: CGFloat = 22
        let radius = size / 2 - line / 2
        ZStack {
            // The sky: night, sunrise, day, sunset, night.
            Circle()
                .stroke(
                    AngularGradient(
                        colors: [Self.night, Self.night, Self.dawn, Self.noon, Self.noon, Self.dusk, Self.night, Self.night],
                        center: .center,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(270)
                    ),
                    lineWidth: line
                )
                .opacity(0.85)
            // Hour marks.
            ForEach(0..<24, id: \.self) { hour in
                Capsule()
                    .fill(Color.white.opacity(hour % 6 == 0 ? 0.55 : 0.18))
                    .frame(width: hour % 6 == 0 ? 2 : 1, height: hour % 6 == 0 ? 10 : 5)
                    .offset(y: -(radius - line / 2 - 10))
                    .rotationEffect(.degrees(Double(hour) * 15))
            }
            // Labels at 12 AM, 6 AM, 12 PM and 6 PM.
            ForEach([0, 6, 12, 18], id: \.self) { hour in
                Text(Self.hourLabel(hour))
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .offset(Self.offset(for: Double(hour) * 60, radius: radius - line / 2 - 26))
            }
            // The middle: the time and a sun or moon.
            VStack(spacing: 2) {
                Image(systemName: Self.symbol(for: minutes))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Self.isDaytime(minutes) ? Theme.goldBright : Color(hex: 0xA9B8FF))
                    .contentTransition(.symbolEffect(.replace))
                Text(TimeText.time(minutes: minutes))
                    .font(.system(size: 26, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textBright)
                    .monospacedDigit()
                    .contentTransition(.numericText(value: Double(minutes)))
                Text(Self.partOfDay(minutes))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.sub)
            }
            // The knob.
            Circle()
                .fill(Color.white)
                .frame(width: line + 8, height: line + 8)
                .overlay(Circle().fill(tint).padding(5))
                .shadow(color: tint.opacity(0.7), radius: dragging ? 12 : 6)
                .scaleEffect(dragging ? 1.15 : 1)
                .offset(Self.offset(for: Double(minutes), radius: radius))
                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: dragging)
        }
        .frame(width: size, height: size)
        .contentShape(Circle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    dragging = true
                    let center = CGPoint(x: size / 2, y: size / 2)
                    let picked = Self.minutes(at: value.location, center: center)
                    if picked != minutes {
                        withAnimation(.interactiveSpring(response: 0.2, dampingFraction: 0.85)) { minutes = picked }
                    }
                }
                .onEnded { _ in dragging = false }
        )
        .sensoryFeedback(.selection, trigger: minutes) { _, _ in haptics }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Time")
        .accessibilityValue(TimeText.time(minutes: minutes))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: minutes = (minutes + Self.snap) % Self.day
            case .decrement: minutes = (minutes - Self.snap + Self.day) % Self.day
            @unknown default: break
            }
        }
    }

    // MARK: Math (static so it can be tested)

    /// Minutes after midnight for a point on the dial, snapped to 15 minutes. Midnight is at the top.
    static func minutes(at point: CGPoint, center: CGPoint) -> Int {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        // atan2 measured from the top, going clockwise.
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * .pi }
        let raw = angle / (2 * .pi) * Double(day)
        let snapped = Int((raw / Double(snap)).rounded()) * snap
        return snapped % day
    }

    /// Where on the dial a time sits, as an offset from the middle.
    static func offset(for minutes: Double, radius: CGFloat) -> CGSize {
        let angle = minutes / Double(day) * 2 * .pi
        return CGSize(width: sin(angle) * Double(radius), height: -cos(angle) * Double(radius))
    }

    static func isDaytime(_ minutes: Int) -> Bool {
        (6 * 60..<19 * 60).contains(minutes)
    }

    static func symbol(for minutes: Int) -> String {
        switch minutes / 60 {
        case 5..<8: return "sunrise.fill"
        case 8..<17: return "sun.max.fill"
        case 17..<20: return "sunset.fill"
        default: return "moon.stars.fill"
        }
    }

    static func partOfDay(_ minutes: Int) -> String {
        switch minutes / 60 {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }

    static func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12A"
        case 12: return "12P"
        default: return hour < 12 ? "\(hour)A" : "\(hour - 12)P"
        }
    }

    private static let night = Color(hex: 0x2B2F7A)
    private static let dawn = Color(hex: 0xF0913A)
    private static let noon = Color(hex: 0xF5C84B)
    private static let dusk = Color(hex: 0xE0607E)
}
