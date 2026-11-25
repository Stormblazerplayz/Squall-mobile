import SwiftUI
import WidgetKit

// The Inbox widget: what needs you and what broke, with Allow and Deny right on the Home Screen.

struct InboxEntry: TimelineEntry {
    let date: Date
    let snapshot: InboxWidgetSnapshot?
}

struct InboxProvider: TimelineProvider {
    func placeholder(in context: Context) -> InboxEntry {
        // The gallery preview is the empty "Open Squall" card, never pretend requests.
        InboxEntry(date: Date(), snapshot: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (InboxEntry) -> Void) {
        completion(InboxEntry(date: Date(), snapshot: InboxWidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<InboxEntry>) -> Void) {
        let now = Date()
        let saved = InboxWidgetSnapshot.load()
        var entries = [InboxEntry(date: now, snapshot: saved)]
        // A second entry when the data turns old, so the buttons go away and it says so.
        if let saved, saved.paired {
            let staleAt = saved.syncedAt.addingTimeInterval(15 * 60 + 1)
            if staleAt > now { entries.append(InboxEntry(date: staleAt, snapshot: saved)) }
        }
        // The app reloads the widget when new data comes in; this is a backstop.
        completion(Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60))))
    }
}

struct InboxWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: InboxWidgetSnapshot.kind, provider: InboxProvider()) { entry in
            InboxWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    ZStack {
                        Color(activityHex: 0x0B0A12)
                        RadialGradient(colors: [Color(activityHex: Palette.goldHex, opacity: 0.22), .clear],
                                       center: .topTrailing, startRadius: 4, endRadius: 260)
                    }
                }
        }
        .configurationDisplayName("Squall Inbox")
        .description("What needs you and what broke. Allow or Deny right here. Comes from your paired computer.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

struct InboxWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: InboxEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, snapshot.paired {
                content(snapshot)
            } else if let snapshot = entry.snapshot, !snapshot.paired {
                note(icon: "desktopcomputer", title: "Not paired", detail: "Open Squall to pair with your computer.")
            } else {
                note(icon: "arrow.triangle.2.circlepath", title: "Open Squall to sync",
                     detail: "What needs you shows up here after Squall talks to your computer.")
            }
        }
        .widgetURL(URL(string: entry.snapshot?.paired == true ? "squall://inbox" : "squall://settings"))
    }

    private var shownCount: Int { family == .systemLarge ? InboxWidgetSnapshot.maxItems : 2 }

    private func content(_ snapshot: InboxWidgetSnapshot) -> some View {
        let stale = snapshot.isStale(now: entry.date)
        let shown = Array(snapshot.items.prefix(shownCount))
        let rest = (snapshot.needsYou + snapshot.problems) - shown.count
        return VStack(alignment: .leading, spacing: family == .systemLarge ? 10 : 7) {
            header(snapshot)
            if shown.isEmpty {
                Spacer(minLength: 0)
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(Palette.green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Nothing needs you")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.text)
                        Text("Your team is getting on with it.")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Palette.sub)
                    }
                }
                Spacer(minLength: 0)
            } else {
                ForEach(shown) { item in
                    row(item, canAnswer: !stale)
                }
                Spacer(minLength: 0)
            }
            footer(snapshot, stale: stale, rest: rest)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(_ snapshot: InboxWidgetSnapshot) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "tray.full.fill")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Palette.goldText)
            Text("INBOX")
                .font(.system(size: 11, weight: .heavy))
                .tracking(0.8)
                .foregroundStyle(Palette.text)
            Spacer(minLength: 0)
            if snapshot.needsYou > 0 {
                pill("\(snapshot.needsYou) need\(snapshot.needsYou == 1 ? "s" : "") you", color: Palette.gold)
            }
            if snapshot.problems > 0 {
                pill("\(snapshot.problems) problem\(snapshot.problems == 1 ? "" : "s")", color: Palette.red)
            }
        }
    }

    private func pill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(Palette.ink)
            .padding(.horizontal, 7)
            .frame(height: 18)
            .background(Capsule().fill(color))
    }

    private func row(_ item: InboxWidgetSnapshot.Item, canAnswer: Bool) -> some View {
        HStack(alignment: .center, spacing: 9) {
            Avatar(letter: String(item.botName.prefix(1)).uppercased(), hex: item.hex, size: 28)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: icon(item))
                        .font(.system(size: 7, weight: .heavy))
                        .foregroundStyle(Palette.ink)
                        .frame(width: 13, height: 13)
                        .background(Circle().fill(item.kind == "error" ? Palette.red : Palette.gold))
                        .offset(x: 3, y: 3)
                }
            VStack(alignment: .leading, spacing: 1) {
                Text("\(item.botName) · \(item.time)")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(Palette.muted)
                    .lineLimit(1)
                Text(item.title)
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(family == .systemLarge ? 2 : 1)
                if family == .systemLarge, let command = item.command {
                    Text(command)
                        .font(.system(size: 10.5, design: .monospaced))
                        .foregroundStyle(Palette.sub)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 4)
            if item.isAsk, canAnswer {
                answerButtons(item.id)
            } else if item.kind == "choice" {
                Text("Answer")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .padding(.horizontal, 9)
                    .frame(height: 24)
                    .background(Capsule().fill(Palette.button))
            }
        }
    }

    private func answerButtons(_ itemID: String) -> some View {
        HStack(spacing: 5) {
            Button(intent: AnswerAskIntent(itemID: itemID, allow: true)) {
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Palette.ink)
                    .frame(width: 30, height: 26)
                    .background(Capsule().fill(Palette.green))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Allow")
            Button(intent: AnswerAskIntent(itemID: itemID, allow: false)) {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .heavy))
                    .foregroundStyle(Palette.text)
                    .frame(width: 30, height: 26)
                    .background(Capsule().fill(Palette.button))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Deny")
        }
    }

    private func footer(_ snapshot: InboxWidgetSnapshot, stale: Bool, rest: Int) -> some View {
        HStack(spacing: 4) {
            if stale {
                Text("Old data · \(Text(snapshot.syncedAt, style: .relative)) ago")
                    .foregroundStyle(Palette.goldText)
            } else if rest > 0 {
                Text("\(rest) more in Squall")
                    .foregroundStyle(Palette.sub)
            } else {
                Text("Synced \(Text(snapshot.syncedAt, style: .relative)) ago")
                    .foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 10.5))
        .lineLimit(1)
    }

    private func icon(_ item: InboxWidgetSnapshot.Item) -> String {
        switch item.kind {
        case "error": return "exclamationmark"
        case "choice": return "questionmark"
        default: return "hand.raised.fill"
        }
    }

    private func note(icon: String, title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Palette.accentText)
            Text(title)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Palette.text)
            Text(detail)
                .font(.system(size: 11.5))
                .foregroundStyle(Palette.sub)
                .lineLimit(3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
