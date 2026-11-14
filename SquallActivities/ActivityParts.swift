import SwiftUI
import WidgetKit

/// Colors and small pieces shared by all five Live Activities.
enum Palette {
    static let background = Color(activityHex: 0x15131F, opacity: 0.94)
    static let text = Color(activityHex: 0xF3F2FA)
    static let sub = Color(activityHex: 0xA9ABBF)
    static let muted = Color(activityHex: 0x6B7080)
    static let track = Color.white.opacity(0.13)
    static let button = Color.white.opacity(0.12)
    static let green = Color(activityHex: 0x4ADE80)
    static let greenText = Color(activityHex: 0x86EFAC)
    static let red = Color(activityHex: 0xE5484D)
    static let gold = Color(activityHex: 0xD8B747)
    static let goldText = Color(activityHex: 0xF1D77A)
    static let ink = Color(activityHex: 0x16131F)
    static let accent = Color(activityHex: 0x6D5CE8)
    static let accentText = Color(activityHex: 0xC9C6F5)

    static let blueHex: UInt32 = 0x3B87D6
    static let goldHex: UInt32 = 0xD8B747
    static let tealHex: UInt32 = 0x2FB39A
    static let tealText = Color(activityHex: 0x5EEAD4)
}

/// A bot's colored ball with its first letter.
struct Avatar: View {
    let letter: String
    let hex: UInt32
    var size: CGFloat = 34

    var body: some View {
        Circle()
            .fill(Color(activityHex: hex))
            .overlay(
                Circle().fill(
                    LinearGradient(colors: [Color.white.opacity(0.38), .clear], startPoint: .topLeading, endPoint: .center)
                )
            )
            .overlay(
                Text(letter)
                    .font(.system(size: size * 0.46, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            )
            .frame(width: size, height: size)
    }
}

/// Avatar with a progress ring around it, for the Dynamic Island's smallest view.
struct RingAvatar: View {
    let letter: String
    let hex: UInt32
    let progress: Double
    var ring: Color = Palette.tealText

    var body: some View {
        ZStack {
            Circle().stroke(Palette.track, lineWidth: 2.5)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(ring, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Avatar(letter: letter, hex: hex, size: 15)
        }
        .frame(width: 22, height: 22)
    }
}

/// The top line of every activity: avatar, who and what, and a short value on the right.
struct ActivityHeader<Lead: View, Trailing: View>: View {
    let sub: String
    let title: String
    @ViewBuilder var lead: Lead
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            lead
            VStack(alignment: .leading, spacing: 1) {
                Text(sub)
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Palette.sub)
                    .lineLimit(1)
                Text(title)
                    .font(.system(size: 15.5, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            trailing
        }
    }
}

/// A rounded progress bar.
struct Bar<Fill: ShapeStyle>: View {
    let value: Double
    let fill: Fill
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Palette.track)
                Capsule()
                    .fill(fill)
                    .frame(width: max(height, geo.size.width * max(0, min(1, value))))
            }
        }
        .frame(height: height)
    }
}

/// The look of every button on the Lock Screen and in the Dynamic Island.
struct Pill: View {
    enum Style {
        case plain, primary, gold, end, on
    }

    let title: String
    var icon: String? = nil
    var style: Style = .plain

    var body: some View {
        HStack(spacing: 5) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11.5, weight: .bold))
            }
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity)
        .frame(height: 30)
        .background(Capsule().fill(fill))
    }

    private var fill: Color {
        switch style {
        case .plain: return Palette.button
        case .primary: return Palette.accent
        case .gold: return Palette.gold
        case .end: return Palette.red
        case .on: return Color.white.opacity(0.88)
        }
    }

    private var foreground: Color {
        switch style {
        case .gold, .on: return Palette.ink
        default: return .white
        }
    }
}

extension View {
    /// The dark card the Lock Screen version sits on.
    func lockScreenCard() -> some View {
        self
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .activityBackgroundTint(Palette.background)
            .activitySystemActionForegroundColor(.white)
    }
}

/// "4:05" from a number of seconds.
func clock(_ seconds: Int) -> String {
    let s = max(0, seconds)
    return "\(s / 60):" + (s % 60 < 10 ? "0" : "") + "\(s % 60)"
}
