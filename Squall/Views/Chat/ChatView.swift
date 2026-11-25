import SwiftUI

/// One-on-one chat with a bot.
struct ChatView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var draft = ""
    @State private var sentCount = 0
    @AppStorage(Prefs.showTyping) private var showTyping = true
    @AppStorage(Prefs.sendOnReturn) private var sendOnReturn = false
    @AppStorage(Prefs.haptics) private var haptics = true
    @State private var showLiveLog = false
    /// A message Search opened the chat at, lit up for a moment.
    @State private var flashID: String?
    @FocusState private var inputFocused: Bool

    var body: some View {
        let bot = store.currentChat
        let list = store.messages(for: bot.id)
        let isWide = sizeClass == .regular
        ZStack {
            GlowBackground(topHex: bot.hex)
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
                                DayDivider(text: "TODAY")
                                if list.isEmpty && store.typingBotID != bot.id {
                                    emptyState(bot)
                                }
                                ForEach(list) { message in
                                    MessageView(message: message, bot: bot) { chip in
                                        store.send(chip)
                                    }
                                    .background(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(store.accent.opacity(flashID == message.id ? 0.2 : 0))
                                            .padding(-6)
                                    )
                                    .animation(.easeOut(duration: 0.5), value: flashID)
                                }
                                if showTyping && store.typingBotID == bot.id {
                                    TypingRow(bot: bot)
                                }
                                Color.clear.frame(height: 1).id("bottom")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .readableColumn(780)
                        }
                        .scrollIndicators(.hidden)
                        .scrollDismissesKeyboard(.interactively)
                        .onAppear {
                            proxy.scrollTo("bottom", anchor: .bottom)
                            jumpIfAsked(proxy, botID: bot.id)
                        }
                        .onReceive(SearchJump.shared.$target) { _ in
                            jumpIfAsked(proxy, botID: bot.id)
                        }
                        .onChange(of: list.count) {
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                        .onChange(of: store.typingBotID) {
                            withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                        }
                        .onChange(of: bot.id) {
                            proxy.scrollTo("bottom", anchor: .bottom)
                            jumpIfAsked(proxy, botID: bot.id)
                        }
                    }
                    inputBar(bot)
                }
                .readableColumn(isWide ? .infinity : Theme.readableWidth)
            }
        }
        .animation(.easeOut(duration: 0.2), value: showLiveLog)
        .sensoryFeedback(.impact(weight: .light), trigger: sentCount) { _, _ in haptics }
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

    /// Scrolls to the message a search result was tapped for, and lights it up for a moment.
    private func jumpIfAsked(_ proxy: ScrollViewProxy, botID: String) {
        guard let target = SearchJump.shared.target, target.chatID == botID else { return }
        SearchJump.shared.target = nil
        // After the chat's own scroll to the bottom, once the messages are laid out.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            withAnimation(.easeInOut(duration: 0.35)) {
                proxy.scrollTo(target.messageID, anchor: .center)
            }
            flashID = target.messageID
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                if flashID == target.messageID { flashID = nil }
            }
        }
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
    @EnvironmentObject private var lock: AppLock
    let bot: Bot
    @Binding var showLiveLog: Bool
    @State private var confirmClear = false
    @State private var showSearch = false

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
                }
                Text(bot.task)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            Button {
                showSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.sub)
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
            .accessibilityLabel("Search chats")
            .sheet(isPresented: $showSearch) {
                ChatSearchView()
                    .lockCover()
                    .environmentObject(store)
                    .environmentObject(lock)
            }
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
            Button {
                confirmClear = true
            } label: {
                Image(systemName: "trash")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.sub)
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Clear chat")
            .confirmationDialog("Clear this chat?", isPresented: $confirmClear, titleVisibility: .visible) {
                Button("Clear chat with \(bot.name)", role: .destructive) {
                    store.clearChat(bot.id)
                }
            } message: {
                Text("\(bot.name) keeps its memory. Only the messages go away.")
            }
        }
        .padding(.horizontal, 10)
        .padding(.top, 4)
    }
}

/// iPad only: a column listing every chat, next to the open conversation.
private struct ChatList: View {
    @EnvironmentObject private var store: SquallStore

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
        guard let message, !message.text.isEmpty else { return bot.task }
        return message.author == ChatMessage.meID ? "You: \(message.text)" : message.text
    }
}

/// Row of every bot so you can jump between chats.
private struct BotStrip: View {
    @EnvironmentObject private var store: SquallStore

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
    var onChip: (String) -> Void = { _ in }
    @AppStorage(Prefs.chatTextSize) private var textSize = 15.0
    @AppStorage(Prefs.showTimes) private var showTimes = true

    var body: some View {
        switch message.kind {
        case .me:
            mine
        case .bot:
            theirs
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

    private var mine: some View {
        HStack {
            Spacer(minLength: 50)
            VStack(alignment: .trailing, spacing: 3) {
                Text(message.text)
                    .font(.system(size: textSize))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(store.accent))
                if showTimes {
                    Text(message.time)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.muted)
                }
            }
        }
    }

    private var theirs: some View {
        let who = author
        return HStack(alignment: .top, spacing: 8) {
            Sphere(bot: who, size: 28)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Text(who.name)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(who.nameColor)
                    if showTimes {
                        Text(message.time)
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.muted)
                    }
                }
                Text(message.text)
                    .font(.system(size: textSize))
                    .foregroundStyle(Theme.text)
                if let text2 = message.text2 {
                    Text(text2)
                        .font(.system(size: textSize))
                        .foregroundStyle(Theme.text)
                }
                if !message.chips.isEmpty {
                    FlowChips(chips: message.chips, tint: who.color, onTap: onChip)
                }
            }
            .padding(12)
            .glassCard(radius: 16, tint: who.hex, strength: 0.1)
            Spacer(minLength: 20)
        }
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
            Text(message.text)
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.text)
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
