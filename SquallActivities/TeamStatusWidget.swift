import SwiftUI
import WidgetKit

// Home Screen and Lock Screen widgets for your team. They draw the summary the app
// saves after each real update from the paired computer (WidgetSnapshot). With no
// real data they say so, and never show a made-up team.

struct TeamEntry: TimelineEntry {
    let date: Date
    /// Nil when the app hasn't saved anything yet (or the App Group isn't set up).
    let snapshot: WidgetSnapshot?
}

struct TeamProvider: TimelineProvider {
    func placeholder(in context: Context) -> TeamEntry {
        // The gallery preview: an empty "Open Squall" card, not a pretend team.
        TeamEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TeamEntry) -> Void) {
        completion(TeamEntry(date: Date(), snapshot: SquallShared.loadWidget()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TeamEntry>) -> Void) {
        let now = Date()
        let saved = SquallShared.loadWidget()
        // One entry now, and one when the data turns old, so the widget can say so.
        var entries = [TeamEntry(date: now, snapshot: saved)]
        if let saved, saved.paired {
            let staleAt = saved.syncedAt.addingTimeInterval(15 * 60 + 1)
            if staleAt > now {
                entries.append(TeamEntry(date: staleAt, snapshot: saved))
            }
        }
        // The app reloads the widget whenever new data comes in; this is just a backstop.
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}

struct TeamStatusWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: SquallShared.widgetKind, provider: TeamProvider()) { entry in
            TeamWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    WidgetBackdrop()
                }
        }
        .configurationDisplayName("Squall team")
        .description("What Chief and your bots are doing, and what needs you. Comes from your paired computer.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryCircular, .accessoryInline])
    }
}

/// The dark glowy background, only on the Home Screen (the Lock Screen draws its own).
private struct WidgetBackdrop: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        switch family {
        case .systemSmall, .systemMedium:
            ZStack {
                Color(activityHex: 0x0B0A12)
                RadialGradient(
                    colors: [Color(activityHex: 0x6D5CE8, opacity: 0.35), .clear],
                    center: .topLeading,
                    startRadius: 4,
                    endRadius: 220
                )
            }
        default:
            Color.clear
        }
    }
}

