import SwiftUI
import UIKit

/// Squall's shared To do list on the phone: the same list as the To do pane on the computer,
/// which you, your live sessions and the bots all keep. Add to it, tick things off, or give one to a bot.
struct TodoView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(Prefs.haptics) private var haptics = true
    @State private var draft = ""
    @State private var giveTo: String?
    @State private var showDone = true
    @State private var confirmClear = false
    @State private var ticks = 0
    @FocusState private var typing: Bool

    var body: some View {
        ZStack {
            GlowBackground(topHex: 0x7C5CF6, bottomHex: 0x20B296)
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let list = store.todo {
                        progressCard(list)
                        addCard
                        if list.items.isEmpty {
                            emptyCard
                        } else {
                            section("Needs you", items: list.needsYou, icon: "exclamationmark.bubble.fill", tint: Theme.goldBright)
                            section("Doing now", items: list.doing, icon: "bolt.fill", tint: Theme.green)
                            section("Next", items: list.next, icon: "circle.dashed", tint: Theme.sub)
                            doneSection(list.done)
                        }
                    } else {
                        needsUpdateCard
                    }
                }
                .padding(16)
                .readableColumn(sizeClass == .regular ? 900 : Theme.readableWidth)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .toolbar {
            if let list = store.todo, list.doneCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(role: .destructive) {
                            confirmClear = true
                        } label: {
                            Label("Clear done", systemImage: "checkmark.circle.badge.xmark")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("More")
                }
            }
        }
        .confirmationDialog("Take every finished to-do off the list?", isPresented: $confirmClear, titleVisibility: .visible) {
            Button("Clear done", role: .destructive) { store.clearDoneTodos() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("They go from the computer's list too.")
        }
        .sensoryFeedback(.success, trigger: ticks) { _, _ in haptics }
        .animation(.easeOut(duration: 0.22), value: store.todo)
    }

    // MARK: - Top

    private func progressCard(_ list: TodoList) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(list.openCount == 0 ? "All done" : "\(list.openCount) to do")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Spacer()
                Text(list.countText)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.sub)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.field)
                    Capsule()
                        .fill(LinearGradient(colors: [Theme.green, Color(hex: 0x20B296)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(geo.size.width * list.progress, list.progress > 0 ? 8 : 0))
                }
            }
            .frame(height: 8)
            .accessibilityElement()
            .accessibilityLabel(list.countText)
            Text("The same list as the To do pane on your computer. Your bots and sessions add to it and tick things off too.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .glassCard(radius: 18)
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                TextField("", text: $draft, prompt: Text("Add a to-do…").foregroundStyle(Theme.muted))
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.text)
                    .focused($typing)
                    .submitLabel(.done)
                    .onSubmit(add)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
                Button(action: add) {
                    Image(systemName: store.isBusy("todo.add") ? "hourglass" : "arrow.up")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(canAdd ? store.accent : Color.white.opacity(0.1)))
                }
                .buttonStyle(.plain)
                .disabled(!canAdd)
                .accessibilityLabel(giveTo.flatMap { store.bot($0)?.name }.map { "Add and give to \($0)" } ?? "Add")
            }
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    Text("Give to")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                    Button("Nobody yet") { giveTo = nil }
                        .buttonStyle(ChipButtonStyle(isOn: giveTo == nil, tint: store.accent, minHeight: 32))
                    ForEach(store.bots) { bot in
                        Button {
                            giveTo = giveTo == bot.id ? nil : bot.id
                        } label: {
                            HStack(spacing: 6) {
                                Sphere(bot: bot, size: 18, glow: 0)
                                Text(bot.name)
                            }
                        }
                        .buttonStyle(ChipButtonStyle(isOn: giveTo == bot.id, tint: bot.color, minHeight: 32))
                    }
                }
            }
            .scrollIndicators(.hidden)
            if let id = giveTo, let bot = store.bot(id) {
                Text("\(bot.name) gets a message about it and starts right away.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.sub)
            }
        }
        .padding(14)
        .glassCard(radius: 18)
        .onChange(of: store.bots) { _, bots in
            if let id = giveTo, !bots.contains(where: { $0.id == id }) { giveTo = nil }
        }
    }

    private var canAdd: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && store.isConnected && !store.isBusy("todo.add")
    }

    private func add() {
        guard canAdd else { return }
        let text = draft
        let bot = giveTo
        Task {
            if await store.addTodo(text, giveTo: bot) {
                draft = ""
                ticks += 1
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private func section(_ title: String, items: [TodoItem], icon: String, tint: Color) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint)
                    SectionLabel(text: "\(title) · \(items.count)")
                }
                .padding(.leading, 4)
                ForEach(items) { item in
                    row(item)
                }
            }
        }
    }

    @ViewBuilder
    private func doneSection(_ items: [TodoItem]) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { showDone.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.green)
                        SectionLabel(text: "Done · \(items.count)")
                        Image(systemName: showDone ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(.leading, 4)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(showDone ? "Hide done" : "Show done")
                if showDone {
                    ForEach(items) { item in
                        row(item)
                    }
                }
            }
        }
    }

    private func row(_ item: TodoItem) -> some View {
        TodoRow(item: item) {
            let finishing = item.isOpen
            store.setTodo(item.id, status: finishing ? .done : .todo)
            if finishing { ticks += 1 }
        }
    }

    // MARK: - Empty and old computers

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checklist")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Theme.sub)
            Text("Nothing on the list")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textBright)
            Text("Add something above. Your bots add their own work here too, and pick up what's left when they have nothing to do.")
                .font(.system(size: 13))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(22)
        .glassCard(radius: 18)
    }

    private var needsUpdateCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Update Squall on the computer", systemImage: "arrow.down.circle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textBright)
            Text("This copy of Squall on your computer doesn't share its To do list with the app yet. Once it's updated, the list shows here.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18)
    }
}

