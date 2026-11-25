import Combine
import SwiftUI
import UIKit

/// One-on-one chat with a bot.
struct ChatView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var draft = ""
    @State private var sentCount = 0
    /// True while the end of the chat is on screen. New messages only pull the chat down then.
    @State private var atBottom = true
    /// When the end of the chat last went off screen. A new message can push it off for a moment, so that doesn't count.
    @State private var leftBottomAt: Date?
    /// The jump button, shown once you've really scrolled up.
    @State private var showJump = false
    /// The messages that were there when you scrolled up, so the button can count what's new.
    @State private var seenIDs = Set<String>()
    /// Where the "New messages" line goes: the first message that came in since you last had this chat open.
    @State private var newFromID: String?
    @AppStorage(Prefs.showTyping) private var showTyping = true
    @AppStorage(Prefs.sendOnReturn) private var sendOnReturn = false
    @AppStorage(Prefs.haptics) private var haptics = true
    @State private var showLiveLog = false
    @FocusState private var inputFocused: Bool

    var body: some View {
        let bot = store.currentChat
        let list = store.messages(for: bot.id)
        let dividers = ChatDays.dividers(list)
        let continued = ChatGrouping.continued(list)
        let isWide = sizeClass == .regular
        ZStack {
            GlowBackground(topHex: bot.hex)
            ChatWallpaperLayer(chatID: bot.id, tint: bot.color)
            HStack(spacing: 0) {
                if isWide {
                    // iPad: every chat in a column beside the conversation.
                    ChatList()
                        .frame(width: 320)
                    Rectangle()
                        .fill(Theme.cardBorder)
                        .frame(width: 1)
                        .ignoresSafeArea(edges: .top)
                }
                VStack(spacing: 0) {
                    ChatHeader(bot: bot, showLiveLog: $showLiveLog)
                    WorkTimerBanner(chatID: bot.id)
                    CatchUpBar(chatID: bot.id, tintHex: bot.hex)
                    PinnedBanner(chatID: bot.id, tint: bot.color)
                        .id(bot.id)
                    if !isWide {
                        BotStrip()
                    }
                    if showLiveLog {
                        LiveLogPanel(bot: bot)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 8)
                            .transition(.opacity)
                    }
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                if list.isEmpty && store.typingBotID != bot.id {
                                    emptyState(bot)
                                }
                                ForEach(list) { message in
                                    // A line where a new day starts, from the message's real time.
                                    if let day = dividers[message.id] {
                                        DayDivider(text: day)
                                    }
                                    if message.id == newFromID {
                                        NewMessagesLine(count: NewMessages.count(list, from: message.id))
                                    }
                                    MessageView(message: message, bot: bot, chatID: bot.id, continued: continued.contains(message.id)) { chip in
                                        store.send(chip)
                                    }
                                }
                                if let last = list.last, last.kind == .bot, last.chips.isEmpty, store.typingBotID != bot.id {
                                    // A quick question at the end of the chat gets tap-to-send answers.
                                    QuickReplyRow(text: last.text + (last.text2.map { "\n" + $0 } ?? ""),
                                                  tint: store.bot(last.author)?.color ?? bot.color) { reply in
                                        store.send(reply)
                                    }
                                }
                                OutboxBubbles(chatID: bot.id)
                                UndoSendBubbles(chatID: bot.id)
                                WorkNowCard(bot: bot)
                                if showTyping && store.typingBotID == bot.id {
                                    TypingRow(bot: bot)
                                }
                                Color.clear.frame(height: 1).id("bottom")
                                    .onAppear {
                                        atBottom = true
                                        leftBottomAt = nil
                                        showJump = false
                                    }
                                    .onDisappear {
                                        atBottom = false
                                        leftBottomAt = Date()
                                        seenIDs = Set(list.map(\.id))
                                        Task { @MainActor in
                                            try? await Task.sleep(for: .milliseconds(400))
                                            if !atBottom { showJump = true }
                                        }
                                    }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .readableColumn(780)
                        }
                        .scrollIndicators(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .onAppear { proxy.scrollTo("bottom", anchor: .bottom) }
                        .onChange(of: list.count) {
                            // Reading older messages isn't interrupted: the chat only follows when you're at the end or
                            // you just sent something. Otherwise the jump button counts what came in.
                            guard ChatDays.shouldFollow(atBottom: atBottom, leftBottomAt: leftBottomAt, newest: list.last) else { return }
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                        .onChange(of: store.typingBotID) {
                            guard ChatDays.shouldFollow(atBottom: atBottom, leftBottomAt: leftBottomAt, newest: nil) else { return }
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                        .onChange(of: bot.id) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                        .onChange(of: bot.id) {
                            seenIDs = Set(list.map(\.id))
                        }
                        .overlay(alignment: .bottom) {
                            if showJump && !list.isEmpty {
                                let unseen = ChatDays.unseen(seen: seenIDs, new: list)
                                JumpToLatestButton(count: unseen, tint: bot.color) {
                                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                                }
                                .padding(.bottom, 10)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                            }
                        }
                        .animation(.easeOut(duration: 0.2), value: showJump)
                        .pinchToResizeText(tint: bot.color)
                    }
                    SelectionBar(chatID: bot.id)
                    SlashPromptBar(draft: $draft, botName: bot.name, tint: bot.color)
                    inputBar(bot)
                }
                .readableColumn(isWide ? .infinity : Theme.readableWidth)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showLiveLog)
        .sensoryFeedback(.impact(weight: .light), trigger: sentCount) { _, _ in haptics }
        .onChange(of: draft) { _, new in SavedPrompts.shared.currentDraft = new }
        // Each chat keeps what you typed but didn't send (see ChatDrafts).
        .onChange(of: draft) { _, new in ChatDrafts.shared.set(new, for: store.currentChat.id) }
        .onChange(of: store.currentChat.id) { _, new in draft = ChatDrafts.shared.text(for: new) }
        .onAppear {
            if draft.isEmpty { draft = ChatDrafts.shared.text(for: store.currentChat.id) }
        }
        // "New messages": the line is worked out when a chat opens, and where you left off is kept as you read.
        .onAppear { openNewLine(store.currentChat.id) }
        .onChange(of: store.currentChat.id) { old, new in
            LastSeen.shared.set(NewMessages.lastToRemember(store.messages(for: old)), for: old)
            openNewLine(new)
        }
        .onChange(of: NewMessages.key(chatID: store.currentChat.id, lastID: store.messages(for: store.currentChat.id).last?.id)) { old, new in
            switch NewMessages.change(from: old, to: new) {
            case .firstLoad: openNewLine(store.currentChat.id)
            case .more: if atBottom { rememberSeen() }
            case .otherChat: break
            }
        }
        .onChange(of: sentCount) { newFromID = nil }
        .onDisappear { rememberSeen() }
        .onReceive(SavedPrompts.shared.$insert) { request in
            // A saved prompt picked from the header goes into the message box; what you'd typed stays in front of it.
            guard let request, request.chatID == store.currentChatID else { return }
            SavedPrompts.shared.insert = nil
            let typed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
            draft = typed.isEmpty ? request.text : typed + "\n" + request.text
            inputFocused = true
        }
    }

    /// Puts the "New messages" line above what came in since you last had this chat open, then counts it all as seen.
    private func openNewLine(_ chatID: String) {
        let list = store.messages(for: chatID)
        newFromID = NewMessages.firstNew(list, lastSeen: LastSeen.shared.id(for: chatID))
        LastSeen.shared.set(NewMessages.lastToRemember(list), for: chatID)
    }

    private func rememberSeen() {
        let id = store.currentChat.id
        LastSeen.shared.set(NewMessages.lastToRemember(store.messages(for: id)), for: id)
    }

    private func emptyState(_ bot: Bot) -> some View {
        VStack(spacing: 10) {
            Sphere(bot: bot, size: 64, glow: 0.5)
            Text("Start a chat with \(bot.name)")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textBright)
            Text("Say hi, or give \(bot.name) something to work on.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private func inputBar(_ bot: Bot) -> some View {
        HStack(spacing: 8) {
            TextField("", text: $draft, prompt: Text("Message \(bot.name)...").foregroundStyle(Theme.muted), axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .focused($inputFocused)
                .submitLabel(.send)
                .onSubmit(sendDraft)
                .onChange(of: draft) { old, new in
                    // "Send with Return": a Return typed at the end sends instead of starting a new line.
                    if sendOnReturn, new.count == old.count + 1, new.hasSuffix("\n") {
                        draft = String(new.dropLast())
                        sendDraft()
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 11)
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.field))
            roundButton("phone.fill", label: "Call Chief") {
                store.showCall = true
            }
            Button(action: sendDraft) {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(canSend ? store.accent : Color.white.opacity(0.12)))
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.background.opacity(0.9))
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func sendDraft() {
        guard canSend else { return }
        store.send(draft)
        draft = ""
        sentCount += 1
    }

    private func roundButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Theme.field))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct ChatHeader: View {
    @EnvironmentObject private var store: SquallStore
    let bot: Bot
    @Binding var showLiveLog: Bool
    @State private var confirmClear = false

    var body: some View {
        HStack(spacing: 10) {
            Button {
                store.tab = .team
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Back to team")
            Sphere(bot: bot, size: 40)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(bot.name)
                        .font(.system(size: 16.5, weight: .bold))
                        .foregroundStyle(Theme.textBright)
                    StatusPill(status: bot.status)
                    DoneWatchBadge(bot: bot)
                }
                Text(bot.task)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button {
                if let job = store.work(for: bot.id) {
                    store.watch(job.id)
                } else {
                    showLiveLog.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Circle().fill(showLiveLog ? Theme.green : Theme.redSoft).frame(width: 7, height: 7)
                    Text("Live").font(.system(size: 12.5, weight: .bold))
                }
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(Capsule().fill(Theme.field))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(store.work(for: bot.id) != nil ? "Watch \(bot.name) work live" : "Show live work")
            SavedPromptsButton(bot: bot)
            StarredButton(bot: bot)
            RemindersButton(bot: bot)
            WorkTimerButton(bot: bot)
            ChatMoreMenu(bot: bot)
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }
}

/// iPad only: a column listing every chat, next to the open conversation.
private struct ChatList: View {
    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var drafts = ChatDrafts.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Chats")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Spacer()
                IconButton(systemName: "person.3", label: "New group") {
                    store.path.append(.group)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 8)
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(store.displayBots) { bot in
                        row(bot)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 12)
            }
            .scrollIndicators(.hidden)
        }
        .background(Color.black.opacity(0.18).ignoresSafeArea(edges: .top))
    }

    private func row(_ bot: Bot) -> some View {
        let isOn = bot.id == store.currentChatID
        let last = store.messages(for: bot.id).last
        return Button {
            store.openChat(bot.id)
        } label: {
            HStack(spacing: 12) {
                Sphere(bot: bot, size: 42, glow: isOn ? 0.6 : 0.3)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(bot.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textBright)
                            .lineLimit(1)
                        Circle().fill(bot.status.dot).frame(width: 7, height: 7)
                        Spacer(minLength: 0)
                        if let last {
                            Text(last.time)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                    Text(preview(last, bot: bot))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                if let unread = bot.unread, !isOn {
                    Text(unread)
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .frame(minWidth: 18, minHeight: 18)
                        .background(Capsule().fill(Theme.red))
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(isOn ? Color.white.opacity(0.1) : Color.clear)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isOn ? bot.color.opacity(0.6) : Color.clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Chat with \(bot.name)")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func preview(_ message: ChatMessage?, bot: Bot) -> String {
        if bot.id != store.currentChatID, let draft = drafts.preview(for: bot.id) { return "Draft: \(draft)" }
        guard let message, !message.text.isEmpty else { return bot.task }
        let words = Markdown.plain(message.text).replacingOccurrences(of: "\n", with: " ")
        return message.author == ChatMessage.meID ? "You: \(words)" : words
    }
}

/// Row of every bot so you can jump between chats.
private struct BotStrip: View {
    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var drafts = ChatDrafts.shared

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(store.displayBots) { bot in
                    let isOn = bot.id == store.currentChatID
                    Button {
                        store.openChat(bot.id)
                    } label: {
                        VStack(spacing: 4) {
                            Sphere(bot: bot, size: 36, glow: isOn ? 0.7 : 0.25)
                                .overlay(Circle().stroke(Color.white.opacity(isOn ? 0.9 : 0), lineWidth: 2).padding(-3))
                                .overlay(alignment: .topTrailing) {
                                    // Something typed here and not sent yet.
                                    if !isOn, drafts.preview(for: bot.id) != nil {
                                        Image(systemName: "pencil")
                                            .font(.system(size: 8, weight: .heavy))
                                            .foregroundStyle(Theme.darkInk)
                                            .frame(width: 15, height: 15)
                                            .background(Circle().fill(Theme.goldBright))
                                            .offset(x: 4, y: -4)
                                            .accessibilityLabel("Draft")
                                    }
                                }
                            Text(bot.name)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(isOn ? Theme.textBright : Theme.muted)
                                .lineLimit(1)
                        }
                        .frame(width: 52)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Chat with \(bot.name)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .scrollIndicators(.hidden)
    }
}

private struct LiveLogPanel: View {
    let bot: Bot

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if bot.log.isEmpty {
                Text("\(bot.name) isn't running anything right now.")
                    .font(Theme.mono(12))
                    .foregroundStyle(Theme.muted)
            } else {
                ForEach(bot.log.indices, id: \.self) { index in
                    Text(bot.log[index])
                        .font(Theme.mono(12))
                        .foregroundStyle(bot.log[index].hasPrefix("$") ? Theme.commandText : Theme.greenText)
                }
            }
            if bot.progress > 0 {
                ProgressView(value: bot.progress)
                    .tint(bot.color)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.cardBorder, lineWidth: 1))
    }
}

/// The pill over the bottom of a chat while you're scrolled up: jumps to the newest message, with a count of new ones.
private struct JumpToLatestButton: View {
    let count: Int
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 12.5, weight: .bold))
                Text(ChatDays.jumpLabel(count))
                    .font(.system(size: 13, weight: .semibold))
                    .contentTransition(.numericText())
            }
            .foregroundStyle(count > 0 ? .white : Theme.text)
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(
                Capsule().fill(count > 0 ? AnyShapeStyle(tint) : AnyShapeStyle(.ultraThinMaterial))
            )
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(.plain)
        .animation(.easeOut(duration: 0.2), value: count)
        .accessibilityLabel(count > 0 ? "Jump to \(ChatDays.jumpLabel(count))" : "Jump to the latest message")
    }
}

