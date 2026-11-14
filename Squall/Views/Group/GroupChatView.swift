import SwiftUI

/// Make a group of bots, then chat with all of them at once.
struct GroupChatView: View {
    @EnvironmentObject private var store: SquallStore

    @State private var started = false
    @State private var groupName = "Build crew"
    @State private var members: [String] = ["barry", "fox", "chip"]
    @State private var chiefLeads = true

    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var typing: String?
    @State private var queue: [String] = []
    @State private var used: [String: Int] = [:]
    @State private var replyRun = 0

    static let lines: [String: [String]] = [
        "barry": ["On it. I'll start with the code and post what I find.", "Pushed nothing yet. I will ask you before I do."],
        "fox": ["I can sketch three ideas and pin them here.", "Art is my part. Give me a style and I will go."],
        "chip": ["I'll keep notes so nothing gets lost.", "Saved that to your notes under this group."],
        "laptop": ["I can test it on Windows and tell you what breaks.", "Running it now. Results soon."],
        "obsidian": ["I will write the docs once the plan is set.", "Docs draft is started."],
        "starx": ["I can research how other games did this.", "Found a few good examples. Want a summary?"],
        "coolyoda": ["Review the code I will, when ready it is.", "Spotted two bugs, I have."],
        "sss": ["I'll take whatever is left over.", "Free now. Hand me something."]
    ]

    var body: some View {
        ZStack {
            GlowBackground()
            if started {
                chat
            } else {
                picker
            }
        }
        .navigationTitle(started ? groupName : "New group")
    }

    private var memberBots: [Bot] {
        members.compactMap { store.bot($0) }
    }

    // MARK: Pick members