/// One to-do: a tick circle, the words, who's on it, and a menu to start it, give it to a bot or remove it.
struct TodoRow: View {
    @EnvironmentObject private var store: SquallStore
    let item: TodoItem
    var onTick: () -> Void

    private var bot: Bot? { item.botID.flatMap { store.bot($0) } }
    private var busy: Bool { store.isBusy("todo.\(item.id)") }

    /// Gold while it waits on you, the bot's color while a bot does it.
    private var tintHex: UInt32? {
        if item.needsYou { return Theme.goldHex }
        if item.status == .doing { return bot?.hex }
        return nil
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Button(action: onTick) {
                ZStack {
                    Circle()
                        .stroke(item.isOpen ? Color.white.opacity(0.3) : Theme.green, lineWidth: 1.6)
                        .frame(width: 24, height: 24)
                    if !item.isOpen {
                        Circle().fill(Theme.green).frame(width: 24, height: 24)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .heavy))
                            .foregroundStyle(Theme.darkInk)
                    }
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(busy || !store.isConnected)
            .accessibilityLabel(item.isOpen ? "Mark done" : "Not done after all")
            .padding(.top, -10)
            .padding(.leading, -10)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.text)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(item.isOpen ? Theme.text : Theme.muted)
                    .strikethrough(!item.isOpen, color: Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                if let needs = item.needs {
                    needsLine(needs)
                }
                meta
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if item.isOpen {
                menu
            }
        }
        .padding(.vertical, 12)
        .padding(.trailing, 12)
        .padding(.leading, 12)
        .glassCard(radius: 16, tint: tintHex, strength: 0.1)
        .opacity(busy ? 0.6 : 1)
        .contextMenu { menuItems }
    }

    private func needsLine(_ needs: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(needs)
                .font(.system(size: 13))
                .foregroundStyle(Theme.goldText)
                .fixedSize(horizontal: false, vertical: true)
            if let id = item.needsBy, let asker = store.bot(id) {
                Button {
                    store.openChat(asker.id)
                } label: {
                    Label("Answer \(asker.name)", systemImage: "bubble.left.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(ChipButtonStyle(isOn: true, tint: Theme.gold, minHeight: 32))
            }
        }
    }

    @ViewBuilder
    private var meta: some View {
        let parts = metaParts
        if !parts.isEmpty || bot != nil {
            HStack(spacing: 6) {
                if let bot, item.status != .todo {
                    Sphere(bot: bot, size: 16, glow: 0)
                }
                Text(parts.joined(separator: " · "))
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
        }
    }

    private var metaParts: [String] {
        var parts: [String] = []
        let name = bot?.name ?? item.who
        switch item.status {
        case .doing where !name.isEmpty: parts.append("\(name) is on it")
        case .done where !name.isEmpty: parts.append("\(name) did it")
        default: break
        }
        if !item.by.isEmpty, item.by != name || item.status == .todo { parts.append("Added by \(item.by == Prefs.displayName || item.by == "Storm" ? "you" : item.by)") }
        if item.status == .done, let doneAt = item.doneAt {
            parts.append(doneAt.formatted(.relative(presentation: .named)))
        }
        return parts
    }

    private var menu: some View {
        Menu {
            menuItems
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.sub)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .disabled(busy || !store.isConnected)
        .accessibilityLabel("More for this to-do")
        .padding(.top, -6)
    }

    @ViewBuilder
    private var menuItems: some View {
        if item.isOpen {
            if item.status == .todo {
                Button {
                    store.setTodo(item.id, status: .doing)
                } label: {
                    Label("Doing it now", systemImage: "play.fill")
                }
            } else {
                Button {
                    store.setTodo(item.id, status: .todo)
                } label: {
                    Label("Not started", systemImage: "arrow.uturn.backward")
                }
            }
            Menu {
                ForEach(store.bots) { bot in
                    Button(bot.name) {
                        store.giveTodo(item.id, to: bot.id)
                    }
                }
            } label: {
                Label("Give to a bot", systemImage: "person.crop.circle.badge.plus")
            }
            Button {
                store.setTodo(item.id, status: .done)
            } label: {
                Label("Done", systemImage: "checkmark.circle")
            }
        } else {
            Button {
                store.setTodo(item.id, status: .todo)
            } label: {
                Label("Not done after all", systemImage: "arrow.uturn.backward")
            }
        }
        Button {
            UIPasteboard.general.string = item.text
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
        Button(role: .destructive) {
            store.deleteTodo(item.id)
        } label: {
            Label("Remove", systemImage: "trash")
        }
    }
}

/// The To do list at a glance on the Team tab, once the computer shares it.
struct TodoSummaryCard: View {
    @EnvironmentObject private var store: SquallStore
    let list: TodoList

    var body: some View {
        Button {
            store.path.append(.todo)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "checklist")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .frame(width: 40, height: 40)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
                VStack(alignment: .leading, spacing: 3) {
                    Text("To do")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Theme.textBright)
                    Text(subtitle)
                        .font(.system(size: 12.5))
                        .foregroundStyle(list.needsYou.isEmpty ? Theme.sub : Theme.goldText)
                        .lineLimit(1)
                }
                Spacer(minLength: 8)
                if !list.items.isEmpty {
                    ZStack {
                        Circle().stroke(Theme.field, lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: list.progress)
                            .stroke(Theme.green, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 28, height: 28)
                    .accessibilityHidden(true)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .glassCard(radius: 18, tint: list.needsYou.isEmpty ? nil : Theme.goldHex, strength: 0.1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("To do, \(subtitle)")
    }

    private var subtitle: String {
        if !list.needsYou.isEmpty {
            return list.needsYou.count == 1 ? "1 needs you" : "\(list.needsYou.count) need you"
        }
        if list.items.isEmpty { return "Nothing on the list" }
        if list.openCount == 0 { return "All done" }
        let doing = list.doing.count
        return "\(list.openCount) open" + (doing > 0 ? " · \(doing) being done" : "") + " · \(list.countText)"
    }
}
