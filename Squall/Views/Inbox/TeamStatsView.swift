import Charts
import SwiftUI

/// Team stats: how much the team did, when, who did it, and how fast each teammate answers you.
/// Built from Team history, so it only counts what's in the chats, inbox, hand offs and jobs right now.
struct TeamStatsView: View {
    /// Closes Team history and opens a teammate's chat.
    let openChat: (String) -> Void

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var feed = HistoryFeed.shared

    @State private var range: TeamStats.Range = .week
    @State private var all: [TeamHistory.Entry] = []

    var body: some View {
        let report = TeamStats.report(all, range: range)
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Picker("Range", selection: $range) {
                        ForEach(TeamStats.Range.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    if report.isEmpty {
                        nothing
                    } else {
                        totals(report)
                        chartCard(report)
                        replyCard(report)
                        peopleCard(report)
                        Text(footnote(report))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(16)
                .readableColumn()
            }
            .scrollIndicators(.hidden)
        }
        .animation(.easeOut(duration: 0.25), value: range)
        .navigationTitle("Team stats")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { all = feed.entries() }
        .onChange(of: feed.stamp) { _, _ in all = feed.entries() }
    }

    // MARK: - Cards

    private func totals(_ report: TeamStats.Report) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            tile("\(report.sent)", "You sent", Theme.text, icon: "arrow.up.message.fill")
            tile("\(report.replies)", "Replies", Theme.text, icon: "bubble.left.fill")
            tile("\(report.done)", "Done", Theme.greenText, icon: "checkmark.circle.fill")
            tile("\(report.problems)", "Problems", report.problems > 0 ? Theme.redText : Theme.text, icon: "exclamationmark.triangle.fill")
            tile("\(report.asks)", "Asked you", Theme.goldText, icon: "exclamationmark.bubble.fill")
            tile("\(report.handoffs)", "Hand offs", Theme.commandText, icon: "arrow.triangle.swap")
        }
    }

    private func tile(_ value: String, _ label: String, _ color: Color, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color.opacity(0.8))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.system(size: 11.5))
                .foregroundStyle(Theme.sub)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .glassCard(radius: 16)
    }

    private func chartCard(_ report: TeamStats.Report) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                label(report.byHour ? "TODAY BY THE HOUR" : "BY DAY")
                Spacer()
                if let hour = report.busiestHour {
                    Text("Busiest at \(TeamHistory.hourText(hour))")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.sub)
                }
            }
            Chart {
                ForEach(report.bars) { bar in
                    BarMark(x: .value("When", bar.start, unit: report.byHour ? .hour : .day),
                            y: .value("Count", bar.chats))
                        .foregroundStyle(by: .value("Kind", "Chats"))
                    BarMark(x: .value("When", bar.start, unit: report.byHour ? .hour : .day),
                            y: .value("Count", bar.done))
                        .foregroundStyle(by: .value("Kind", "Done"))
                    BarMark(x: .value("When", bar.start, unit: report.byHour ? .hour : .day),
                            y: .value("Count", bar.problems))
                        .foregroundStyle(by: .value("Kind", "Problems"))
                }
            }
            .chartForegroundStyleScale([
                "Chats": store.accent,
                "Done": Theme.green,
                "Problems": Theme.redSoft,
            ])
            .chartLegend(position: .bottom, alignment: .leading)
            .chartXAxis {
                if report.byHour {
                    AxisMarks(values: .stride(by: .hour, count: 6)) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel(format: .dateTime.hour())
                            .foregroundStyle(Theme.muted)
                    }
                } else {
                    AxisMarks(values: .stride(by: .day, count: report.bars.count > 7 ? 2 : 1)) { _ in
                        AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                        AxisValueLabel(format: report.bars.count > 7 ? Date.FormatStyle.dateTime.day() : Date.FormatStyle.dateTime.weekday(.abbreviated))
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.white.opacity(0.06))
                    AxisValueLabel().foregroundStyle(Theme.muted)
                }
            }
            .frame(height: 190)
            .accessibilityLabel(chartSummary(report))
        }
        .padding(16)
        .glassCard(radius: 20, strength: 0.12)
    }

    @ViewBuilder
    private func replyCard(_ report: TeamStats.Report) -> some View {
        if let time = report.replyTime {
            HStack(spacing: 14) {
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(store.accent)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(store.accent.opacity(0.16)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(TeamStats.duration(time))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textBright)
                    Text("Usual time to answer you, from \(report.timedReplies) \(report.timedReplies == 1 ? "reply" : "replies")")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.sub)
                }
                Spacer(minLength: 0)
            }
            .padding(14)
            .glassCard(radius: 18)
        }
    }

    private func peopleCard(_ report: TeamStats.Report) -> some View {
        let top = max(report.people.map(\.total).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 12) {
            label("WHO DID WHAT")
            if report.people.isEmpty {
                Text("Only your own messages so far.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.sub)
            }
            ForEach(report.people) { person in
                personRow(person, top: top)
            }
        }
        .padding(16)
        .glassCard(radius: 20)
    }

    private func personRow(_ person: TeamStats.Person, top: Int) -> some View {
        let bot = store.bot(person.id) ?? store.bots.first { $0.name.lowercased() == person.id.lowercased() }
        let name = bot?.name ?? person.id
        let hex = bot?.hex ?? Theme.goldHex
        return Button {
            guard let bot else { return }
            openChat(bot.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    Sphere(hex: hex, letter: String(name.prefix(1)).uppercased(), size: 30)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(name)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(Theme.textBright)
                        Text(detail(person))
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.sub)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 4)
                    Text("\(person.total)")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.text)
                        .monospacedDigit()
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [Color(hex: hex), Color(hex: hex).opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(8, geo.size.width * CGFloat(person.total) / CGFloat(top)))
                    }
                }
                .frame(height: 6)
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(bot == nil)
        .accessibilityHint(bot == nil ? "" : "Opens the chat")
    }

    private var nothing: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.bar")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.sub)
            Text(range == .today ? "Nothing yet today" : "Nothing to count yet")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textBright)
            Text(store.isConnected
                 ? "Stats fill in as your team chats and works."
                 : "Connect to your computer to see your team's stats.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 50)
        .frame(maxWidth: .infinity)
    }

    private func label(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .bold))
            .tracking(1)
            .foregroundStyle(Theme.label)
    }

    // MARK: - Words

    /// "12 replies · 3 done · answers in 2 min".
    private func detail(_ person: TeamStats.Person) -> String {
        var parts: [String] = []
        func add(_ count: Int, _ one: String, _ many: String) {
            if count > 0 { parts.append("\(count) \(count == 1 ? one : many)") }
        }
        add(person.replies, "reply", "replies")
        add(person.done, "done", "done")
        add(person.started, "job started", "jobs started")
        add(person.problems, "problem", "problems")
        add(person.asks, "ask", "asks")
        add(person.handoffs, "hand off", "hand offs")
        if let time = person.replyTime { parts.append("answers in \(TeamStats.duration(time))") }
        return parts.joined(separator: " · ")
    }

    private func footnote(_ report: TeamStats.Report) -> String {
        var text = "Counted from what's in your chats, Inbox, hand offs and jobs now"
        if let since = report.since {
            text += ", going back to \(since.formatted(date: .abbreviated, time: .shortened))"
        }
        return text + ". Clearing a chat takes its messages out of the stats."
    }

    private func chartSummary(_ report: TeamStats.Report) -> String {
        let chats = report.bars.reduce(0) { $0 + $1.chats }
        let done = report.bars.reduce(0) { $0 + $1.done }
        let problems = report.bars.reduce(0) { $0 + $1.problems }
        return "\(chats) chat messages, \(done) done, \(problems) problems"
    }
}
