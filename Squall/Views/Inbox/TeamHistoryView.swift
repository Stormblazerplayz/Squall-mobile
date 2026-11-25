import SwiftUI

/// The clock button in the Inbox header that opens Team history.
struct HistoryButton: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    @State private var show = false

    var body: some View {
        Button {
            show = true
        } label: {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Theme.text)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.field))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Team history")
        .sheet(isPresented: $show) {
            TeamHistoryView()
                .lockCover()
                .environmentObject(store)
                .environmentObject(lock)
        }
    }
}

/// Everything the team did, newest first: messages, asks, problems, finished work, hand offs and jobs started.
struct TeamHistoryView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var feed = HistoryFeed.shared

    @State private var filter: TeamHistory.Filter = .all
    @State private var who: String?
    @State private var words = ""
    @State private var all: [TeamHistory.Entry] = []
    @State private var shown = 150

    var body: some View {
        let picked = TeamHistory.filter(all, by: filter, who: who, words: words)
        let days = TeamHistory.days(Array(picked.prefix(shown)))
        NavigationStack {
            ZStack {
                GlowBackground()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14, pinnedViews: [.sectionHeaders]) {
                        TodayCard(today: TeamHistory.today(all), accent: store.accent)
                        searchField
                        filterChips
                        peopleRow
                        if days.isEmpty {
                            nothing
                        }
                        ForEach(days) { day in
                            Section {
                                VStack(spacing: 0) {
                                    ForEach(Array(day.entries.enumerated()), id: \.element.id) { index, entry in
                                        HistoryRow(entry: entry, isLast: index == day.entries.count - 1) {
                                            open(entry)
                                        }
                                    }
                                }
                                .padding(.vertical, 6)
                                .glassCard(radius: 18)
                            } header: {
                                Text(day.title)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(Theme.label)
                                    .padding(.vertical, 6)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Theme.background.opacity(0.92))
                            }
                        }
                        if picked.count > shown {
                            Button("Show more") { shown += 150 }
                                .buttonStyle(GhostButtonStyle(height: 40))
                        }
                    }
                    .padding(16)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Team history")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        TeamStatsView { chatID in openChat(chatID) }
                    } label: {
                        Label("Stats", systemImage: "chart.bar.xaxis")
                    }
                    .accessibilityLabel("Team stats")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { all = feed.entries() }
        .onChange(of: feed.stamp) { _, _ in all = feed.entries() }
        .onChange(of: filter) { _, _ in shown = 150 }
        .onChange(of: who) { _, _ in shown = 150 }
    }

    // MARK: - Parts

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Theme.muted)
            TextField("", text: $words, prompt: Text("Search history").foregroundColor(Theme.muted))
                .font(.system(size: 15))
                .foregroundColor(Theme.text)
                .submitLabel(.search)
                .autocorrectionDisabled()
            if !words.isEmpty {
                Button {
                    words = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TeamHistory.Filter.allCases) { option in
                    let count = TeamHistory.filter(all, by: option, who: who).count
                    let on = option == filter
                    Button {
                        filter = option
                    } label: {
                        HStack(spacing: 6) {
                            Text(option.label)
                            if count > 0 {
                                Text("\(count)")
                                    .font(.system(size: 11.5, weight: .bold))
                                    .foregroundColor(on ? .white.opacity(0.85) : Theme.muted)
                            }
                        }
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundColor(on ? .white : Theme.text)
                        .padding(.horizontal, 12)
                        .frame(height: 34)
                        .background(Capsule().fill(on ? store.accent : Theme.field))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var peopleRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                personButton(id: nil) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.text)
                        .frame(width: 38, height: 38)
                        .background(Circle().fill(Theme.field))
                }
                ForEach(store.bots) { bot in
                    personButton(id: bot.id) {
                        Sphere(bot: bot, size: 38, glow: 0.2)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    private func personButton<Icon: View>(id: String?, @ViewBuilder icon: () -> Icon) -> some View {
        let on = who == id
        let name = id.flatMap { store.bot($0)?.name } ?? "Everyone"
        return Button {
            withAnimation(.easeOut(duration: 0.2)) { who = id }
        } label: {
            VStack(spacing: 5) {
                icon()
                    .overlay(Circle().stroke(on ? store.accent : .clear, lineWidth: 2).padding(-3))
                Text(name)
                    .font(.system(size: 11, weight: on ? .bold : .medium))
                    .foregroundColor(on ? Theme.textBright : Theme.sub)
                    .lineLimit(1)
                    .frame(maxWidth: 64)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(id == nil ? "Everyone" : name)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private var nothing: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.system(size: 28))
                .foregroundColor(Theme.muted)
            Text(all.isEmpty ? "Nothing yet. What your team does shows up here." : "Nothing matches.")
                .font(.system(size: 14))
                .foregroundColor(Theme.sub)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 30)
    }

    private func open(_ entry: TeamHistory.Entry) {
        guard let chatID = entry.chatID else { return }
        openChat(chatID)
    }

    private func openChat(_ chatID: String) {
        guard store.bot(chatID) != nil else { return }
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            store.openChat(chatID)
        }
    }
}

/// Today at a glance: four counts and a bar for each hour.
private struct TodayCard: View {
    let today: TeamHistory.Today
    let accent: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("TODAY")
                    .font(.system(size: 11.5, weight: .bold))
                    .tracking(1)
                    .foregroundColor(Theme.label)
                Spacer()
                if let hour = today.busiestHour {
                    Text("Busiest at \(TeamHistory.hourText(hour))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Theme.sub)
                }
            }
            HStack(spacing: 8) {
                tile("\(today.messages)", "Messages", Theme.text)
                tile("\(today.done)", "Done", Theme.greenText)
                tile("\(today.problems)", "Problems", today.problems > 0 ? Theme.redText : Theme.text)
                tile("\(today.handoffs)", "Hand offs", Theme.commandText)
            }
            HourBars(hours: today.hours, accent: accent)
        }
        .padding(16)
        .glassCard(radius: 20, strength: 0.12)
    }

    private func tile(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(color)
                .monospacedDigit()
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.sub)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
    }
}

