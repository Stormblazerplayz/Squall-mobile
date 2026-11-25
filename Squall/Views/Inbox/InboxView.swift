import SwiftUI

/// Everything that needs you, plus problems and finished work.
struct InboxView: View {
    @EnvironmentObject private var store: SquallStore
    @State private var filter: InboxItem.Filter = .all
    @State private var openDetails: Set<String> = []
    @State private var selectedID: String?
    @Environment(\.horizontalSizeClass) private var sizeClass

    var body: some View {
        ZStack {
            GlowBackground()
            if sizeClass == .regular {
                wideLayout
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        filterBar
                        sections
                    }
                    .padding(16)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)
            }
        }
        .animation(.easeOut(duration: 0.25), value: store.inbox)
        .animation(.easeOut(duration: 0.2), value: openDetails)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text("Inbox")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Spacer()
                NotesButton()
                    .padding(.trailing, 4)
                HistoryButton()
                    .padding(.trailing, 4)
                Button(store.unreadInboxCount == 0 ? "All read" : "Mark all read") {
                    store.markAllRead()
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(store.unreadInboxCount == 0 ? Theme.muted : Theme.text)
                .disabled(store.unreadInboxCount == 0)
            }
            Text(summary)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
        }
    }

    private var summary: String {
        let needs = store.waitingOnYouCount
        let unread = store.unreadInboxCount
        let needsText = needs == 1 ? "1 thing needs you" : "\(needs) things need you"
        return "\(needsText) · \(unread) unread"
    }

    private func count(_ filter: InboxItem.Filter) -> Int {
        items(for: filter).count
    }

    private func items(for filter: InboxItem.Filter) -> [InboxItem] {
        switch filter {
        case .all: return store.inbox
        case .needs: return store.inbox.filter { $0.kind.needsYou }
        case .problems: return store.inbox.filter { $0.kind == .error }
        case .done: return store.inbox.filter {
            if case .done = $0.kind { return true }
            return false
        }
        }
    }

    private var filterBar: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(InboxItem.Filter.allCases) { option in
                    Button("\(option.label) \(count(option))") { filter = option }
                        .buttonStyle(ChipButtonStyle(isOn: filter == option, tint: store.accent))
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private var sections: some View {
        let shown = items(for: filter)
        if shown.isEmpty {
            Text(filter.emptyText)
                .font(.system(size: 14))
                .foregroundStyle(Theme.sub)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 50)
        } else {
            section("Needs you", dot: Theme.goldBright, items: shown.filter { $0.kind.needsYou })
            section("Problems", dot: Theme.redSoft, items: shown.filter { $0.kind == .error })
            section("Done", dot: Theme.green, items: shown.filter {
                if case .done = $0.kind { return true }
                return false
            })
        }
    }

    @ViewBuilder
    private func section(_ title: String, dot: Color, items: [InboxItem]) -> some View {
        if !items.isEmpty {
            HStack(spacing: 6) {
                Circle().fill(dot).frame(width: 7, height: 7)
                SectionLabel(text: title)
            }
            .padding(.top, 4)
            ForEach(items) { item in
                InboxCard(item: item, showDetails: openDetails.contains(item.id)) {
                    toggleDetails(item.id)
                }
            }
        }
    }

    private func toggleDetails(_ id: String) {
        if openDetails.contains(id) {
            openDetails.remove(id)
        } else {
            openDetails.insert(id)
        }
    }

    // MARK: iPad: list on the left, the picked item on the right

    private var wideLayout: some View {
        let shown = items(for: filter)
        let selected = shown.first(where: { $0.id == selectedID }) ?? shown.first
        return HStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    header
                    filterBar
                    if shown.isEmpty {
                        Text(filter.emptyText)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.sub)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 50)
                    } else {
                        listSection("Needs you", dot: Theme.goldBright, items: shown.filter { $0.kind.needsYou }, selected: selected?.id)
                        listSection("Problems", dot: Theme.redSoft, items: shown.filter { $0.kind == .error }, selected: selected?.id)
                        listSection("Done", dot: Theme.green, items: shown.filter {
                            if case .done = $0.kind { return true }
                            return false
                        }, selected: selected?.id)
                    }
                }
                .padding(20)
            }
            .scrollIndicators(.hidden)
            .frame(width: 400)

            Rectangle()
                .fill(Theme.cardBorder)
                .frame(width: 1)
                .ignoresSafeArea(edges: .vertical)

            ScrollView {
                Group {
                    if let selected {
                        InboxDetail(item: selected, showDetails: openDetails.contains(selected.id)) {
                            toggleDetails(selected.id)
                        }
                    } else {
                        Text("Pick something on the left.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.sub)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 80)
                    }
                }
                .padding(24)
                .readableColumn(720)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func listSection(_ title: String, dot: Color, items: [InboxItem], selected: String?) -> some View {
        if !items.isEmpty {
            HStack(spacing: 6) {
                Circle().fill(dot).frame(width: 7, height: 7)
                SectionLabel(text: title)
            }
            .padding(.top, 4)
            ForEach(items) { item in
                InboxRow(item: item, isOn: item.id == selected) {
                    selectedID = item.id
                    store.markRead(item.id)
                }
            }
        }
    }
}

/// Small row for the iPad list. Tapping it shows the item on the right.
private struct InboxRow: View {
    @EnvironmentObject private var store: SquallStore
    let item: InboxItem
    let isOn: Bool
    var select: () -> Void

    var body: some View {
        Button(action: select) {
            HStack(alignment: .top, spacing: 10) {
                if let bot = store.bot(item.botID) {
                    Sphere(bot: bot, size: 34)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(Theme.textBright)
                            .lineLimit(1)
                        if item.unread {
                            Circle().fill(store.accent).frame(width: 7, height: 7)
                                .accessibilityLabel("Unread")
                        }
                        Spacer(minLength: 0)
                        Text(item.time)
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.muted)
                    }
                    Text(item.body)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 16, tint: isOn ? store.accentHex : nil, strength: 0.18,
                       border: isOn ? store.accent.opacity(0.7) : nil)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The right side on iPad: who sent it, the full card, and a way to their chat.
private struct InboxDetail: View {
    @EnvironmentObject private var store: SquallStore
    let item: InboxItem
    let showDetails: Bool
    var toggleDetails: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if let bot = store.bot(item.botID) {
                HStack(spacing: 14) {
                    Sphere(bot: bot, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bot.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.textBright)
                        Text(bot.role)
                            .font(.system(size: 13.5))
                            .foregroundStyle(Theme.sub)
                    }
                    Spacer(minLength: 0)
                    StatusPill(status: bot.status)
                }
            }
            InboxCard(item: item, showDetails: showDetails, toggleDetails: toggleDetails)
            if let bot = store.bot(item.botID) {
                Button("Open chat with \(bot.name)") { store.openChat(bot.id) }
                    .buttonStyle(GhostButtonStyle(height: 44))
            }
        }
    }
}

