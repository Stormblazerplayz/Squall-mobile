import SwiftUI

/// The Go to a day list: each day in this chat with its count and first words. Tap one to go there.
struct ChatDaySheet: View {
    @Environment(\.dismiss) private var dismiss
    let bot: Bot
    let messages: [ChatMessage]

    var body: some View {
        let days = ChatDayJump.days(messages)
        NavigationStack {
            Group {
                if days.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "calendar")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.muted)
                        Text("No dated messages yet")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textBright)
                        Text("Days show here once \(bot.name)'s computer sends message times.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.sub)
                            .multilineTextAlignment(.center)
                    }
                    .padding(32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 8) {
                            ForEach(days) { day in
                                Button {
                                    ChatDayJump.Model.shared.go(chatID: bot.id, messageID: day.firstID)
                                    dismiss()
                                } label: {
                                    row(day)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Go to a day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private func row(_ day: ChatDayJump.Day) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Text(day.start.formatted(.dateTime.month(.abbreviated)).uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(bot.color)
                Text(day.start.formatted(.dateTime.day()))
                    .font(.system(size: 20, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.textBright)
            }
            .frame(width: 46, height: 46)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(bot.color.opacity(0.14)))
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(ChatDayJump.title(day.start))
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                    Spacer(minLength: 8)
                    Text(ChatDayJump.countText(day.count))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
                if !day.preview.isEmpty {
                    Text(day.preview)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)
                        .lineLimit(2)
                }
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.muted)
                .padding(.top, 4)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Goes to the first message that day")
    }
}
