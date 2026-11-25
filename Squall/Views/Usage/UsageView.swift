import SwiftUI

/// Plan usage: how much of your Claude plan the team has used, where the pace lands,
/// the switch that slows the team down to save usage, and the jobs each bot did today.
/// Everything comes from Squall on the computer, which reads it from Claude itself.
struct UsageView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var isWide: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                // Redraws every 30 seconds so "resets in" and "runs out in" keep counting down.
                TimelineView(.periodic(from: .now, by: 30)) { context in
                    content(now: context.date)
                }
                .padding(16)
                .readableColumn(isWide ? 1100 : Theme.readableWidth)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                store.refreshNow()
            }
        }
    }

    @ViewBuilder
    private func content(now: Date) -> some View {
        if let usage = store.usage {
            VStack(alignment: .leading, spacing: 14) {
                if isWide {
                    // iPad: the windows on the left, the switch and today on the right.
                    HStack(alignment: .top, spacing: 18) {
                        VStack(alignment: .leading, spacing: 14) {
                            windowsColumn(usage, now: now)
                        }
                        .frame(maxWidth: .infinity)
                        VStack(alignment: .leading, spacing: 14) {
                            settingsColumn(usage)
                        }
                        .frame(maxWidth: .infinity)
                    }
                } else {
                    windowsColumn(usage, now: now)
                    settingsColumn(usage)
                }
                footer(usage, now: now)
            }
        } else {
            OldDesktopCard()
        }
    }

    @ViewBuilder
    private func windowsColumn(_ usage: PlanUsage, now: Date) -> some View {
        if let main = usage.main {
            MainWindowCard(window: main, usage: usage, now: now)
            if !usage.others.isEmpty {
                SectionLabel(text: "Weekly")
                VStack(spacing: 14) {
                    ForEach(usage.others) { window in
                        WindowRow(window: window, now: now)
                    }
                }
                .padding(16)
                .glassCard(radius: 18)
            }
        } else {
            NoReadingsCard()
        }
    }

    @ViewBuilder
    private func settingsColumn(_ usage: PlanUsage) -> some View {
        SectionLabel(text: "Save usage")
        SaveUsageCard(usage: usage)
        SectionLabel(text: "Today")
        TodayCard(usage: usage)
    }

    private func footer(_ usage: PlanUsage, now: Date) -> some View {
        VStack(spacing: 4) {
            if let read = UsageText.read(usage, now: now) {
                Text(read)
            }
            if store.showingSaved, let synced = store.lastSynced {
                Text("Saved copy from \(synced.formatted(date: .omitted, time: .shortened)). Your computer isn't answering.")
            }
        }
        .font(.system(size: 12))
        .foregroundStyle(Theme.muted)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

// MARK: - The 5-hour window

private struct MainWindowCard: View {
    let window: PlanUsage.Window
    let usage: PlanUsage
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 18) {
                UsageRing(percent: window.percent, limit: usage.slowDown ? usage.limit : nil, pace: window.predicting ? nil : window.atReset)
                VStack(alignment: .leading, spacing: 6) {
                    Text(window.isFiveHour ? "5-hour limit" : window.label)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.textBright)
                    if let reset = UsageText.reset(window, now: now) {
                        Label(reset, systemImage: "clock")
                            .font(.system(size: 13.5, weight: .semibold))
                            .foregroundStyle(Theme.sub)
                    }
                    if let outlook = UsageText.outlook(window, now: now) {
                        Text(outlook)
                            .font(.system(size: 13))
                            .foregroundStyle(window.runsOutAt != nil ? Theme.redText : Theme.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            if let why = UsageText.slowDown(usage) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "tortoise.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Theme.goldBright)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("The team is slowing down")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.goldText)
                        Text(why)
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.gold.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.goldBright.opacity(0.35), lineWidth: 1))
            }
            if usage.overage {
                Label("Your plan is using extra usage past its limits.", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(Theme.redText)
            }
        }
        .padding(16)
        .glassCard(radius: 20, tint: 0x7C5CF6, strength: 0.1)
        .accessibilityElement(children: .combine)
    }
}

/// A weekly window: its name, a bar, how full it is, when it resets and where the pace lands.
private struct WindowRow: View {
    let window: PlanUsage.Window
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(window.label)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text("\(window.percent)%")
                    .font(.system(size: 14.5, weight: .bold))
                    .monospacedDigit()
                    .foregroundStyle(UsageStyle.text(UsageLevel.of(window.percent)))
            }
            UsageBar(percent: window.percent)
            HStack(spacing: 6) {
                if let reset = UsageText.reset(window, now: now) {
                    Text(reset)
                }
                if let outlook = UsageText.outlook(window, now: now) {
                    Text("· " + outlook)
                        .foregroundStyle(window.runsOutAt != nil ? Theme.redText : Theme.muted)
                }
            }
            .font(.system(size: 12))
            .foregroundStyle(Theme.muted)
            .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Save usage

