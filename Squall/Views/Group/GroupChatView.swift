import SwiftUI

/// Make a group of bots, then chat with all of them at once.
struct GroupChatView: View {
    @EnvironmentObject private var store: SquallStore
    @AppStorage(Prefs.haptics) private var haptics = true

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
                        .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
                } else {
                    picker
                        .transition(.opacity)
                }
            }
            .readableColumn()
        }
        .navigationTitle(started ? groupName : "New group")
        .sensoryFeedback(.selection, trigger: members) { _, _ in haptics }
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

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

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
                GroupOrbit(chief: store.chief, members: memberBots, chiefLeads: chiefLeads)
                    .frame(maxWidth: .infinity)
                    .frame(height: 230)
                    .glassCard(radius: 24, tint: chiefLeads ? Theme.goldHex : store.accentHex, strength: 0.1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(members.count) bots in the group")
                SectionLabel(text: "Group name")
                DarkField(placeholder: "Group name", text: $groupName)
                HStack {
                    SectionLabel(text: "Who's in it")
                    Spacer()
                    Text(members.count < 2 ? "Pick at least 2" : "\(members.count) picked")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(members.count < 2 ? Theme.redText : Theme.greenText)
                        .contentTransition(.numericText(value: Double(members.count)))
                        .animation(.snappy, value: members.count)
                }
                if store.teammates.isEmpty {
                    Text("Add a teammate on the Team tab first. A group needs at least 2.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.sub)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(radius: 16)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 10) {
                        ForEach(store.teammates) { bot in
                            memberChip(bot)
                        }
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
            Button {
                start()
            } label: {
                HStack(spacing: 8) {
                    if creating {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: 14, weight: .bold))
                    }
                    Text(creating ? "Making the group…" : "Create group with \(members.count) members")
                }
            }
            .buttonStyle(FilledButtonStyle(fill: members.count >= 2 && !creating ? store.accent : Color.white.opacity(0.12)))
            .disabled(members.count < 2 || creating)
            .animation(.snappy, value: members.count >= 2)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.background.opacity(0.95))
        }
    }

    private func memberChip(_ bot: Bot) -> some View {
        let isOn = members.contains(bot.id)
        return Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                if isOn {
                    members.removeAll { $0 == bot.id }
                } else {
                    members.append(bot.id)
                }
            }
        } label: {
            VStack(spacing: 6) {
                Sphere(bot: bot, size: 42, glow: isOn ? 0.7 : 0.15)
                    .saturation(isOn ? 1 : 0.4)
                    .opacity(isOn ? 1 : 0.6)
                    .scaleEffect(isOn ? 1.08 : 1)
                    .overlay(alignment: .bottomTrailing) {
                        if isOn {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.green)
                                .background(Circle().fill(Theme.background))
                                .offset(x: 4, y: 4)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                Text(bot.name)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(isOn ? bot.nameColor : Theme.muted)
                    .lineLimit(1)
            }
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, minHeight: 84)
            .glassCard(radius: 16, tint: isOn ? bot.hex : nil, strength: 0.2)
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(bot.color.opacity(isOn ? 0.6 : 0), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(bot.name)
        .accessibilityAddTraits(isOn ? [.isButton, .isSelected] : .isButton)
    }

    private func existingGroupRow(_ group: BotGroup) -> some View {
        let bots = group.members.compactMap { store.bot($0) }
        let tint = bots.first?.hex ?? store.accentHex
        let busy = bots.filter { $0.status == .working }.count
        return Button {
            open(group)
        } label: {
            HStack(spacing: 12) {
                HStack(spacing: -10) {
                    ForEach(bots.prefix(4)) { bot in
                        Sphere(bot: bot, size: 30)
                            .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                    }
                    if bots.count > 4 {
                        Text("+\(bots.count - 4)")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.text)
                            .frame(width: 30, height: 30)
                            .background(Circle().fill(Theme.field))
                            .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                        .lineLimit(1)
                    HStack(spacing: 5) {
                        if busy > 0 {
                            LiveDot()
                            Text("\(busy) working")
                                .foregroundStyle(Theme.greenText)
                        } else {
                            Text("\(bots.count) bots\(group.chiefLeads ? " · Chief leads" : "")")
                                .foregroundStyle(Theme.sub)
                        }
                    }
                    .font(.system(size: 12))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(12)
            .glassCard(radius: 16, tint: tint, strength: 0.12)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func open(_ group: BotGroup) {
        groupName = group.name
        members = group.members
        chiefLeads = group.chiefLeads
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { groupID = group.id }
    }

    private func start() {
        guard members.count >= 2, !creating else { return }
        if groupName.trimmingCharacters(in: .whitespaces).isEmpty { groupName = "Build crew" }
        let name = groupName.trimmingCharacters(in: .whitespaces)
        Task {
            guard let id = await store.createGroup(name: name, members: members, chiefLeads: chiefLeads) else { return }
            groupName = name
            withAnimation(.spring(response: 0.45, dampingFraction: 0.85)) { groupID = id }
        }
    }

    // MARK: Chat

    private var chat: some View {
        VStack(spacing: 0) {
            header
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if messages.isEmpty && typing == nil {
                            emptyChat
                        } else {
                            DayDivider(text: "TODAY")
                        }
                        ForEach(messages) { message in
                            MessageView(message: message, bot: store.chief) { chip in
                                send(chip)
                            }
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                        if let typing, let bot = store.bot(typing) {
                            TypingRow(bot: bot, label: "\(bot.name) is writing...")
                        }
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(16)
                    .animation(.spring(response: 0.4, dampingFraction: 0.85), value: messages.count)
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

    private var header: some View {
        let busy = memberBots.filter { $0.status == .working }.count
        return HStack(spacing: 12) {
            HStack(spacing: -10) {
                if chiefLeads {
                    Sphere(bot: store.chief, size: 34, glow: 0.5)
                        .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                }
                ForEach(memberBots) { bot in
                    Sphere(bot: bot, size: 34)
                        .overlay(Circle().stroke(Theme.background, lineWidth: 2))
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(groupName)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                    .lineLimit(1)
                HStack(spacing: 5) {
                    if busy > 0 {
                        LiveDot()
                        Text("\(busy) working")
                            .foregroundStyle(Theme.greenText)
                        Text("·").foregroundStyle(Theme.muted)
                    }
                    Text("\(members.count + (chiefLeads ? 1 : 0)) bots\(chiefLeads ? " · Chief leads" : "")")
                        .foregroundStyle(Theme.sub)
                }
                .font(.system(size: 12))
                .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .glassCard(radius: 18, tint: chiefLeads ? Theme.goldHex : (memberBots.first?.hex ?? store.accentHex), strength: 0.12)
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var emptyChat: some View {
        VStack(spacing: 12) {
            GroupOrbit(chief: store.chief, members: memberBots, chiefLeads: chiefLeads, ringSize: 120)
                .frame(height: 160)
            Text("Say hi to \(groupName)")
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.textBright)
                .multilineTextAlignment(.center)
            Text("Everyone here reads your message. Tap a name below to talk to one bot.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 24)
        .padding(.horizontal, 12)
        .frame(maxWidth: .infinity)
    }

    private var mentionBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                Button("@Everyone") { addMention("Everyone") }
                    .buttonStyle(ChipButtonStyle(tint: store.accent, minHeight: 32))
                ForEach(memberBots) { bot in
                    Button {
                        addMention(bot.name)
                    } label: {
                        HStack(spacing: 5) {
                            Circle().fill(bot.color).frame(width: 8, height: 8)
                            Text("@\(bot.name)")
                        }
                    }
                    .buttonStyle(ChipButtonStyle(tint: bot.color, minHeight: 32))
                    .accessibilityLabel("Mention \(bot.name)")
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
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.field))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(canSend ? store.accent.opacity(0.45) : Color.white.opacity(0.08), lineWidth: 1)
                )
            Button {
                send(draft)
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle().fill(canSend ? AnyShapeStyle(LinearGradient(colors: [store.accent, store.accent.opacity(0.7)],
                                                                             startPoint: .top, endPoint: .bottom))
                                              : AnyShapeStyle(Color.white.opacity(0.12)))
                    )
                    .shadow(color: canSend ? store.accent.opacity(0.5) : .clear, radius: 8, y: 2)
                    .scaleEffect(canSend ? 1 : 0.92)
            }
            .buttonStyle(.plain)
            .disabled(!canSend)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: canSend)
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

/// Chief (or a team icon) in the middle, with the group's bots slowly circling
/// on a dotted ring. Holds still when Reduce Motion is on.
private struct GroupOrbit: View {
    let chief: Bot
    let members: [Bot]
    let chiefLeads: Bool
    var ringSize: CGFloat = 170
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if reduceMotion {
            orbit(turn: 0)
        } else {
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { context in
                orbit(turn: context.date.timeIntervalSinceReferenceDate * 0.18)
            }
        }
    }

    private func orbit(turn: Double) -> some View {
        let radius = Double(ringSize) / 2
        let member: CGFloat = ringSize >= 150 ? 40 : 30
        let center: CGFloat = ringSize >= 150 ? 60 : 44
        return ZStack {
            Circle()
                .stroke(Color.white.opacity(0.06), lineWidth: 18)
                .frame(width: ringSize, height: ringSize)
            Circle()
                .stroke(Color.white.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 6]))
                .frame(width: ringSize, height: ringSize)
                .rotationEffect(.radians(-turn * 0.6))
            if chiefLeads {
                Sphere(bot: chief, size: center, glow: 0.7)
                    .scaleEffect(1 + 0.03 * sin(turn * 8))
                    .transition(.scale.combined(with: .opacity))
            } else {
                Image(systemName: "person.3.fill")
                    .font(.system(size: center * 0.42))
                    .foregroundStyle(Theme.sub)
                    .frame(width: center, height: center)
                    .background(Circle().fill(Color.white.opacity(0.06)))
                    .transition(.scale.combined(with: .opacity))
            }
            ForEach(Array(members.enumerated()), id: \.element.id) { index, bot in
                let angle = Double(index) / Double(max(members.count, 1)) * 2 * Double.pi - Double.pi / 2 + turn
                Sphere(bot: bot, size: member, glow: 0.4)
                    .offset(x: CGFloat(cos(angle) * radius), y: CGFloat(sin(angle) * radius))
                    .transition(.scale.combined(with: .opacity))
            }
            if members.isEmpty {
                Text("Pick bots below")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(Theme.muted)
                    .offset(y: CGFloat(radius) + 18)
            }
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: members.map(\.id))
        .animation(.spring(response: 0.45, dampingFraction: 0.75), value: chiefLeads)
    }
}

/// A small green dot that softly pulses while bots are working.
private struct LiveDot: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var on = false

    var body: some View {
        Circle()
            .fill(Theme.green)
            .frame(width: 6, height: 6)
            .background(
                Circle()
                    .fill(Theme.green.opacity(0.4))
                    .scaleEffect(on ? 2.2 : 1)
                    .opacity(on ? 0 : 1)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { on = true }
            }
            .accessibilityHidden(true)
    }
}
