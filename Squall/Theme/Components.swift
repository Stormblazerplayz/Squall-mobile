import SwiftUI

/// Dark background with the purple and teal glow from the concepts.
struct GlowBackground: View {
    var topHex: UInt32 = 0x7C5CF6
    var bottomHex: UInt32 = 0x20B296

    var body: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Color(hex: topHex, opacity: 0.24), Color(hex: topHex, opacity: 0)],
                center: .topLeading,
                startRadius: 0,
                endRadius: 520
            )
            RadialGradient(
                colors: [Color(hex: bottomHex, opacity: 0.16), Color(hex: bottomHex, opacity: 0)],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: 480
            )
        }
        .ignoresSafeArea()
    }
}

/// The glowing ball avatar every bot has, with its first letter.
struct Sphere: View {
    let hex: UInt32
    let letter: String
    var size: CGFloat = 44
    var glow: Double = 0.35

    var body: some View {
        Circle()
            .fill(
                RadialGradient(
                    colors: [
                        Color.shade(hex, towardWhite: true, 0.5),
                        Color(hex: hex),
                        Color.shade(hex, towardWhite: false, 0.42)
                    ],
                    center: UnitPoint(x: 0.34, y: 0.28),
                    startRadius: 0,
                    endRadius: size * 0.78
                )
            )
            .frame(width: size, height: size)
            .overlay(
                Text(letter)
                    .font(.system(size: size * 0.42, weight: .bold))
                    .foregroundStyle(Color.brightness(hex) > 0.62 ? Theme.darkInk : Color.white)
            )
            .shadow(color: Color(hex: hex, opacity: glow), radius: size * 0.22)
            .accessibilityHidden(true)
    }
}

extension Sphere {
    init(bot: Bot, size: CGFloat = 44, glow: Double = 0.35) {
        self.init(hex: bot.hex, letter: bot.letter, size: size, glow: glow)
    }
}

/// Small rounded label with a colored dot, like "Working" or "Napping".
struct StatusPill: View {
    let status: BotStatus
    var text: String? = nil

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.dot)
                .frame(width: 7, height: 7)
            Text(text ?? status.label)
                .font(.system(size: 12, weight: .semibold))
                .lineLimit(1)
        }
        .foregroundStyle(status.foreground)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Capsule().fill(status.background))
        .overlay(Capsule().stroke(status.border, lineWidth: 1))
    }
}

/// Glassy card: faint fill with a thin border, optionally tinted with a bot color.
struct GlassCard: ViewModifier {
    var radius: CGFloat = 20
    var tintHex: UInt32? = nil
    var tintStrength: Double = 0.13
    var borderColor: Color? = nil

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .stroke(border, lineWidth: 1)
            )
    }

    private var fill: LinearGradient {
        if let tintHex {
            return LinearGradient(
                colors: [Color(hex: tintHex, opacity: tintStrength), Color.white.opacity(0.02)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(colors: [Theme.card, Theme.card], startPoint: .top, endPoint: .bottom)
    }

    private var border: Color {
        if let borderColor { return borderColor }
        if let tintHex { return Color(hex: tintHex, opacity: 0.24) }
        return Theme.cardBorder
    }
}

extension View {
    func glassCard(radius: CGFloat = 20, tint: UInt32? = nil, strength: Double = 0.13, border: Color? = nil) -> some View {
        modifier(GlassCard(radius: radius, tintHex: tint, tintStrength: strength, borderColor: border))
    }
}

/// Big filled button (accent color by default).
struct FilledButtonStyle: ButtonStyle {
    var fill: Color
    var foreground: Color = .white
    var height: CGFloat = 46

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(foreground)
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

/// Outlined see-through button.
struct GhostButtonStyle: ButtonStyle {
    var height: CGFloat = 46
    var expand: Bool = true
    var foreground: Color = Theme.text
    var border: Color = Color.white.opacity(0.14)
    var fill: Color = Color.white.opacity(0.05)
    var fontSize: CGFloat = 15
    var sidePadding: CGFloat = 18

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.horizontal, sidePadding)
            .frame(maxWidth: expand ? .infinity : nil)
            .frame(height: height)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(fill))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(border, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Small rounded chip that can be on or off.
struct ChipButtonStyle: ButtonStyle {
    var isOn: Bool = false
    var tint: Color
    var minHeight: CGFloat = 36

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isOn ? Theme.textBright : Theme.grayText)
            .padding(.horizontal, 12)
            .frame(minHeight: minHeight)
            .background(Capsule().fill(isOn ? tint.opacity(0.24) : Color.white.opacity(0.04)))
            .overlay(Capsule().stroke(isOn ? tint.opacity(0.7) : Color.white.opacity(0.12), lineWidth: 1))
            .opacity(configuration.isPressed ? 0.75 : 1)
    }
}

/// Square icon button used in headers.
struct IconButton: View {
    let systemName: String
    let label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Color(hex: 0xC9CBE0))
                .frame(width: 44, height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Uppercase section heading like "SAFETY".
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12.5, weight: .bold))
            .tracking(0.9)
            .foregroundStyle(Theme.label)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 4)
    }
}

/// A row with a title, a small explanation and a switch.
struct SwitchRow: View {
    let title: String
    var subtitle: String? = nil
    @Binding var isOn: Bool
    var tint: Color

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(tint)
        .frame(minHeight: 44)
    }
}

/// Three bouncing dots shown while a bot is writing.
struct TypingDots: View {
    @State private var animating = false

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Theme.sub)
                    .frame(width: 7, height: 7)
                    .offset(y: animating ? -3 : 3)
                    .animation(
                        .easeInOut(duration: 0.45)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.15),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
        .accessibilityHidden(true)
    }
}

/// Segmented picker in the concept style (pill buttons inside a dark track).
struct PillSegments<Value: Hashable>: View {
    let options: [(label: String, value: Value)]
    @Binding var selection: Value

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let option = options[index]
                let isOn = option.value == selection
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { selection = option.value }
                } label: {
                    Text(option.label)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isOn ? Theme.textBright : Theme.sub)
                        .frame(maxWidth: .infinity, minHeight: 38)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(isOn ? Color.white.opacity(0.14) : Color.clear)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(Theme.field))
    }
}

/// The pop-up message at the top of the screen.
struct ToastView: View {
    let toast: ToastMessage
    var onAction: (ToastAction) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Theme.goldBright)
            Text(toast.text)
                .font(.system(size: 13.5, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let action = toast.action {
                Button(action.label) { onAction(action) }
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Theme.goldText)
                    .buttonStyle(.plain)
                    .frame(minHeight: 32)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(hex: 0x1C1A28, opacity: 0.97))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.cardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 15, y: 8)
        .padding(.horizontal, 16)
    }
}

/// Text field with the dark rounded look.
struct DarkField: View {
    let placeholder: String
    @Binding var text: String
    var axis: Axis = .horizontal

    var body: some View {
        TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(Theme.muted), axis: axis)
            .font(.system(size: 15))
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
