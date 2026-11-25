import AppIntents
import SwiftUI
import WidgetKit

// A Home Screen and Lock Screen widget for one teammate you pick: what they're doing and the last message in your
// chat. Tapping it opens that chat. It draws what the app saved from the paired computer (TeammateWidgetSnapshot),
// and says so when there's nothing real to show.

// MARK: - Picking the teammate

struct TeammateEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Teammate"
    static let defaultQuery = TeammateQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct TeammateQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [TeammateEntity] {
        let list = Self.all()
        return identifiers.compactMap { id in list.first { $0.id == id } }
    }

    func suggestedEntities() async throws -> [TeammateEntity] {
        Self.all()
    }

    func defaultResult() async -> TeammateEntity? {
        Self.all().first
    }

    /// The team the app last saved, Chief first.
    static func all() -> [TeammateEntity] {
        (TeammateWidgetSnapshot.load()?.teammates ?? []).map { TeammateEntity(id: $0.id, name: $0.name) }
    }
}

struct TeammateWidgetIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Teammate"
    static let description = IntentDescription("Pick which teammate the widget shows.")

    @Parameter(title: "Teammate")
    var teammate: TeammateEntity?

    init() {}
}

// MARK: - Timeline

struct TeammateEntry: TimelineEntry {
    let date: Date
    /// Nil when the app hasn't saved anything yet.
    let snapshot: TeammateWidgetSnapshot?
    let teammateID: String?
}

struct TeammateProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TeammateEntry {
        // The gallery preview is the empty "Open Squall" card, never a pretend teammate.
        TeammateEntry(date: Date(), snapshot: nil, teammateID: nil)
    }

    func snapshot(for configuration: TeammateWidgetIntent, in context: Context) async -> TeammateEntry {
        TeammateEntry(date: Date(), snapshot: TeammateWidgetSnapshot.load(), teammateID: configuration.teammate?.id)
    }

    func timeline(for configuration: TeammateWidgetIntent, in context: Context) async -> Timeline<TeammateEntry> {
        let now = Date()
        let saved = TeammateWidgetSnapshot.load()
        let id = configuration.teammate?.id
        var entries = [TeammateEntry(date: now, snapshot: saved, teammateID: id)]
        // A second entry when the data turns old, so the widget can say so.
        if let saved, saved.paired {
            let staleAt = saved.syncedAt.addingTimeInterval(15 * 60 + 1)
            if staleAt > now { entries.append(TeammateEntry(date: staleAt, snapshot: saved, teammateID: id)) }
        }
        // The app reloads the widget when new data comes in; this is a backstop.
        return Timeline(entries: entries, policy: .after(now.addingTimeInterval(30 * 60)))
    }
}

// MARK: - The widget

struct TeammateWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: TeammateWidgetSnapshot.kind, intent: TeammateWidgetIntent.self,
                               provider: TeammateProvider()) { entry in
            TeammateWidgetView(entry: entry)
                .containerBackground(for: .widget) {
                    TeammateBackdrop(hex: entry.snapshot?.teammate(entry.teammateID)?.hex ?? 0x6D5CE8)
                }
        }
        .configurationDisplayName("Squall teammate")
        .description("One teammate: what they're doing and the last message in your chat. Comes from your paired computer.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular, .accessoryInline])
    }
}

/// The dark background with the teammate's color glowing in the corner, only on the Home Screen.
private struct TeammateBackdrop: View {
    @Environment(\.widgetFamily) private var family
    let hex: UInt32

    var body: some View {
        switch family {
        case .systemSmall, .systemMedium:
            ZStack {
                Color(activityHex: 0x0B0A12)
                RadialGradient(colors: [Color(activityHex: hex, opacity: 0.42), .clear],
                               center: .topLeading, startRadius: 4, endRadius: 230)
            }
        default:
            Color.clear
        }
    }
}

