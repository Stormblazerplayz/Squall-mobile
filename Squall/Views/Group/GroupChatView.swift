import SwiftUI

/// Make a group of bots, then chat with all of them at once.
struct GroupChatView: View {
    @EnvironmentObject private var store: SquallStore

    /// The group chat on the computer, once it's made or picked.
    @State private var groupID: String?
    @State private var groupName = "Build crew"
    @State private var members: [String] = []
    @State private var chiefLeads = true
    @State private var draft = ""

    private var started: Bool { groupID != nil }

    var body: some View {
        ZStack {
            GlowBackground()
            Group {
                if started {
                    chat
                } else {
                    picker
                }
            }
            .readableColumn()
        }
        .navigationTitle(started ? groupName : "New group")
    }

    private var memberBots: [Bot] {
        members.compactMap { store.bot($0) }
    }

    private var messages: [ChatMessage] {
        guard let groupID else { return [] }
        return store.messages(for: groupID)
    }

    private var typing: String? {
        guard let id = store.typingBotID, id == Bot.chiefID || members.contains(id) else { return nil }
        return id
    }

    private var creating: Bool { store.isBusy("group.create") }

    // MARK: Pick members

    private var picker: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if !store.groups.isEmpty {
                    SectionLabel(text: "Your groups")
                    VStack(spacing: 8) {
                        ForEach(store.groups) { group in
                            existingGroupRow(group)
                        }
                    }
                    SectionLabel(text: "Make a new one")
                }
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
            Button(creating ? "Making the group…" : "Create group with \(members.count) members") { start() }
                .buttonStyle(FilledButtonStyle(fill: members.count >= 2 && !creating ? store.accent : Color.white.opacity(0.12)))
                .disabled(members.count < 2 || creating)
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

    private func existingGroupRow(_ group: BotGroup) -> some View {
        Button {
            open(group)
        } label: {
            HStack(spacing: 10) {
                HStack(spacing: -10) {
                    ForEach(group.members.prefix(4).compactMap { store.bot($0) }) { bot in
                        Sphere(bot: bot, size: 28)
                            .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                    }
                }
                Text(group.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.textBright)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(12)
            .glassCard(radius: 16)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func open(_ group: BotGroup) {
        groupName = group.name
        members = group.members
        chiefLeads = group.chiefLeads
        withAnimation { groupID = group.id }
    }

    private func start() {
        guard members.count >= 2, !creating else { return }
        if groupName.trimmingCharacters(in: .whitespaces).isEmpty { groupName = "Build crew" }
        let name = groupName.trimmingCharacters(in: .whitespaces)
        Task {
            guard let id = await store.createGroup(name: name, members: members, chiefLeads: chiefLeads) else { return }
            groupName = name
            withAnimation { groupID = id }
        }
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
            MentionPickerBar(draft: $draft, bots: memberBots, tint: store.accent)
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
        guard !text.isEmpty, let groupID else { return }
        store.send(text, to: groupID)
        draft = ""
    }
}
