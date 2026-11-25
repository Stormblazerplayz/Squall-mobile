import SwiftUI

/// Settings > Your team: every teammate, with a crown on each chief. Tap one to rename it, make it a chief or remove it.
struct TeamManageSection: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    @ObservedObject private var feed = HistoryFeed.shared
    @State private var picked: PickedBot?

    private struct PickedBot: Identifiable {
        let id: String
    }

    var body: some View {
        let info = TeamManage.info(from: feed.latest)
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text(info.map { "\($0.size) of \($0.max) teammates" } ?? "\(store.bots.count) teammates")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Theme.sub)
                Spacer()
                if let info {
                    Text(info.chiefs == 1 ? "1 chief" : "\(info.chiefs) chiefs")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.goldText)
                }
            }
            .padding(.bottom, 8)
            ForEach(Array(store.bots.enumerated()), id: \.element.id) { index, bot in
                if index > 0 {
                    Divider().overlay(Theme.cardBorder)
                }
                Button {
                    picked = PickedBot(id: bot.id)
                } label: {
                    HStack(spacing: 12) {
                        Sphere(bot: bot, size: 34, glow: 0.2)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(bot.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(Theme.textBright)
                                if info?.isChief(bot.id) ?? (bot.id == Bot.chiefID) {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 11))
                                        .foregroundColor(Theme.gold)
                                        .accessibilityLabel("Chief")
                                }
                            }
                            Text([bot.role, info?.projectOf[bot.id]].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.system(size: 12.5))
                                .foregroundColor(Theme.sub)
                                .lineLimit(1)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(Theme.muted)
                    }
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            if info?.manage != true, store.isConnected {
                Text("Update Squall on your computer to rename, promote or remove teammates from here.")
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.muted)
                    .padding(.top, 8)
            }
        }
        .padding(14)
        .glassCard(radius: 18)
        .sheet(item: $picked) { pick in
            ManageTeammateSheet(botID: pick.id)
                .lockCover()
                .environmentObject(store)
                .environmentObject(lock)
        }
    }
}

