import SwiftUI

struct ChatView: View {
    @EnvironmentObject private var store: SquallStore
    @AppStorage("hapticsOn") private var hapticsOn = true
    @State private var draft = ""
    @FocusState private var inputFocused: Bool

    private let typingID = "typing-indicator"

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(store.messages) { message in
                            MessageBubble(message: message)
                                .id(message.id)
                        }
                        if store.isTyping {
                            TypingIndicator()
                                .id(typingID)
                        }
                    }
                    .padding()
                }
                .scrollDismissesKeyboard(.interactively)
                .background(Theme.background.ignoresSafeArea())
                .onChange(of: store.messages.count) {
                    scrollToBottom(proxy)
                }
                .onChange(of: store.isTyping) {
                    scrollToBottom(proxy)
                }
                .onAppear {
                    scrollToBottom(proxy, animated: false)
                }
            }
            .safeAreaInset(edge: .bottom) {
                inputBar
            }
            .navigationTitle("Team chat")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: store.messages.count) { _, _ in
            hapticsOn
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("Message your team…", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .focused($inputFocused)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .card(cornerRadius: 20)

            Button(action: send) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(Theme.background)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(canSend ? Theme.accent : Color.gray.opacity(0.4)))
            }
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func send() {
        guard canSend else { return }
        store.send(draft)
        draft = ""
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy, animated: Bool = true) {
        if store.isTyping {
            scroll(proxy, to: typingID, animated: animated)
        } else if let last = store.messages.last {
            scroll(proxy, to: last.id, animated: animated)
        }
    }

    private func scroll<ID: Hashable>(_ proxy: ScrollViewProxy, to id: ID, animated: Bool) {
        if animated {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(id, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(id, anchor: .bottom)
        }
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .bottom) {
            if message.isMine {
                Spacer(minLength: 48)
            }
            VStack(alignment: message.isMine ? .trailing : .leading, spacing: 4) {
                if !message.isMine {
                    Text(message.senderName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
                Text(message.text)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .foregroundStyle(message.isMine ? Theme.background : Color.white)
                    .background(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(message.isMine ? Theme.accent : Theme.card)
                    )
                Text(message.date, style: .time)
                    .font(.caption2)
                    .foregroundStyle(Theme.textSecondary)
            }
            if !message.isMine {
                Spacer(minLength: 48)
            }
        }
    }
}

struct TypingIndicator: View {
    @State private var animating = false

    var body: some View {
        HStack {
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(Theme.textSecondary)
                        .frame(width: 7, height: 7)
                        .scaleEffect(animating ? 1 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever()
                                .delay(Double(index) * 0.15),
                            value: animating
                        )
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.card)
            )
            Spacer()
        }
        .onAppear { animating = true }
        .accessibilityLabel("Typing")
    }
}

#Preview {
    ChatView()
        .environmentObject(SquallStore())
        .preferredColorScheme(.dark)
}