private struct SaveUsageCard: View {
    @EnvironmentObject private var store: SquallStore
    let usage: PlanUsage

    /// 0 stands for Off.
    private static let choices: [(label: String, value: Int)] = PlanUsage.limitChoices.map { limit in
        (label: UsageText.limitLabel(limit), value: limit ?? 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SwitchRow(
                title: "Slow the team down to save usage",
                subtitle: "When usage is tight, bots keep turns short, skip extra work and don't wake sleeping teammates.",
                isOn: Binding(
                    get: { usage.slowDown },
                    set: { store.setSlowDown($0) }
                ),
                tint: store.accent
            )
            VStack(alignment: .leading, spacing: 8) {
                Text("Also slow down at")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                Text("A percent of the 5-hour window. Off slows down only when the pace would run out before it resets.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
                PillSegments(
                    options: Self.choices,
                    selection: Binding(
                        get: { usage.limit ?? 0 },
                        set: { store.setUsageLimit($0 == 0 ? nil : $0) }
                    )
                )
            }
            .disabled(!usage.slowDown)
            .opacity(usage.slowDown ? 1 : 0.45)
            if !store.isConnected {
                Text("Connect to your computer to change these.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
            }
        }
        .disabled(!store.isConnected || store.isBusy("usage.settings"))
        .padding(16)
        .glassCard(radius: 18)
    }
}

// MARK: - Today

private struct TodayCard: View {
    @EnvironmentObject private var store: SquallStore
    let usage: PlanUsage

    private struct Row: Identifiable {
        let bot: Bot
        let day: PlanUsage.BotDay
        var id: String { day.id }
    }

    /// Today's bots that are still on the team.
    private var rows: [Row] {
        usage.today.compactMap { day in
            store.bot(day.botID).map { Row(bot: $0, day: day) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if rows.isEmpty {
                Text("No bot jobs on your computer yet today.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.sub)
            } else {
                HStack {
                    Text("\(UsageText.jobs(usage.totalJobs)) · \(UsageText.duration(usage.totalSeconds)) of work")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    Spacer()
                }
                let longest = max(rows.map(\.day.seconds).max() ?? 1, 1)
                VStack(spacing: 10) {
                    ForEach(rows) { row in
                        Button {
                            store.openChat(row.bot.id)
                        } label: {
                            BotDayRow(bot: row.bot, day: row.day, share: Double(row.day.seconds) / Double(longest))
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens the chat with \(row.bot.name)")
                    }
                }
            }
            Text("Timed by Squall on your computer, from when a job starts to when it ends.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18)
    }
}

private struct BotDayRow: View {
    let bot: Bot
    let day: PlanUsage.BotDay
    /// This bot's time next to the busiest bot's, 0 to 1.
    let share: Double
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var grown = false

    var body: some View {
        HStack(spacing: 12) {
            Sphere(bot: bot, size: 34, glow: 0.3)
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(bot.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Spacer()
                    Text(UsageText.day(day))
                        .font(.system(size: 12.5, weight: .medium))
                        .monospacedDigit()
                        .foregroundStyle(Theme.sub)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.07))
                        Capsule()
                            .fill(LinearGradient(colors: [Color.shade(bot.hex, towardWhite: true, 0.3), bot.color],
                                                 startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(6, geo.size.width * (grown || reduceMotion ? min(max(share, 0), 1) : 0)))
                            .shadow(color: bot.color.opacity(0.45), radius: 4)
                    }
                }
                .frame(height: 6)
                .animation(.spring(response: 0.8, dampingFraction: 0.85), value: grown)
                .onAppear { grown = true }
            }
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(bot.name): \(UsageText.day(day))")
    }
}

// MARK: - Empty states

/// Squall on the computer hasn't read any usage yet.
private struct NoReadingsCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("No usage yet", systemImage: "gauge.with.dots.needle.0percent")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textBright)
            Text("Usage shows up after a bot's next reply: every Claude run on your computer reports your plan's 5-hour and weekly use.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 20)
    }
}

/// The computer is connected but its Squall is too old to send usage.
private struct OldDesktopCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Update Squall on your computer", systemImage: "arrow.down.circle")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.textBright)
            Text("This Squall doesn't send plan usage to the phone yet. Once it's updated, your 5-hour and weekly use show up here.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 20)
    }
}

// MARK: - Pieces

/// Colors for how full a window is.
enum UsageStyle {
    static func colors(_ level: UsageLevel) -> [Color] {
        switch level {
        case .ok: return [Color(hex: 0x3FD0B0), Color(hex: 0x3A8DE0)]
        case .warm: return [Theme.yellow, Color(hex: 0xF0913A)]
        case .hot: return [Color(hex: 0xF0913A), Theme.red]
        }
    }

    static func text(_ level: UsageLevel) -> Color {
        switch level {
        case .ok: return Theme.text
        case .warm: return Theme.goldText
        case .hot: return Theme.redText
        }
    }
}

/// A ring that fills up with the percent used, with a gold tick at your limit.
/// It sweeps in when it first shows, glows at its tip, and can show where the
/// pace lands at reset as a faint dashed arc.
struct UsageRing: View {
    let percent: Int
    var limit: Int? = nil
    var size: CGFloat = 116
    var line: CGFloat = 12
    /// Where the pace lands when the window resets, drawn faintly past the fill.
    var pace: Int? = nil
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        let level = UsageLevel.of(percent)
        let fraction = CGFloat(min(max(percent, 0), 100)) / 100
        let drawn = shown || reduceMotion ? fraction : 0
        let colors = UsageStyle.colors(level)
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.08), lineWidth: line)
            if size >= 80 {
                // Little ticks every 10%, like a gauge.
                ForEach(0..<10, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(index == 0 ? 0.3 : 0.14))
                        .frame(width: 1.5, height: line * 0.45)
                        .offset(y: -(size / 2 - line - 6))
                        .rotationEffect(.degrees(Double(index) * 36))
                }
            }
            if let pace, pace > percent {
                let end = CGFloat(min(pace, 100)) / 100
                Circle()
                    .trim(from: drawn, to: shown || reduceMotion ? end : 0)
                    .stroke(colors.last?.opacity(0.35) ?? Color.white.opacity(0.2),
                            style: StrokeStyle(lineWidth: line * 0.45, lineCap: .round, dash: [2, 5]))
                    .rotationEffect(.degrees(-90))
            }
            Circle()
                .trim(from: 0, to: drawn)
                .stroke(
                    AngularGradient(colors: [colors.first ?? .white, colors.last ?? .white, colors.first ?? .white],
                                    center: .center, startAngle: .degrees(0), endAngle: .degrees(360)),
                    style: StrokeStyle(lineWidth: line, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: (colors.last ?? .clear).opacity(0.45), radius: line * 0.6)
            if let limit {
                let spot = CGFloat(limit) / 100
                Circle()
                    .trim(from: max(spot - 0.005, 0), to: min(spot + 0.005, 1))
                    .stroke(Theme.goldBright, style: StrokeStyle(lineWidth: line + 6, lineCap: .butt))
                    .rotationEffect(.degrees(-90))
            }
            VStack(spacing: 0) {
                Text("\(shown || reduceMotion ? percent : 0)%")
                    .font(.system(size: size * 0.24, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(Theme.textBright)
                    .contentTransition(.numericText(value: Double(shown || reduceMotion ? percent : 0)))
                if size >= 80 {
                    Text("used")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.sub)
                }
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.9, dampingFraction: 0.85), value: shown)
        .animation(.easeOut(duration: 0.5), value: percent)
        .onAppear { shown = true }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(percent) percent used" + (limit.map { ", limit \($0) percent" } ?? ""))
    }
}

