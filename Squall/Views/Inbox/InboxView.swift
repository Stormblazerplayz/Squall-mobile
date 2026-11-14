import SwiftUI

/// Everything that needs you, plus problems and finished work.
struct InboxView: View {
    @EnvironmentObject private var store: SquallStore
    @State private var filter: InboxItem.Filter = .all
    @State private var openDetails: Set<String> = []

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    filterBar
                    sections
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
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
                    if openDetails.contains(item.id) {
                        openDetails.remove(item.id)
                    } else {
                        openDetails.insert(item.id)
                    }
                }
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
            if showDetails, item.kind == .error {
                Text(SampleData.chiefError)
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
        switch item.kind {
        case .ask:
            HStack(spacing: 8) {
                Button("Allow") { store.allowPush() }
                    .buttonStyle(FilledButtonStyle(fill: Theme.green.opacity(0.85), foreground: Theme.darkInk, height: 40))
                Button("Deny") { store.denyPush() }
                    .buttonStyle(GhostButtonStyle(height: 40))
            }
        case .choice(let options):
            VStack(spacing: 6) {
                ForEach(options, id: \.self) { option in
                    Button(option) { store.pickIcon(option) }
                        .buttonStyle(GhostButtonStyle(height: 40))
                }
            }
        case .error:
            HStack(spacing: 8) {
                Button(updateLabel) { store.runUpdate() }
                    .buttonStyle(FilledButtonStyle(fill: Theme.gold, foreground: Theme.darkInk, height: 40))
                    .disabled(store.claudeCode != .needed)
                Button(showDetails ? "Hide" : "Details", action: toggleDetails)
                    .buttonStyle(GhostButtonStyle(height: 40, expand: false))
            }
            if case .updating(let progress) = store.claudeCode {
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

    private var updateLabel: String {
        if case .updating = store.claudeCode { return "Updating…" }
        return "Update Claude Code"
    }

    private func open() {
        store.markRead(item.id)
        switch item.opens {
        case .live:
            store.path.append(.live)
        case .chat:
            store.openChat(item.botID)
        }
    }
}
