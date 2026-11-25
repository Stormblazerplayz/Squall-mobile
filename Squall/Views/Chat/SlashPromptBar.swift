import SwiftUI

/// Shows above the message box while it holds a slash search like "/fix" (see SlashPrompts).
/// Tap a prompt to put it in the box.
struct SlashPromptBar: View {
    @Binding var draft: String
    let botName: String
    var tint: Color = Color(hex: Theme.defaultAccentHex)
    @ObservedObject private var prompts = SavedPrompts.shared
    /// The box's words when you closed the list, so it stays closed until you type something else.
    @State private var closedAt: String?

    var body: some View {
        let query = SlashPrompts.query(draft)
        let showing = query != nil && closedAt != draft
        VStack(spacing: 0) {
            if showing, let query {
                panel(query)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.18), value: showing)
    }

    private func panel(_ query: String) -> some View {
        let found = SlashPrompts.matches(prompts.items, query: query)
        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 6) {
                Image(systemName: "text.book.closed")
                    .font(.system(size: 11, weight: .bold))
                Text(query.isEmpty ? "Saved prompts" : "Saved prompts with \u{201C}\(query)\u{201D}")
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button {
                    closedAt = draft
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close saved prompts")
            }
            .foregroundStyle(Theme.sub)
            .padding(.leading, 12)
            .padding(.trailing, 4)
            if found.isEmpty {
                Text(prompts.items.isEmpty
                     ? "No saved prompts yet. Press and hold a message you sent and pick Save as prompt."
                     : "No prompt matches. Keep typing to send it as a message.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.bottom, 10)
            } else {
                VStack(spacing: 0) {
                    ForEach(found) { item in
                        Button {
                            if let text = prompts.use(item.id, name: botName) {
                                // A prompt that itself starts with "/" shouldn't open the list again.
                                closedAt = text
                                draft = text
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.textBright)
                                    .lineLimit(1)
                                Text(SlashPrompts.preview(item.text))
                                    .font(.system(size: 12.5))
                                    .foregroundStyle(Theme.sub)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Use \(item.title)")
                        if item.id != found.last?.id {
                            Rectangle().fill(Color.white.opacity(0.06)).frame(height: 1).padding(.leading, 12)
                        }
                    }
                }
                .padding(.bottom, 4)
            }
        }
        .padding(.top, 2)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.field)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(tint.opacity(0.35), lineWidth: 1)
                )
        )
        .padding(.horizontal, 12)
        .padding(.top, 6)
    }
}