/// A thin bar that fills up with the percent used. It grows in when it first shows,
/// with a soft shine on the filled part.
struct UsageBar: View {
    let percent: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var shown = false

    var body: some View {
        let fraction = CGFloat(min(max(percent, 0), 100)) / 100
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: UsageStyle.colors(UsageLevel.of(percent)), startPoint: .leading, endPoint: .trailing))
                    .overlay(
                        Capsule().fill(LinearGradient(colors: [Color.white.opacity(0.28), Color.white.opacity(0)],
                                                      startPoint: .top, endPoint: .bottom))
                    )
                    .frame(width: geo.size.width * (shown || reduceMotion ? fraction : 0))
                    .shadow(color: (UsageStyle.colors(UsageLevel.of(percent)).last ?? .clear).opacity(0.4), radius: 4)
            }
        }
        .frame(height: 7)
        .animation(.spring(response: 0.8, dampingFraction: 0.85), value: shown)
        .animation(.easeOut(duration: 0.5), value: percent)
        .onAppear { shown = true }
    }
}

/// The small card on the Team tab: the 5-hour window at a glance. Tap it for Plan usage.
struct UsageSummaryCard: View {
    @EnvironmentObject private var store: SquallStore
    let usage: PlanUsage

    var body: some View {
        Button {
            store.path.append(.usage)
        } label: {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                HStack(spacing: 12) {
                    UsageRing(percent: usage.main?.percent ?? 0, limit: usage.slowDown ? usage.limit : nil, size: 44, line: 5)
                        .opacity(usage.main == nil ? 0.4 : 1)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Plan usage")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textBright)
                        Text(UsageText.summary(usage, now: context.date))
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.sub)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if usage.throttled {
                        Label("Slowing down", systemImage: "tortoise.fill")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(Theme.goldText)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(Theme.gold.opacity(0.14)))
                            .overlay(Capsule().stroke(Theme.goldBright.opacity(0.4), lineWidth: 1))
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(Theme.muted)
                }
                .padding(12)
                .glassCard(radius: 18)
                .contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Plan usage, \(UsageText.summary(usage))" + (usage.throttled ? ", slowing down" : ""))
    }
}
