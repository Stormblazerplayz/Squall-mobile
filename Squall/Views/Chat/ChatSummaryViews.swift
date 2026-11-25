import SwiftUI

/// Under a long teammate message: a Summary button, then the summary itself.
@MainActor
struct MessageSummary: View {
    let chatID: String
    let messageID: String
    let tint: Color

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var feed = HistoryFeed.shared
    @State private var asking = false

    var body: some View {
        let _ = feed.stamp
        if let info = ChatSummaries.current() {
            let job = info.job(chatID: chatID, messageID: messageID)
            if let summary = info.summary(chatID: chatID, messageID: messageID) {
                VStack(alignment: .leading, spacing: 4) {
                    Label("Summary", systemImage: "sparkles")
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(tint)
                    Text(summary)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(tint.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(tint.opacity(0.3), lineWidth: 1))
                .transition(.opacity)
            } else if asking || (job != nil && job?.failed == false) {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini).tint(tint)
                    Text("Summarizing…")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.sub)
                }
                .frame(height: 28)
            } else if let job, job.failed {
                HStack(spacing: 8) {
                    Text(ChatSummaries.failed("Couldn’t summarize", job.error))
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.sub)
                        .lineLimit(2)
                    Button("Try again") { ask() }
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(tint)
                        .buttonStyle(.plain)
                }
            } else {
                Button {
                    ask()
                } label: {
                    Label("Summary", systemImage: "sparkles")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 11)
                        .frame(height: 28)
                        .background(Capsule().fill(tint.opacity(0.16)))
                        .overlay(Capsule().stroke(tint.opacity(0.35), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Summarize this message")
            }
        }
    }

    private func ask() {
        asking = true
        Task {
            await store.perform(ChatSummaries.messageAction(chatID: chatID, messageID: messageID),
                                busyKey: "summary-\(chatID)-\(messageID)")
            // The job (or the summary) is in the state now, so the spinner can follow that.
            asking = false
        }
    }
}

/// Under a chat's header: a Catch me up button once the chat is busy, then the catch up itself.
@MainActor
struct CatchUpBar: View {
    let chatID: String
    let tintHex: UInt32

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var feed = HistoryFeed.shared
    @ObservedObject private var memory = CatchUpMemory.shared
    @State private var asking = false

    var body: some View {
        let _ = feed.stamp
        if let info = ChatSummaries.current(), let chat = info.chats[chatID] {
            let job = info.job(chatID: chatID, messageID: nil)
            let catchUp = info.catchUp(for: chatID)
            let working = asking || (job != nil && job?.failed == false)
            Group {
                if working {
                    slim {
                        ProgressView().controlSize(.small).tint(Color(hex: tintHex))
                        Text("Catching you up…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Spacer(minLength: 0)
                    }
                } else if let catchUp, !memory.isClosed(chatID, at: catchUp.upTo) {
                    card(catchUp, hasNew: info.hasNew(chatID: chatID))
                } else if let job, job.failed {
                    slim {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(Theme.goldText)
                        Text(ChatSummaries.failed("Couldn’t catch you up", job.error))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.sub)
                            .lineLimit(2)
                        Spacer(minLength: 4)
                        Button("Try again") { ask() }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: tintHex))
                            .buttonStyle(.plain)
                    }
                } else if chat.count >= ChatSummaries.catchUpFrom, info.hasNew(chatID: chatID),
                          !memory.isClosed(chatID, at: chat.lastID) {
                    pill(lastID: chat.lastID)
                }
            }
            .animation(.easeOut(duration: 0.2), value: working)
        }
    }

    // MARK: - Parts

    private func pill(lastID: String?) -> some View {
        HStack(spacing: 0) {
            Button {
                ask()
            } label: {
                Label("Catch me up", systemImage: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textBright)
                    .padding(.leading, 14)
                    .padding(.trailing, 8)
                    .frame(height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Catch me up on this chat")
            Button {
                memory.close(chatID, at: lastID)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(Theme.sub)
                    .frame(width: 30, height: 32)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Hide Catch me up")
        }
        .background(Capsule().fill(Color(hex: tintHex).opacity(0.2)))
        .overlay(Capsule().stroke(Color(hex: tintHex).opacity(0.45), lineWidth: 1))
        .frame(maxWidth: .infinity)
        .padding(.bottom, 6)
        .transition(.opacity)
    }

    private func card(_ catchUp: ChatSummaries.CatchUp, hasNew: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(hex: tintHex))
                Text("Catch up")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Text(subtitle(catchUp))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button {
                    memory.close(chatID, at: catchUp.upTo)
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.sub)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close the catch up")
            }
            ScrollView {
                Text(catchUp.text)
                    .font(.system(size: 14.5))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxHeight: 150)
            .scrollBounceBehavior(.basedOnSize)
            if hasNew {
                Button {
                    ask()
                } label: {
                    Label("New messages since. Catch me up again", systemImage: "arrow.clockwise")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Color(hex: tintHex))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .glassCard(radius: 16, tint: tintHex, strength: 0.14)
        .padding(.horizontal, 12)
        .padding(.bottom, 6)
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func slim<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        HStack(spacing: 8) { content() }
            .padding(.horizontal, 12)
            .frame(minHeight: 40)
            .glassCard(radius: 14)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
    }

    private func subtitle(_ catchUp: ChatSummaries.CatchUp) -> String {
        let covers = ChatSummaries.covers(catchUp.count)
        guard let at = catchUp.at else { return covers }
        return "\(covers) · \(TeamHistory.clock(at))"
    }

    private func ask() {
        asking = true
        Task {
            await store.perform(ChatSummaries.catchUpAction(chatID: chatID), busyKey: "catchup-\(chatID)")
            asking = false
        }
    }
}
