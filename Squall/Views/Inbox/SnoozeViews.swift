import SwiftUI

/// Press and hold an Inbox card: hide it until later.
struct SnoozeMenuItems: View {
    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var snooze = InboxSnooze.shared
    let item: InboxItem

    var body: some View {
        let now = Date()
        Section("Snooze") {
            ForEach(InboxSnooze.Choice.allCases) { choice in
                if let until = choice.until(from: now) {
                    Button {
                        snooze.snooze(item, until: until)
                        store.markRead(item.id)
                        store.showToast("Snoozed \(InboxSnooze.untilText(until)). It's under Snoozed at the bottom.")
                    } label: {
                        Label(choice.label, systemImage: choice.icon)
                    }
                }
            }
        }
    }
}

/// The bottom of the Inbox: what's snoozed and when it comes back.
struct SnoozedSection: View {
    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var snooze = InboxSnooze.shared
    @State private var open = false

    var body: some View {
        let list = snooze.snoozed(store.inbox)
        if !list.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { open.toggle() }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.sub)
                        SectionLabel(text: "Snoozed \(list.count)")
                        Spacer()
                        Image(systemName: open ? "chevron.up" : "chevron.down")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.muted)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if open {
                    ForEach(list) { item in
                        row(item)
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    private func row(_ item: InboxItem) -> some View {
        HStack(spacing: 10) {
            if let bot = store.bot(item.botID) {
                Sphere(bot: bot, size: 26)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .lineLimit(1)
                if let until = snooze.until(item.id) {
                    Text(InboxSnooze.untilText(until))
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                }
            }
            Spacer(minLength: 6)
            Button("Wake") { snooze.wake(item.id) }
                .buttonStyle(GhostButtonStyle(height: 32, expand: false, fontSize: 13, sidePadding: 10))
        }
        .padding(10)
        .glassCard(radius: 14, tint: nil, strength: 0.06, border: nil)
    }
}
