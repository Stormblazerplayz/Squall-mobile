import SwiftUI

/// A small speaker next to a reply's name while it's being read aloud. Tap it to stop.
struct ReadingMark: View {
    let id: String
    var tint: Color = Color(hex: Theme.defaultAccentHex)
    @ObservedObject private var reader = ReadAloud.shared
    @State private var pulse = false

    var body: some View {
        if reader.isReading(id) {
            Button {
                reader.stop()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.system(size: 10, weight: .bold))
                        .opacity(pulse ? 0.45 : 1)
                    Text("Stop")
                        .font(.system(size: 10.5, weight: .bold))
                }
                .foregroundStyle(tint)
                .padding(.horizontal, 7)
                .frame(height: 20)
                .background(Capsule().fill(tint.opacity(0.16)))
                .contentShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop reading aloud")
            .onAppear {
                withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) { pulse = true }
            }
            .onDisappear { pulse = false }
        }
    }
}
