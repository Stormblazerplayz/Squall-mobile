import SwiftUI
import Translation

/// The Info sheet for a message: who wrote it, when, and how long it is.
struct MessageInfoSheet: View {
    let message: ChatMessage
    let authorName: String
    let tint: Color

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let facts = MessageInfo.facts(for: message, authorName: authorName)
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(Markdown.plain(StarredMessages.words(of: message)))
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.sub)
                        .lineLimit(4)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(tint.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(tint.opacity(0.35), lineWidth: 1)
                                )
                        )
                    VStack(spacing: 0) {
                        ForEach(Array(facts.enumerated()), id: \.element.id) { index, fact in
                            HStack(alignment: .firstTextBaseline) {
                                Text(fact.label)
                                    .font(.system(size: 14.5))
                                    .foregroundStyle(Theme.sub)
                                Spacer(minLength: 12)
                                Text(fact.value)
                                    .font(.system(size: 14.5, weight: .semibold))
                                    .foregroundStyle(Theme.textBright)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.vertical, 11)
                            .padding(.horizontal, 14)
                            .accessibilityElement(children: .combine)
                            if index < facts.count - 1 {
                                Rectangle().fill(Color.white.opacity(0.07)).frame(height: 1).padding(.leading, 14)
                            }
                        }
                    }
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.05)))
                }
                .padding(16)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Message info")
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
}

/// Shows Apple's Translate card for the message's words. Translate needs iOS 17.4, so older phones skip it.
struct TranslateCard: ViewModifier {
    @Binding var isPresented: Bool
    let text: String

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(iOS 17.4, *) {
            content.translationPresentation(isPresented: $isPresented, text: text)
        } else {
            content
        }
    }
}

enum TranslateSupport {
    static var isAvailable: Bool {
        if #available(iOS 17.4, *) { return true }
        return false
    }
}