private struct InboxCard: View {
    @EnvironmentObject private var store: SquallStore
    let item: InboxItem
    let showDetails: Bool
    var toggleDetails: () -> Void

    var body: some View {
        let bot = store.bot(item.botID)
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                ZStack(alignment: .bottomTrailing) {
                    if let bot {
                        Sphere(bot: bot, size: 38)
                    }
                    Text(item.kind.badge)
                        .font(.system(size: 10, weight: .heavy))
                        .foregroundStyle(Theme.darkInk)
                        .frame(width: 16, height: 16)
                        .background(Circle().fill(badgeColor))
                        .offset(x: 3, y: 3)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textBright)
                        if item.unread {
                            Circle().fill(store.accent).frame(width: 7, height: 7)
                                .accessibilityLabel("Unread")
                        }
                    }
                    Text(item.body)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.sub)
                }
                Spacer(minLength: 0)
                Text(item.time)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.muted)
            }
            actions
            if showDetails, item.kind == .error, let details = item.details, !details.isEmpty {
                Text(details)
                    .font(Theme.mono(11.5))
                    .foregroundStyle(Theme.redText)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.black.opacity(0.35)))
                    .textSelection(.enabled)
            }
        }
        .padding(14)
        .glassCard(radius: 18, tint: item.fresh ? 0x4ADE80 : nil, strength: 0.1, border: borderColor)
        .contentShape(Rectangle())
        .onTapGesture { store.markRead(item.id) }
    }

    private var badgeColor: Color {
        switch item.kind {
        case .ask, .choice: return Theme.goldBright
        case .error: return Theme.redSoft
        case .done: return Theme.green
        }
    }

    private var borderColor: Color? {
        switch item.kind {
        case .ask, .choice: return Theme.goldBright.opacity(0.35)
        case .error: return Theme.red.opacity(0.35)
        case .done: return nil
        }
    }

    @ViewBuilder
    private var actions: some View {
        let busy = store.isBusy("inbox.\(item.id)")
        switch item.kind {
        case .ask:
            HStack(spacing: 8) {
                Button("Allow") { store.answer(item.id, with: "allow") }
                    .buttonStyle(FilledButtonStyle(fill: Theme.green.opacity(0.85), foreground: Theme.darkInk, height: 40))
                Button("Deny") { store.answer(item.id, with: "deny") }
                    .buttonStyle(GhostButtonStyle(height: 40))
            }
            .disabled(busy)
            // Ask on the Lock Screen instead, with Allow and Deny right there.
            LockScreenButton(kind: .approval) {
                LiveActivities.shared.startApproval(item, bot: store.bot(item.botID))
            }
        case .choice(let options):
            VStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button(option) { store.answer(item.id, with: option) }
                        .buttonStyle(GhostButtonStyle(height: 40))
                }
            }
            .disabled(busy)
        case .error:
            HStack(spacing: 8) {
                if store.chiefNeedsUpdate {
                    Button(store.isUpdatingClaudeCode ? "Updating…" : "Update Claude Code") { store.runUpdate() }
                        .buttonStyle(FilledButtonStyle(fill: Theme.gold, foreground: Theme.darkInk, height: 40))
                        .disabled(store.isUpdatingClaudeCode)
                }
                if let details = item.details, !details.isEmpty {
                    Button(showDetails ? "Hide" : "Details", action: toggleDetails)
                        .buttonStyle(GhostButtonStyle(height: 40, expand: !store.chiefNeedsUpdate))
                }
                Button("Clear") { store.clearInbox(item.id) }
                    .buttonStyle(GhostButtonStyle(height: 40, expand: false, foreground: Theme.sub, fontSize: 14))
            }
            if let progress = store.claudeCode?.updating {
                ProgressView(value: progress).tint(Theme.goldBright)
            }
        case .done(let openLabel):
            HStack(spacing: 8) {
                Button(openLabel) { open() }
                    .buttonStyle(GhostButtonStyle(height: 38, fontSize: 14))
                Button("Clear") { store.clearInbox(item.id) }
                    .buttonStyle(GhostButtonStyle(height: 38, expand: false, foreground: Theme.sub, fontSize: 14))
            }
        }
    }

    private func open() {
        store.markRead(item.id)
        switch item.opens {
        case .live:
            if let workID = item.workID {
                store.watch(workID)
            } else {
                store.path.append(.live)
            }
        case .chat:
            store.openChat(item.botID)
        }
    }
}