struct DayDivider: View {
    let text: String

    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Theme.cardBorder).frame(height: 1)
            Text(text)
                .font(.system(size: 11, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.muted)
            Rectangle().fill(Theme.cardBorder).frame(height: 1)
        }
        .padding(.vertical, 4)
    }
}

struct TypingRow: View {
    let bot: Bot
    var label = "Writing..."

    var body: some View {
        HStack(spacing: 8) {
            Sphere(bot: bot, size: 26)
            TypingDots()
            Text(label)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
            Spacer()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bot.name) is writing")
    }
}

/// One message in a chat.
struct MessageView: View {
    @EnvironmentObject private var store: SquallStore
    let message: ChatMessage
    /// Bot to use when the message has no author we know.
    let bot: Bot
    /// The chat it's in, for Summary under long messages. nil leaves that out.
    var chatID: String? = nil
    /// True when it follows another reply from the same teammate (see ChatGrouping): no picture or name, and closer up.
    var continued = false
    var onChip: (String) -> Void = { _ in }
    @AppStorage(Prefs.chatTextSize) private var textSize = 15.0
    @AppStorage(Prefs.showTimes) private var showTimes = true
    @ObservedObject private var starred = StarredMessages.shared

    var body: some View {
        switch message.kind {
        case .me:
            mine
                .swipeToReply(message, chatID: chatID, authorName: "You", tint: store.accent)
                .selectableMessage(message, chatID: chatID, tint: store.accent)
        case .bot:
            theirs
                .swipeToReply(message, chatID: chatID, authorName: author.name, tint: author.color)
                .selectableMessage(message, chatID: chatID, tint: author.color)
        case .error(let count):
            ErrorBubble(message: message, count: count)
        case .handoff(let fromName, let fromHex, let note):
            handoff(fromName: fromName, fromHex: fromHex, note: note)
        case .system:
            Text(message.text)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
    }

    private var author: Bot {
        store.bot(message.author) ?? bot
    }

    private var isStarred: Bool {
        guard let chatID else { return false }
        return starred.isStarred(chatID: chatID, messageID: message.id)
    }

    private var starMark: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Theme.goldBright)
            .accessibilityLabel("Starred")
    }

    private var mine: some View {
        HStack {
            Spacer(minLength: 50)
            VStack(alignment: .trailing, spacing: 3) {
                Text(ChatLinks.mine(message.text))
                    .font(.system(size: textSize))
                    .foregroundStyle(.white)
                    .tint(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(store.accent))
                    .messageMenu(message, chatID: chatID, authorName: "You")
                    .reactionBadge(chatID: chatID, messageID: message.id, tint: store.accent, trailing: true)
                if showTimes || isStarred {
                    HStack(spacing: 4) {
                        if isStarred { starMark }
                        if showTimes {
                            Text(message.time)
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.muted)
                        }
                    }
                }
            }
        }
    }

    private var theirs: some View {
        let who = author
        return HStack(alignment: .top, spacing: 8) {
            if continued {
                Color.clear.frame(width: 28, height: 1)
            } else {
                Sphere(bot: who, size: 28)
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    if !continued {
                        Text(who.name)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(who.nameColor)
                    }
                    if showTimes {
                        Text(message.time)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                    }
                    if isStarred { starMark }
                    if let chatID { ReadingMark(id: ReadAloud.id(chatID: chatID, messageID: message.id), tint: who.color) }
                }
                FoldedReply(id: "\(chatID ?? "")/\(message.id)", text: message.text + (message.text2.map { "\n\n" + $0 } ?? ""),
                            size: textSize, tint: who.color) {
                    VStack(alignment: .leading, spacing: 6) {
                        MarkdownText(text: message.text, size: textSize, tint: who.color)
                        if let text2 = message.text2 {
                            MarkdownText(text: text2, size: textSize, tint: who.color)
                        }
                    }
                }
                LinkCards(text: message.text + (message.text2.map { "\n\n" + $0 } ?? ""), tint: who.color)
                if let chatID, ChatSummaries.canSummarize(message) {
                    MessageSummary(chatID: chatID, messageID: message.id, tint: who.color)
                }
                if !message.chips.isEmpty {
                    FlowChips(chips: message.chips, tint: who.color, onTap: onChip)
                }
            }
            .padding(12)
            .glassCard(radius: 16, tint: who.hex, strength: 0.1)
            .messageMenu(message, chatID: chatID, authorName: who.name)
            .reactionBadge(chatID: chatID, messageID: message.id, tint: who.color, trailing: false)
            Spacer(minLength: 20)
        }
        .padding(.top, continued ? -6 : 0)
    }

    private func handoff(fromName: String, fromHex: UInt32, note: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Sphere(hex: fromHex, letter: String(fromName.prefix(1)).uppercased(), size: 24)
                Image(systemName: "arrow.right").font(.system(size: 12, weight: .bold)).foregroundStyle(Theme.goldText)
                Sphere(hex: Theme.goldHex, letter: "C", size: 24)
                Text("Handoff from \(fromName)")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.goldText)
                Spacer()
                Text(message.time).font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            MarkdownText(text: message.text, size: 14.5, tint: Theme.gold)
            if !note.isEmpty {
                Text("Note: \(note)")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.sub)
            }
        }
        .padding(12)
        .glassCard(radius: 16, tint: Theme.goldHex, strength: 0.16)
    }
}

