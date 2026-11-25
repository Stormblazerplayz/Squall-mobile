import SwiftUI

/// Teammates to mention, over the message box while you type @. Tap one to finish the name.
struct MentionPickerBar: View {
    @Binding var draft: String
    let bots: [Bot]
    var tint: Color = Color(hex: Theme.defaultAccentHex)

    var body: some View {
        let found = MentionPicker.query(draft).map { MentionPicker.matches(bots, query: $0) } ?? []
        VStack(spacing: 0) {
            if !found.isEmpty {
                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(found) { bot in
                            Button {
                                draft = MentionPicker.insert(bot.name, into: draft)
                            } label: {
                                HStack(spacing: 6) {
                                    Sphere(bot: bot, size: 22, glow: 0.2)
                                    Text("@" + bot.name)
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.textBright)
                                }
                                .padding(.leading, 4)
                                .padding(.trailing, 12)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule()
                                        .fill(Theme.field)
                                        .overlay(Capsule().stroke(bot.color.opacity(0.45), lineWidth: 1))
                                )
                                .contentShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Mention \(bot.name)")
                        }
                    }
                    .padding(.horizontal, 12)
                }
                .scrollIndicators(.hidden)
                .padding(.top, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: found.map(\.id))
        .tint(tint)
    }
}