struct TeammateWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TeammateEntry

    var body: some View {
        Group {
            if let snapshot = entry.snapshot, snapshot.paired, let mate = snapshot.teammate(entry.teammateID) {
                switch family {
                case .accessoryInline:
                    inline(mate)
                case .accessoryRectangular:
                    rectangular(mate)
                case .systemMedium:
                    medium(mate, snapshot: snapshot)
                default:
                    small(mate, snapshot: snapshot)
                }
            } else if let snapshot = entry.snapshot, !snapshot.paired {
                note(icon: "desktopcomputer", title: "Not paired", detail: "Open Squall to pair with your computer.")
            } else {
                note(icon: "arrow.triangle.2.circlepath", title: "Open Squall to sync",
                     detail: "Your teammate shows up here after Squall talks to your computer.")
            }
        }
        .widgetURL(link)
    }

    private var link: URL? {
        guard let snapshot = entry.snapshot, snapshot.paired, let mate = snapshot.teammate(entry.teammateID) else {
            return URL(string: "squall://settings")
        }
        let id = mate.id.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? mate.id
        return URL(string: "squall://chat/\(id)")
    }

    // MARK: - Sizes

    private func inline(_ mate: TeammateWidgetSnapshot.Teammate) -> some View {
        Label("\(mate.name): \(mate.statusLabel)", systemImage: "person.fill")
    }

    private func rectangular(_ mate: TeammateWidgetSnapshot.Teammate) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(mate.name) · \(mate.statusLabel)")
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
            Text(lastLine(mate))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func small(_ mate: TeammateWidgetSnapshot.Teammate, snapshot: TeammateWidgetSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            header(mate, size: 30)
            Spacer(minLength: 0)
            Text(lastLine(mate))
                .font(.system(size: 12.5))
                .foregroundStyle(mate.lastText == nil ? Palette.muted : Palette.text)
                .lineLimit(3)
            footer(mate, snapshot: snapshot)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func medium(_ mate: TeammateWidgetSnapshot.Teammate, snapshot: TeammateWidgetSnapshot) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                header(mate, size: 36)
                if !mate.task.isEmpty {
                    Text(mate.task)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Palette.sub)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                footer(mate, snapshot: snapshot)
            }
            .frame(width: 118, alignment: .leading)
            VStack(alignment: .leading, spacing: 6) {
                Text(mate.lastText == nil ? "NO MESSAGES YET" : (mate.lastFromMe ? "YOU SAID" : "\(mate.name.uppercased()) SAID"))
                    .font(.system(size: 9.5, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Palette.muted)
                Text(mate.lastText ?? "Tap to start a chat with \(mate.name).")
                    .font(.system(size: 13))
                    .foregroundStyle(mate.lastText == nil ? Palette.sub : Palette.text)
                    .lineLimit(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Spacer(minLength: 0)
                HStack(spacing: 4) {
                    Image(systemName: "bubble.left.fill")
                    Text("Open chat")
                }
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(Palette.text)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule().fill(Color(activityHex: mate.hex, opacity: 0.45)))
            }
            .padding(10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.white.opacity(0.06)))
        }
    }

    // MARK: - Parts

    private func header(_ mate: TeammateWidgetSnapshot.Teammate, size: CGFloat) -> some View {
        HStack(spacing: 8) {
            Avatar(letter: String(mate.name.prefix(1)).uppercased(), hex: mate.hex, size: size)
                .overlay(alignment: .bottomTrailing) {
                    Circle()
                        .fill(statusColor(mate.status))
                        .frame(width: size * 0.3, height: size * 0.3)
                        .overlay(Circle().stroke(Color(activityHex: 0x0B0A12), lineWidth: 1.5))
                }
            VStack(alignment: .leading, spacing: 1) {
                Text(mate.name)
                    .font(.system(size: 14.5, weight: .bold))
                    .foregroundStyle(Palette.text)
                    .lineLimit(1)
                Text(mate.statusLabel)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusColor(mate.status))
                    .lineLimit(1)
            }
        }
    }

    private func footer(_ mate: TeammateWidgetSnapshot.Teammate, snapshot: TeammateWidgetSnapshot) -> some View {
        Group {
            if snapshot.isStale(now: entry.date) {
                Text("Old data · \(Text(snapshot.syncedAt, style: .relative)) ago")
                    .foregroundStyle(Palette.goldText)
            } else if !mate.lastTime.isEmpty {
                Text(mate.lastTime)
                    .foregroundStyle(Palette.muted)
            } else {
                Text("Synced \(Text(snapshot.syncedAt, style: .relative)) ago")
                    .foregroundStyle(Palette.muted)
            }
        }
        .font(.system(size: 10.5))
        .lineLimit(1)
    }

    private func lastLine(_ mate: TeammateWidgetSnapshot.Teammate) -> String {
        guard let text = mate.lastText else { return "No messages yet" }
        return mate.lastFromMe ? "You: \(text)" : text
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "working": return Palette.green
        case "waiting", "handed": return Palette.goldText
        case "napping", "paused": return Color(activityHex: 0xFACC15)
        default: return Palette.sub
        }
    }

    private func note(icon: String, title: String, detail: String) -> some View {
        Group {
            switch family {
            case .accessoryInline:
                Label("Squall: \(title)", systemImage: icon)
            case .accessoryRectangular:
                VStack(alignment: .leading, spacing: 2) {
                    Label("Squall", systemImage: icon)
                        .font(.system(size: 13, weight: .semibold))
                    Text(title)
                        .font(.system(size: 12))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
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
    }
}