private struct ErrorBubble: View {
    @EnvironmentObject private var store: SquallStore
    let message: ChatMessage
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.octagon.fill")
                    .foregroundStyle(Theme.redSoft)
                Text("Chief hit an error")
                    .font(.system(size: 13.5, weight: .bold))
                    .foregroundStyle(Theme.redText)
                if count > 1 {
                    Text("×\(count)")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Theme.red))
                }
                Spacer()
                Text(message.time).font(.system(size: 11)).foregroundStyle(Theme.muted)
            }
            Text(message.text)
                .font(Theme.mono(12))
                .foregroundStyle(Theme.redText.opacity(0.9))
                .textSelection(.enabled)
            if count > 1 {
                Text("Same error \(count) times, grouped")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
            HStack(spacing: 8) {
                Button(store.isBusy("chief.retry") ? "Retrying…" : "Try again") {
                    store.retryChief()
                }
                .buttonStyle(GhostButtonStyle(height: 36, expand: false, foreground: Theme.redText, border: Theme.red.opacity(0.5)))
                .disabled(store.isBusy("chief.retry"))
                if store.chiefNeedsUpdate {
                    Button("Update Claude Code") {
                        store.path.append(.settings)
                    }
                    .buttonStyle(GhostButtonStyle(height: 36, expand: false, foreground: Theme.goldText, border: Theme.gold.opacity(0.5)))
                }
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.red.opacity(0.1)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.red.opacity(0.35), lineWidth: 1))
    }
}

/// Reply chips that wrap onto more lines when needed.
struct FlowChips: View {
    let chips: [String]
    let tint: Color
    var onTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(chips, id: \.self) { chip in
                Button(chip) { onTap(chip) }
                    .buttonStyle(ChipButtonStyle(tint: tint, minHeight: 36))
            }
        }
    }
}