/// Rename a teammate, make it a chief or take that away, or remove it from the team.
struct ManageTeammateSheet: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var feed = HistoryFeed.shared
    let botID: String

    @State private var newName = ""
    @State private var askRemove = false
    @State private var working = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()
                if let bot = store.bot(botID) {
                    content(bot, info: TeamManage.info(from: feed.latest))
                } else {
                    VStack(spacing: 10) {
                        Image(systemName: "person.crop.circle.badge.xmark")
                            .font(.system(size: 30))
                            .foregroundColor(Theme.muted)
                        Text("This teammate isn't on the team any more.")
                            .font(.system(size: 15))
                            .foregroundColor(Theme.sub)
                    }
                }
            }
            .navigationTitle("Manage teammate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private func content(_ bot: Bot, info: TeamManage.Info?) -> some View {
        let canManage = info?.manage == true && store.isConnected
        let isChief = info?.isChief(bot.id) ?? (bot.id == Bot.chiefID)
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero(bot, isChief: isChief)
                if !canManage {
                    Text(store.isConnected
                         ? "Update Squall on your computer to manage teammates from the phone."
                         : "Connect to your computer to manage teammates.")
                        .font(.system(size: 13.5))
                        .foregroundColor(Theme.sub)
                        .padding(14)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(radius: 16)
                }
                renameCard(bot)
                    .disabled(!canManage || working)
                    .opacity(canManage ? 1 : 0.5)
                if let info {
                    chiefCard(bot, isChief: isChief, info: info)
                        .disabled(!canManage || working)
                        .opacity(canManage ? 1 : 0.5)
                    projectCard(bot, info: info)
                        .disabled(!canManage || working)
                        .opacity(canManage ? 1 : 0.5)
                    removeCard(bot, isChief: isChief, info: info)
                        .disabled(!canManage || working)
                        .opacity(canManage ? 1 : 0.5)
                }
            }
            .padding(18)
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .onAppear { if newName.isEmpty { newName = bot.name } }
        .confirmationDialog("Remove \(bot.name) from the team?", isPresented: $askRemove, titleVisibility: .visible) {
            Button("Remove \(bot.name)", role: .destructive) { remove(bot) }
            Button("Keep", role: .cancel) {}
        } message: {
            Text("Its chats and routines go too. Its folder and files stay on the computer.")
        }
    }

    private func hero(_ bot: Bot, isChief: Bool) -> some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topTrailing) {
                Sphere(bot: bot, size: 76, glow: 0.45)
                if isChief {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 15))
                        .foregroundColor(Theme.goldBright)
                        .padding(6)
                        .background(Circle().fill(Theme.background))
                        .offset(x: 6, y: -6)
                }
            }
            Text(bot.name)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(Theme.textBright)
            Text(isChief ? "Chief · \(bot.role)" : bot.role)
                .font(.system(size: 13.5))
                .foregroundColor(Theme.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .glassCard(radius: 22, tint: bot.hex, strength: 0.16)
    }

    private func renameCard(_ bot: Bot) -> some View {
        let others = store.bots.map(\.name)
        let problem = TeamManage.nameProblem(newName, current: bot.name, others: others)
        let changed = newName.trimmingCharacters(in: .whitespacesAndNewlines) != bot.name
        return VStack(alignment: .leading, spacing: 10) {
            label("Name")
            HStack(spacing: 8) {
                TextField("", text: $newName, prompt: Text("Name").foregroundColor(Theme.muted))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(Theme.text)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .focused($nameFocused)
                    .submitLabel(.done)
                    .onSubmit { if changed, problem == nil { rename(bot) } }
                    .padding(.horizontal, 12)
                    .frame(height: 44)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
                Button(working ? "Saving..." : "Rename") { rename(bot) }
                    .buttonStyle(FilledButtonStyle(fill: store.accent, height: 44))
                    .frame(width: 110)
                    .disabled(!changed || problem != nil || working)
                    .opacity(changed && problem == nil ? 1 : 0.5)
            }
            if changed, let problem {
                Text(problem)
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.redText)
            } else {
                Text("Its chats, routines and history move to the new name.")
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.muted)
            }
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private func chiefCard(_ bot: Bot, isChief: Bool, info: TeamManage.Info) -> some View {
        let block = TeamManage.chiefBlock(isChief: isChief, info: info)
        return VStack(alignment: .leading, spacing: 10) {
            label("Chief")
            SwitchRow(
                title: "Chief",
                subtitle: block ?? "Chiefs lead the group chats they're in and hand out work. \(info.chiefs) of \(info.maxChiefs) now.",
                isOn: Binding(get: { isChief }, set: { setChief(bot, on: $0) }),
                tint: Theme.gold
            )
            .disabled(block != nil)
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private func projectCard(_ bot: Bot, info: TeamManage.Info) -> some View {
        let current = info.projectOf[bot.id]
        let choices = TeamManage.projectChoices(current: current, info: info)
        return VStack(alignment: .leading, spacing: 10) {
            label("Project")
            Menu {
                Button {
                    setProject(bot, "")
                } label: {
                    if current == nil { Label("All of Projects", systemImage: "checkmark") } else { Text("All of Projects") }
                }
                if !choices.isEmpty {
                    Divider()
                }
                ForEach(choices, id: \.self) { name in
                    Button {
                        setProject(bot, name)
                    } label: {
                        if current == name { Label(name, systemImage: "checkmark") } else { Text(name) }
                    }
                    .disabled(info.projects?.contains(name) != true)
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .foregroundColor(store.accent)
                    Text(current ?? "All of Projects")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.muted)
                }
                .padding(.horizontal, 12)
                .frame(height: 44)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
            }
            Text(info.projects == nil
                 ? "Your computer is still reading its projects."
                 : "\(bot.name) works in this folder from its next run, in a new conversation there.")
                .font(.system(size: 12.5))
                .foregroundColor(Theme.muted)
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private func removeCard(_ bot: Bot, isChief: Bool, info: TeamManage.Info) -> some View {
        let block = TeamManage.removeBlock(isChief: isChief, info: info)
        return VStack(alignment: .leading, spacing: 10) {
            label("Remove")
            Button {
                askRemove = true
            } label: {
                Label("Remove \(bot.name)", systemImage: "person.fill.xmark")
            }
            .buttonStyle(GhostButtonStyle(height: 44, foreground: Theme.redText, border: Theme.red.opacity(0.4)))
            .disabled(block != nil)
            .opacity(block == nil ? 1 : 0.5)
            Text(block ?? "Takes it off the team with its chats and routines. Its folder stays on the computer.")
                .font(.system(size: 12.5))
                .foregroundColor(block == nil ? Theme.muted : Theme.redText)
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private func label(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 11.5, weight: .bold))
            .tracking(1)
            .foregroundColor(Theme.label)
    }

    // MARK: - Doing it

    private func rename(_ bot: Bot) {
        guard !working, TeamManage.nameProblem(newName, current: bot.name, others: store.bots.map(\.name)) == nil else { return }
        nameFocused = false
        working = true
        Task {
            let reply = await store.perform(TeamManage.renameAction(botID: bot.id, name: newName))
            working = false
            if reply != nil {
                store.showToast("Renamed to \(newName.trimmingCharacters(in: .whitespacesAndNewlines)).")
                dismiss()
            }
        }
    }

    private func setChief(_ bot: Bot, on: Bool) {
        guard !working else { return }
        working = true
        Task {
            await store.perform(TeamManage.chiefAction(botID: bot.id, on: on))
            working = false
        }
    }

    private func setProject(_ bot: Bot, _ project: String) {
        guard !working else { return }
        working = true
        Task {
            let reply = await store.perform(TeamManage.projectAction(botID: bot.id, project: project))
            working = false
            if reply != nil {
                store.showToast(project.isEmpty ? "\(bot.name) works across all of Projects." : "\(bot.name) now works in \(project).")
            }
        }
    }

    private func remove(_ bot: Bot) {
        guard !working else { return }
        working = true
        let name = bot.name
        Task {
            let reply = await store.perform(TeamManage.removeAction(botID: bot.id, confirm: name))
            working = false
            if reply != nil {
                store.showToast("\(name) left the team.")
                dismiss()
            }
        }
    }
}
