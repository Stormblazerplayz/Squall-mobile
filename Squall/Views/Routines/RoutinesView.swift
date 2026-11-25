import SwiftUI

/// Routines that wake a teammate up on a schedule: what's up next, today's runs on a timeline, and every routine as a card
/// you can tap to change.
struct RoutinesView: View {
    @EnvironmentObject private var store: SquallStore

    @Environment(\.horizontalSizeClass) private var sizeClass

    @State private var editing: Routine?
    @State private var deleting: Routine?

    private var isWide: Bool { sizeClass == .regular }

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Routines")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textBright)
                        Spacer()
                        if let routine = store.routines.first(where: { $0.run != nil }) {
                            // A routine running right now, counting up on the Lock Screen.
                            LockScreenButton(kind: .routine, compact: true) {
                                LiveActivities.shared.startRoutine(routine, bot: store.bot(routine.botID))
                            }
                        }
                        Button {
                            store.path.append(.newRoutine)
                        } label: {
                            Label("New", systemImage: "plus")
                        }
                        .buttonStyle(GhostButtonStyle(height: 38, expand: false, fontSize: 14, sidePadding: 14))
                    }
                    Text("A routine wakes a teammate on a schedule to check in or pick up work. Tap one to change it.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.sub)

                    if store.routines.isEmpty {
                        emptyState
                    } else {
                        // The countdown and the "now" line move on their own.
                        TimelineView(.periodic(from: .now, by: 30)) { context in
                            VStack(alignment: .leading, spacing: 14) {
                                if isWide {
                                    HStack(alignment: .top, spacing: 12) {
                                        UpNextCard(routines: store.routines, now: context.date)
                                        RoutinesTodayCard(routines: store.routines, now: context.date)
                                    }
                                } else {
                                    UpNextCard(routines: store.routines, now: context.date)
                                    RoutinesTodayCard(routines: store.routines, now: context.date)
                                }
                            }
                        }
                        SectionLabel(text: "All routines (\(store.routines.count))")
                            .padding(.top, 4)
                        // iPad: routines sit side by side in a grid that fills the screen.
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: isWide ? 360 : 280), spacing: 12)],
                            spacing: 12
                        ) {
                            ForEach(store.routines) { routine in
                                RoutineCard(
                                    routine: routine,
                                    onEdit: { editing = routine },
                                    onDelete: { deleting = routine }
                                )
                            }
                        }
                    }
                }
                .padding(16)
                .readableColumn(isWide ? Theme.wideWidth : Theme.readableWidth)
            }
            .scrollIndicators(.hidden)
        }
        .sheet(item: $editing) { routine in
            NavigationStack {
                RoutineEditorView(existing: routine) { editing = nil }
                    .navigationTitle("Edit routine")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarColorScheme(.dark, for: .navigationBar)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") { editing = nil }
                        }
                    }
            }
            .environmentObject(store)
            .presentationBackground(Theme.background)
        }
        .confirmationDialog(
            "Delete this routine?",
            isPresented: Binding(get: { deleting != nil }, set: { if !$0 { deleting = nil } }),
            titleVisibility: .visible,
            presenting: deleting
        ) { routine in
            Button("Delete routine", role: .destructive) {
                store.deleteRoutine(routine.id)
                deleting = nil
            }
            Button("Keep it", role: .cancel) { deleting = nil }
        } message: { routine in
            Text("\(store.bot(routine.botID)?.name ?? "The bot") won't wake up for it any more.")
        }
    }

    private var emptyState: some View {
        EmptyStateCard(
            icon: "clock.badge",
            title: "No routines yet",
            text: "A routine wakes a teammate on a schedule, like checking for bugs every morning or tidying up on Fridays.",
            buttonTitle: "New routine",
            tint: Theme.goldBright,
            action: { store.path.append(.newRoutine) }
        )
        .padding(.top, 12)
    }
}

// MARK: - Up next