    private var picker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                orbit
                SectionLabel(text: "Group name")
                DarkField(placeholder: "Group name", text: $groupName)
                HStack {
                    SectionLabel(text: "Who's in it")
                    Spacer()
                    Text(members.count < 2 ? "Pick at least 2" : "\(members.count) picked")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(members.count < 2 ? Theme.redText : Theme.sub)
                }
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: 10)], spacing: 10) {
                    ForEach(store.teammates) { bot in
                        memberChip(bot)
                    }
                }
                SwitchRow(title: "Chief leads this group", subtitle: "Chief splits the work and keeps everyone on track", isOn: $chiefLeads, tint: Theme.gold)
                    .padding(14)
                    .glassCard(radius: 18, tint: Theme.goldHex, strength: 0.1)
            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            Button("Create group with \(members.count) members") { start() }
                .buttonStyle(FilledButtonStyle(fill: members.count >= 2 ? store.accent : Color.white.opacity(0.12)))
                .disabled(members.count < 2)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.background.opacity(0.95))
        }
    }

    private var orbit: some View {
        let shown = memberBots
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.1), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                .frame(width: 170, height: 170)
            if chiefLeads {
                Sphere(bot: store.chief, size: 58, glow: 0.6)
            } else {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.sub)
            }
            ForEach(shown.indices, id: \.self) { index in
                let angle = Double(index) / Double(max(shown.count, 1)) * 2 * Double.pi - Double.pi / 2
                Sphere(bot: shown[index], size: 38)
                    .offset(x: cos(angle) * 85, y: sin(angle) * 85)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 210)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: members)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(members.count) bots in the group")
    }

    private func memberChip(_ bot: Bot) -> some View {
        let isOn = members.contains(bot.id)
        return Button {
            if isOn {
                members.removeAll { $0 == bot.id }
            } else {
                members.append(bot.id)
            }
        } label: {
            VStack(spacing: 5) {
                Sphere(bot: bot, size: 40, glow: isOn ? 0.7 : 0.15)
                    .opacity(isOn ? 1 : 0.55)
                    .overlay(alignment: .bottomTrailing) {
                        if isOn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.green)
                                .background(Circle().fill(Theme.background))
                                .offset(x: 3, y: 3)
                        }
                    }
                Text(bot.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isOn ? Theme.textBright : Theme.muted)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 76)
            .glassCard(radius: 14, tint: isOn ? bot.hex : nil, strength: 0.16)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(bot.name)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func start() {
        guard members.count >= 2 else { return }
        if groupName.trimmingCharacters(in: .whitespaces).isEmpty { groupName = "Build crew" }
        let names = memberBots.map(\.name)
        var first = [
            ChatMessage(kind: .system, author: "system", text: "You made \(groupName) with \(names.joined(separator: ", "))", time: TimeText.now())
        ]
        if chiefLeads {
            first.append(ChatMessage(kind: .bot, author: Bot.chiefID, text: "Hi team. \(names.joined(separator: ", ")) are here. Tell us the goal and I will split it up.", time: TimeText.now()))
        }
        messages = first
        withAnimation { started = true }
    }

    // MARK: Chat

    private var chat: some View {
        VStack(spacing: 0) {
            stackedAvatars
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        DayDivider(text: "TODAY")
                        ForEach(messages) { message in
                            MessageView(message: message, bot: store.chief) { chip in
                                send(chip)
                            }
                        }
                        if let typing, let bot = store.bot(typing) {
                            TypingRow(bot: bot, label: "\(bot.name) is writing...")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(16)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: messages.count) {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
                .onChange(of: typing) {
                    withAnimation { proxy.scrollTo("bottom", anchor: .bottom) }
                }
            }
            mentionBar
            inputBar
        }
    }

    private var stackedAvatars: some View {
        HStack(spacing: 10) {
            HStack(spacing: -10) {
                if chiefLeads {
                    Sphere(bot: store.chief, size: 30)
                }
                ForEach(memberBots) { bot in
                    Sphere(bot: bot, size: 30)
                        .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(groupName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Text("\(members.count + (chiefLeads ? 1 : 0)) bots\(chiefLeads ? " · Chief leads" : "")")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.sub)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var mentionBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button("@Everyone") { addMention("Everyone") }
                    .buttonStyle(ChipButtonStyle(tint: store.accent, minHeight: 32))
                ForEach(memberBots) { bot in
                    Button("@\(bot.name)") { addMention(bot.name) }
                        .buttonStyle(ChipButtonStyle(tint: bot.color, minHeight: 32))
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.vertical, 6)
    }

    private var inputBar: some View {
        HStack(spacing: 8) {
            TextField("", text: $draft, prompt: Text("Message \(groupName)...").foregroundStyle(Theme.muted))
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .submitLabel(.send)
                .onSubmit { send(draft) }
                .padding(.horizontal, 14)
                .frame(height: 42)
                .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(Theme.field))
            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(Circle().fill(store.accent))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Send")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.background.opacity(0.9))
    }

    private func addMention(_ name: String) {
        let tag = "@\(name) "
        if draft.isEmpty || draft.hasSuffix(" ") {
            draft += tag
        } else {
            draft += " " + tag
        }
    }

    private func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        messages.append(ChatMessage(kind: .me, author: ChatMessage.meID, text: text, time: TimeText.now()))
        draft = ""

        let lower = text.lowercased()
        var who = memberBots.filter { lower.contains("@" + $0.name.lowercased()) }.map(\.id)
        if who.isEmpty || lower.contains("@everyone") {
            who = (chiefLeads ? [Bot.chiefID] : []) + Array(members.prefix(2))
        }
        typing = who.first
        queue = Array(who.dropFirst())
        replyRun += 1
        let run = replyRun
        Task { @MainActor in
            await runReplies(run)
        }
    }

    /// Bots answer one after another. A newer message starts a new run and this one stops.
    private func runReplies(_ run: Int) async {
        while let id = typing {
            try? await Task.sleep(for: .seconds(1.3))
            guard replyRun == run, typing == id else { return }
            messages.append(ChatMessage(kind: .bot, author: id, text: reply(for: id), time: TimeText.now()))
            if queue.isEmpty {
                typing = nil
            } else {
                typing = queue.removeFirst()
            }
        }
    }

    private func reply(for id: String) -> String {
        let turn = used[id, default: 0]
        used[id] = turn + 1
        if id == Bot.chiefID {
            let others = memberBots.prefix(2).map(\.name).joined(separator: " and ")
            let options = [
                "Here is the plan. \(others) start now, and I will check their work before it reaches you.",
                "Got it. I will post a summary here when everyone is done."
            ]
            return options[turn % options.count]
        }
        let options = Self.lines[id] ?? ["On it."]
        return options[turn % options.count]
    }
}
