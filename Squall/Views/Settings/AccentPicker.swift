import SwiftUI

/// The accent color picker in Settings: a grid of glowing color swatches with a
/// check on the one you picked, and a little preview of how the app looks in it.
struct AccentPicker: View {
    @Binding var selection: UInt32
    @AppStorage(Prefs.haptics) private var haptics = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var picked: Color { Color(hex: selection) }
    private var pickedName: String {
        Theme.accentChoices.first { $0.hex == selection }?.name ?? "Custom"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            preview
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: 10)], spacing: 12) {
                ForEach(Theme.accentChoices.indices, id: \.self) { index in
                    swatch(Theme.accentChoices[index])
                }
            }
        }
        .sensoryFeedback(.selection, trigger: selection) { _, _ in haptics }
    }

    // MARK: Preview

    /// A tiny piece of the app painted in the picked color.
    private var preview: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Color.shade(selection, towardWhite: true, 0.35), picked],
                                         center: .topLeading, startRadius: 2, endRadius: 40))
                Image(systemName: "bolt.fill")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)
            .shadow(color: picked.opacity(0.7), radius: 10)
            VStack(alignment: .leading, spacing: 6) {
                Text(pickedName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                    .contentTransition(.opacity)
                HStack(spacing: 6) {
                    Capsule()
                        .fill(picked)
                        .frame(width: 54, height: 8)
                    Capsule()
                        .fill(picked.opacity(0.45))
                        .frame(width: 30, height: 8)
                    Capsule()
                        .fill(picked.opacity(0.2))
                        .frame(width: 18, height: 8)
                }
            }
            Spacer(minLength: 0)
            Text("Send")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(picked))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(LinearGradient(colors: [picked.opacity(0.28), picked.opacity(0.06)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(picked.opacity(0.45), lineWidth: 1)
        )
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: selection)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview in \(pickedName)")
    }

    // MARK: Swatch

    private func swatch(_ choice: (name: String, hex: UInt32)) -> some View {
        let isOn = choice.hex == selection
        let color = Color(hex: choice.hex)
        return Button {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                selection = choice.hex
            }
        } label: {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [Color.shade(choice.hex, towardWhite: true, 0.3), color],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 38, height: 38)
                        .shadow(color: color.opacity(isOn ? 0.8 : 0), radius: 8)
                    Circle()
                        .stroke(Color.white, lineWidth: 2.5)
                        .frame(width: 46, height: 46)
                        .opacity(isOn ? 1 : 0)
                        .scaleEffect(isOn ? 1 : 0.8)
                    if isOn {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .heavy))
                            .foregroundStyle(.white)
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 48, height: 48)
                .scaleEffect(isOn ? 1.05 : 1)
                Text(choice.name)
                    .font(.system(size: 10.5, weight: isOn ? .bold : .medium))
                    .foregroundStyle(isOn ? Theme.textBright : Theme.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.name)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }
}