/// The routine that runs soonest, with a live countdown.
private struct UpNextCard: View {
    @EnvironmentObject private var store: SquallStore
    let routines: [Routine]
    let now: Date

    private var next: (routine: Routine, date: Date)? {
        routines
            .compactMap { routine in routine.nextRunDate(now: now).map { (routine: routine, date: $0) } }
            .min { $0.date < $1.date }
    }

    var body: some View {
        if let next {
            let bot = store.bot(next.routine.botID)
            let tint = bot.map { Color(hex: $0.hex) } ?? store.accent
            let countdown = Routine.countdown(to: next.date, now: now)
            let when = countdown ?? next.routine.nextRunText.replacingOccurrences(of: "Next run: ", with: "")
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    PulseDot(color: tint)
                    Text("UP NEXT")
                        .font(.system(size: 11.5, weight: .heavy))
                        .tracking(1.1)
                        .foregroundStyle(tint)
                    Spacer()
                    Text(TimeText.time(minutes: next.routine.minutes))
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(Theme.sub)
                }
                HStack(alignment: .center, spacing: 14) {
                    if let bot {
                        Sphere(bot: bot, size: 52, glow: 0.65)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text(when)
                            .font(.system(size: countdown == nil ? 20 : 26, weight: .bold, design: .rounded))
                            .foregroundStyle(Theme.textBright)
                            .monospacedDigit()
                            .contentTransition(.numericText())
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text("\(bot?.name ?? "A teammate") wakes up")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.sub)
                    }
                    Spacer(minLength: 0)
                }
                Text(next.routine.task)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
                if next.routine.runsLaterToday(now: now) {
                    Button {
                        store.skipRoutine(next.routine.id)
                    } label: {
                        Label("Skip today", systemImage: "forward.end")
                    }
                    .buttonStyle(GhostButtonStyle(height: 36, expand: false, fontSize: 13, sidePadding: 12))
                    .disabled(store.isBusy("routine.skip"))
                    .accessibilityLabel("Skip today's run")
                }
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 22, tint: bot?.hex, strength: 0.2)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Up next: \(bot?.name ?? "a teammate"), \(when). \(next.routine.task)")
        } else {
            HStack(spacing: 12) {
                Image(systemName: "moon.zzz.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.sub)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Nothing coming up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                    Text("Every routine is off. Turn one on to wake a teammate.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)
                }
                Spacer(minLength: 0)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 22)
        }
    }
}

/// A soft dot that breathes, for "this is coming up".
private struct PulseDot: View {
    let color: Color
    @State private var on = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .background(
                Circle()
                    .fill(color.opacity(0.45))
                    .scaleEffect(on && !reduceMotion ? 2.4 : 1)
                    .opacity(on && !reduceMotion ? 0 : 0.8)
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeOut(duration: 1.6).repeatForever(autoreverses: false)) { on = true }
            }
            .accessibilityHidden(true)
    }
}

// MARK: - Today

/// Today's runs on a 24-hour line, with a "now" marker: done runs are dim, the ones still to come glow in their bot's color.
private struct RoutinesTodayCard: View {
    @EnvironmentObject private var store: SquallStore
    let routines: [Routine]
    let now: Date

    private var today: Int { Routine.todayIndex(now) }
    private var nowMinutes: Int { Routine.minutesNow(now) }

    /// Routines that are on and run on today's weekday, by time.
    private var todays: [Routine] {
        routines
            .filter { $0.isOn && $0.days.count == 7 && $0.days[today] }
            .sorted { $0.minutes < $1.minutes }
    }

    private func isDone(_ routine: Routine) -> Bool {
        routine.isDoneToday(now: now) || routine.minutes <= nowMinutes
    }