struct TeamWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TeamEntry

    var body: some View {
        Group {
            switch state {
            case .noData:
                message(icon: "desktopcomputer", title: "Open Squall", detail: "Pair with your computer to see your team here.")
            case .notPaired:
                message(icon: "desktopcomputer", title: "Not paired", detail: "Open Squall to pair with your computer.")
            case .team(let snapshot):
                team(snapshot)
            }
        }
        .widgetURL(link)
    }

    private enum ShowState {
        case noData
        case notPaired
        case team(WidgetSnapshot)
    }

    private var state: ShowState {
        guard let snapshot = entry.snapshot else { return .noData }
        guard snapshot.paired else { return .notPaired }
        return .team(snapshot)
    }

    private var link: URL? {
        if case .team(let snapshot) = state, snapshot.needsYou > 0 {
            return URL(string: "squall://inbox")
        }
        if case .team = state {
            return URL(string: "squall://team")
        }
        return URL(string: "squall://settings")
    }

    // MARK: - No data

    @ViewBuilder
    private func message(icon: String, title: String, detail: String) -> some View {
        switch family {
        case .accessoryInline:
            Label("Squall: \(title)", systemImage: icon)
        case .accessoryCircular:
            ZStack {
                AccessoryWidgetBackground()
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .semibold))
            }
        case .accessoryRectangular:
            VStack(alignment: .leading, spacing: 2) {
                Label("Squall", systemImage: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 13))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        default:
            VStack(alignment: .leading, spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Palette.sub)
                Spacer(minLength: 0)
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.text)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.sub)
                    .lineLimit(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }

    // MARK: - The team

    @ViewBuilder
    private func team(_ snapshot: WidgetSnapshot) -> some View {
        switch family {
        case .accessoryInline:
            inline(snapshot)
        case .accessoryCircular:
            circular(snapshot)
        case .accessoryRectangular:
            rectangular(snapshot)
        case .systemMedium:
            medium(snapshot)
        default:
            small(snapshot)
        }
    }

    private func headline(_ snapshot: WidgetSnapshot) -> String {
        if snapshot.paused { return "Team paused" }
        if snapshot.needsYou == 1 { return "1 needs you" }
        if snapshot.needsYou > 1 { return "\(snapshot.needsYou) need you" }
        return "\(snapshot.workingCount) working"
    }

    private func inline(_ snapshot: WidgetSnapshot) -> some View {
        Label("Squall: \(headline(snapshot))", systemImage: snapshot.needsYou > 0 ? "exclamationmark.bubble.fill" : "person.2.fill")
    }

    private func circular(_ snapshot: WidgetSnapshot) -> some View {
        ZStack {
            AccessoryWidgetBackground()
            VStack(spacing: 0) {
                Image(systemName: snapshot.needsYou > 0 ? "tray.full.fill" : "person.2.fill")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(snapshot.needsYou > 0 ? snapshot.needsYou : snapshot.workingCount)")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.6)
            }
        }
        .widgetAccentable()
        .accessibilityLabel(headline(snapshot))
    }

    private func rectangular(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                Text("Squall · \(headline(snapshot))")
                    .lineLimit(1)
            }
            .font(.system(size: 13, weight: .semibold))
            .widgetAccentable()
            if let ask = snapshot.firstAsk {
                Text("\(snapshot.firstAskBot ?? "A bot"): \(ask)")
                    .font(.system(size: 12))
                    .lineLimit(2)
            } else if let chief = snapshot.members.first {
                Text("\(chief.name): \(chief.task.isEmpty ? chief.statusLabel : chief.task)")
                    .font(.system(size: 12))
                    .lineLimit(2)
            }
            syncedLine(snapshot)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func small(_ snapshot: WidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Palette.gold)
                Text("Squall")
                    .foregroundStyle(Palette.text)
                Spacer(minLength: 0)
            }
            .font(.system(size: 13, weight: .bold))
            Text(headline(snapshot))
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(snapshot.needsYou > 0 ? Palette.goldText : Palette.text)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            HStack(spacing: -6) {
                ForEach(snapshot.members.prefix(5)) { member in
                    memberBall(member, size: 24)
                }
            }
            Spacer(minLength: 0)
            if let ask = snapshot.firstAsk {
                Text(ask)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Palette.sub)
                    .lineLimit(2)
            }
            syncedLine(snapshot)
                .font(.system(size: 10.5))
                .foregroundStyle(snapshot.isStale(now: entry.date) ? Palette.goldText : Palette.muted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func medium(_ snapshot: WidgetSnapshot) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(Palette.gold)
                    Text("Squall")
                        .foregroundStyle(Palette.text)
                }
                .font(.system(size: 13, weight: .bold))
                Text(headline(snapshot))
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(snapshot.needsYou > 0 ? Palette.goldText : Palette.text)
                    .minimumScaleFactor(0.7)
                    .lineLimit(1)
                if let ask = snapshot.firstAsk {
                    Text("\(snapshot.firstAskBot ?? "A bot") asks: \(ask)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.sub)
                        .lineLimit(3)
                } else if snapshot.unreadInbox > 0 {
                    Text("\(snapshot.unreadInbox) unread in Inbox")
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.sub)
                }
                Spacer(minLength: 0)
                syncedLine(snapshot)
                    .font(.system(size: 10.5))
                    .foregroundStyle(snapshot.isStale(now: entry.date) ? Palette.goldText : Palette.muted)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            VStack(alignment: .leading, spacing: 5) {
                if snapshot.members.isEmpty {
                    Text("No bots yet")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.sub)
                }
                ForEach(snapshot.members.prefix(4)) { member in
                    HStack(spacing: 7) {
                        memberBall(member, size: 22)
                        VStack(alignment: .leading, spacing: 0) {
                            Text(member.name)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Palette.text)
                                .lineLimit(1)
                            Text(member.task.isEmpty ? member.statusLabel : member.task)
                                .font(.system(size: 10.5))
                                .foregroundStyle(statusColor(member.status))
                                .lineLimit(1)
                        }
                    }
                }
                if snapshot.members.count > 4 {
                    Text("+\(snapshot.members.count - 4) more")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.muted)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
    }

    private func memberBall(_ member: WidgetSnapshot.Member, size: CGFloat) -> some View {
        Avatar(letter: String(member.name.prefix(1)).uppercased(), hex: member.hex, size: size)
            .overlay(alignment: .bottomTrailing) {
                Circle()
                    .fill(statusColor(member.status))
                    .frame(width: size * 0.32, height: size * 0.32)
                    .overlay(Circle().stroke(Color(activityHex: 0x0B0A12), lineWidth: 1.5))
            }
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "working": return Palette.green
        case "waiting", "handed": return Palette.goldText
        case "napping", "paused": return Color(activityHex: 0xFACC15)
        default: return Palette.sub
        }
    }

    /// "Synced 3 min ago from Storm-PC", or "Old · 2 hr ago" once it's stale.
    private func syncedLine(_ snapshot: WidgetSnapshot) -> Text {
        let age = Text(snapshot.syncedAt, style: .relative)
        if snapshot.isStale(now: entry.date) {
            return Text("Old data · \(age) ago")
        }
        return Text("Synced \(age) ago")
    }
}