private struct HourBars: View {
    let hours: [Int]
    let accent: Color

    var body: some View {
        let top = max(hours.max() ?? 0, 1)
        let current = Calendar.current.component(.hour, from: Date())
        VStack(spacing: 4) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { hour in
                    let value = hour < hours.count ? hours[hour] : 0
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(hour == current ? accent : (value > 0 ? accent.opacity(0.45) : Color.white.opacity(0.07)))
                        .frame(height: value > 0 ? max(4, 46 * CGFloat(value) / CGFloat(top)) : 3)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 46, alignment: .bottom)
            HStack {
                Text("12 AM")
                Spacer()
                Text("6 AM")
                Spacer()
                Text("12 PM")
                Spacer()
                Text("6 PM")
                Spacer()
                Text("Now")
                    .opacity(0)
            }
            .font(.system(size: 10))
            .foregroundColor(Theme.muted)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Activity by hour today")
    }
}

private struct HistoryRow: View {
    @EnvironmentObject private var store: SquallStore
    let entry: TeamHistory.Entry
    let isLast: Bool
    var onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 30, height: 30)
                    Image(systemName: entry.kind.icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(tint)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(headline)
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundColor(Theme.textBright)
                            .lineLimit(1)
                        Spacer(minLength: 6)
                        Text(TeamHistory.clock(entry.at))
                            .font(.system(size: 11.5))
                            .foregroundColor(Theme.muted)
                            .monospacedDigit()
                    }
                    Text(entry.text)
                        .font(.system(size: 13.5))
                        .foregroundColor(Theme.text)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .padding(.bottom, isLast ? 4 : 14)
            }
            .background(alignment: .topLeading) {
                // The line that joins this step to the next one.
                if !isLast {
                    Rectangle()
                        .fill(Theme.cardBorder)
                        .frame(width: 2)
                        .padding(.leading, 14)
                        .padding(.top, 32)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var tint: Color {
        switch entry.kind {
        case .message: return store.accent
        case .reply: return Theme.grayText
        case .ask: return Theme.goldText
        case .problem: return Theme.redSoft
        case .done: return Theme.green
        case .handoff: return Theme.commandText
        case .started: return Theme.greenText
        }
    }

    private func name(_ id: String?) -> String {
        guard let id, !id.isEmpty else { return "A teammate" }
        if id == ChatMessage.meID { return "You" }
        if let bot = store.bot(id) { return bot.name }
        if let group = store.group(id) { return group.name }
        return id
    }

    private var headline: String {
        let place = entry.chatID.flatMap { store.group($0)?.name }.map { " in \($0)" } ?? ""
        switch entry.kind {
        case .message: return "You to \(name(entry.to))"
        case .reply: return name(entry.who) + place
        case .ask: return "\(name(entry.who)) needs you"
        case .problem: return "\(name(entry.who)) hit a problem" + place
        case .done: return "\(name(entry.who)) finished"
        case .handoff: return "\(name(entry.who)) to \(name(entry.to))"
        case .started: return "\(name(entry.who)) started a job"
        }
    }
}