    var body: some View {
        let list = todays
        let left = list.filter { !isDone($0) }.count
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("Today")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Text(Routine.dayFull[today])
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
                Spacer()
                Text(list.isEmpty ? "No runs" : left == 0 ? "All done" : "\(left) to go")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(left == 0 && !list.isEmpty ? Theme.greenText : Theme.sub)
            }
            track(list)
            if list.isEmpty {
                Text("No routine runs today.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
            } else {
                VStack(spacing: 6) {
                    ForEach(list) { routine in
                        runRow(routine)
                    }
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 22)
    }

    private func track(_ list: [Routine]) -> some View {
        GeometryReader { geo in
            let width = max(geo.size.width, 1)
            ZStack(alignment: .topLeading) {
                // the day, with the part that's gone shaded
                Capsule()
                    .fill(Theme.field)
                    .frame(width: width, height: 8)
                    .offset(y: 11)
                Capsule()
                    .fill(LinearGradient(colors: [store.accent.opacity(0.15), store.accent.opacity(0.45)], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(8, xFor(nowMinutes, width)), height: 8)
                    .offset(y: 11)
                // the runs
                ForEach(list) { routine in
                    dot(for: routine)
                        .position(x: min(max(xFor(routine.minutes, width), 7), width - 7), y: 15)
                }
                // now
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.textBright)
                    .frame(width: 2, height: 22)
                    .position(x: min(max(xFor(nowMinutes, width), 1), width - 1), y: 15)
                // hours
                ForEach([0, 6, 12, 18], id: \.self) { hour in
                    Text(hourLabel(hour))
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                        .fixedSize()
                        .position(x: min(max(xFor(hour * 60, width) + 14, 14), width - 14), y: 38)
                }
            }
        }
        .frame(height: 46)
        .accessibilityElement()
        .accessibilityLabel("Today's runs: \(list.count). It's \(TimeText.time(minutes: nowMinutes)).")
    }

    private func xFor(_ minutes: Int, _ width: CGFloat) -> CGFloat {
        CGFloat(minutes) / CGFloat(24 * 60) * width
    }

    private func dot(for routine: Routine) -> some View {
        let color = store.bot(routine.botID).map { Color(hex: $0.hex) } ?? store.accent
        let done = isDone(routine)
        let size: CGFloat = done ? 10 : 14
        return Circle()
            .fill(done ? Theme.muted.opacity(0.6) : color)
            .frame(width: size, height: size)
            .overlay(Circle().stroke(Theme.background, lineWidth: 2))
            .shadow(color: done ? Color.clear : color.opacity(0.8), radius: 6)
    }

    private func hourLabel(_ hour: Int) -> String {
        switch hour {
        case 0: return "12 AM"
        case 12: return "12 PM"
        default: return hour < 12 ? "\(hour) AM" : "\(hour - 12) PM"
        }
    }

    private func runRow(_ routine: Routine) -> some View {
        let bot = store.bot(routine.botID)
        let done = isDone(routine)
        let skipped = routine.isDoneToday(now: now) && routine.minutes > nowMinutes
        return HStack(spacing: 10) {
            Text(TimeText.time(minutes: routine.minutes))
                .font(.system(size: 12.5, weight: .semibold).monospacedDigit())
                .foregroundStyle(done ? Theme.muted : Theme.text)
                .frame(width: 70, alignment: .leading)
            Circle()
                .fill(bot.map { Color(hex: $0.hex) } ?? store.accent)
                .frame(width: 8, height: 8)
                .opacity(done ? 0.5 : 1)
            Text(bot?.name ?? "Teammate")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(done ? Theme.muted : Theme.textBright)
            Text(routine.task)
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
                .lineLimit(1)
            Spacer(minLength: 4)
            if routine.run != nil {
                Text("Running")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Theme.greenText)
            } else if done {
                Image(systemName: skipped ? "forward.end.fill" : "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.muted)
                    .accessibilityLabel(skipped ? "Skipped" : "Done")
            }
        }
    }
}

// MARK: - A routine

private struct RoutineCard: View {
    @EnvironmentObject private var store: SquallStore
    let routine: Routine
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let bot = store.bot(routine.botID)
        let tint = bot.map { Color(hex: $0.hex) } ?? store.accent
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                if let bot {
                    Sphere(bot: bot, size: 40, glow: routine.isOn ? 0.45 : 0.1)
                        .saturation(routine.isOn ? 1 : 0.2)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(bot?.name ?? "Teammate")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Theme.textBright)
                        statusChip
                    }
                    Text(routine.task)
                        .font(.system(size: 13.5))
                        .foregroundStyle(routine.isOn ? Theme.text : Theme.muted)
                        .lineLimit(3)
                }
                Spacer(minLength: 0)
                Toggle("", isOn: Binding(
                    get: { routine.isOn },
                    set: { store.setRoutine(routine.id, isOn: $0) }
                ))
                .labelsHidden()
                .tint(store.accent)
                .accessibilityLabel("Turn on \(bot?.name ?? "this") routine")
            }
            HStack(spacing: 10) {
                WeekDots(days: routine.days, tint: tint, isOn: routine.isOn)
                Spacer(minLength: 4)
                Text(TimeText.time(minutes: routine.minutes))
                    .font(.system(size: 15, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(routine.isOn ? Theme.textBright : Theme.muted)
                menu
            }
            if let run = routine.run, run.total > 0 {
                ProgressView(value: Double(run.done), total: Double(run.total)) {
                    Text("\(run.label) · \(run.done) of \(run.total)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                }
                .tint(store.accent)
            }
        }
        .padding(14)
        .glassCard(radius: 18, tint: routine.isOn ? bot?.hex : nil, strength: 0.1)
        .opacity(routine.isOn ? 1 : 0.82)
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(perform: onEdit)
        .accessibilityAction(named: "Edit routine") { onEdit() }
        .contextMenu {
            Button("Edit routine", systemImage: "pencil", action: onEdit)
            if routine.runsLaterToday() {
                Button("Skip today", systemImage: "forward.end") { store.skipRoutine(routine.id) }
            }
            Button("Delete routine", systemImage: "trash", role: .destructive, action: onDelete)
        }
    }

    @ViewBuilder
    private var statusChip: some View {
        if routine.run != nil {
            chip("Running", color: Theme.greenText)
        } else if !routine.isOn {
            chip("Off", color: Theme.muted)
        } else if routine.days.count == 7, routine.days[Routine.todayIndex(Date())], routine.isDoneToday() {
            chip("Done today", color: Theme.sub)
        } else {
            chip(routine.nextRunText.replacingOccurrences(of: "Next run: ", with: ""), color: Theme.greenText)
        }
    }

    private func chip(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
    }

    private var menu: some View {
        Menu {
            Button("Edit routine", systemImage: "pencil", action: onEdit)
            if routine.runsLaterToday() {
                Button("Skip today", systemImage: "forward.end") { store.skipRoutine(routine.id) }
            }
            Button(routine.isOn ? "Turn off" : "Turn on", systemImage: routine.isOn ? "pause.circle" : "play.circle") {
                store.setRoutine(routine.id, isOn: !routine.isOn)
            }
            Button("Delete routine", systemImage: "trash", role: .destructive, action: onDelete)
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(Theme.sub)
                .frame(width: 36, height: 36)
                .contentShape(Rectangle())
        }
        .accessibilityLabel("More for this routine")
    }
}

/// M T W T F S S, lit up on the routine's days, with a ring around today.
private struct WeekDots: View {
    let days: [Bool]
    let tint: Color
    let isOn: Bool

    var body: some View {
        let today = Routine.todayIndex(Date())
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { index in
                let lit = index < days.count && days[index]
                Text(Routine.dayShort[index])
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(lit ? Theme.textBright : Theme.muted)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(lit ? tint.opacity(isOn ? 0.55 : 0.25) : Theme.field))
                    .overlay(Circle().stroke(Theme.textBright.opacity(index == today ? 0.7 : 0), lineWidth: 1.2))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(Routine.dayFull.indices.filter { $0 < days.count && days[$0] }.map { Routine.dayFull[$0] }.joined(separator: ", "))
    }
}
