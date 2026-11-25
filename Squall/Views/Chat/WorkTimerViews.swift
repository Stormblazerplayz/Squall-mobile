import SwiftUI

/// The timer button in a chat's header. It glows while a timer runs in that chat.
struct WorkTimerButton: View {
    let bot: Bot

    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    @ObservedObject private var feed = HistoryFeed.shared
    @State private var show = false

    var body: some View {
        let info = WorkTimers.info(from: feed.latest)
        let on = info?.timer(for: bot.id) != nil
        if info != nil {
            Button {
                show = true
            } label: {
                Image(systemName: on ? "timer.circle.fill" : "timer")
                    .font(.system(size: on ? 19 : 16, weight: .semibold))
                    .foregroundStyle(on ? store.accent : Theme.sub)
                    .frame(width: 36, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(on ? "Work timer running" : "Work timer and goal")
            .sheet(isPresented: $show) {
                WorkTimerSheet(bot: bot)
                    .lockCover()
                    .environmentObject(store)
                    .environmentObject(lock)
                    .presentationDetents([.medium, .large])
            }
        }
    }
}

/// A slim bar under a chat's header while a timer runs there: a ring, the time left and Stop.
struct WorkTimerBanner: View {
    let chatID: String

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var feed = HistoryFeed.shared
    @State private var stopping = false

    var body: some View {
        if let timer = WorkTimers.info(from: feed.latest)?.timer(for: chatID) {
            TimelineView(.periodic(from: .now, by: 1)) { context in
                HStack(spacing: 10) {
                    TimerRing(progress: timer.progress(now: context.date), tint: store.accent, size: 22)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(timer.continuous ? "Working until you stop it" : "Work timer")
                            .font(.system(size: 12.5, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text(WorkTimers.status(timer, now: context.date))
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .foregroundStyle(Theme.sub)
                    }
                    Spacer(minLength: 8)
                    Button {
                        stop()
                    } label: {
                        Group {
                            if stopping {
                                ProgressView().controlSize(.mini).tint(Theme.text)
                            } else {
                                Text("Stop")
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 14)
                        .frame(height: 30)
                        .background(Capsule().fill(Theme.field))
                    }
                    .buttonStyle(.plain)
                    .disabled(stopping)
                    .accessibilityLabel("Stop the work timer")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassCard(radius: 14)
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func stop() {
        stopping = true
        Task {
            await store.perform(WorkTimers.stopAction(chatID: chatID), busyKey: "timer-\(chatID)")
            stopping = false
        }
    }
}

/// Start a work timer, set a goal, or stop what's running.
struct WorkTimerSheet: View {
    let bot: Bot

    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var feed = HistoryFeed.shared
    @State private var minutes = 60
    @State private var goal = ""
    @State private var working = false
    @FocusState private var goalFocused: Bool

    var body: some View {
        let info = WorkTimers.info(from: feed.latest)
        let running = info?.timer(for: bot.id)
        NavigationStack {
            ZStack {
                GlowBackground(topHex: bot.hex)
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        if let running {
                            runningCard(running)
                        }
                        timerCard(running: running != nil)
                        goalCard
                    }
                    .padding(16)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Keep \(bot.name) working")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if let dial = info?.dial, WorkTimers.choices.contains(dial) { minutes = dial }
        }
    }

    // MARK: - Parts

    private func runningCard(_ running: WorkTimers.Running) -> some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 14) {
                TimerRing(progress: running.progress(now: context.date), tint: store.accent, size: 54)
                VStack(alignment: .leading, spacing: 3) {
                    Text(running.continuous ? "Continuous" : WorkTimers.status(running, now: context.date))
                        .font(.system(size: 20, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.textBright)
                    if let started = running.startedAt {
                        Text("Started \(TeamHistory.clock(started))")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.sub)
                    }
                }
                Spacer(minLength: 0)
                Button("Stop") {
                    act(WorkTimers.stopAction(chatID: bot.id), done: "Timer stopped.")
                }
                .buttonStyle(GhostButtonStyle(height: 38, expand: false, sidePadding: 16))
                .disabled(working)
            }
            .padding(14)
            .glassCard(radius: 18, tint: bot.hex, strength: 0.12)
        }
    }

    private func timerCard(running: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            label("WORK TIMER", "\(bot.name) keeps going until the time's up, and gets a nudge whenever it stops early.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 8)], spacing: 8) {
                ForEach(WorkTimers.choices, id: \.self) { choice in
                    Button(WorkTimers.length(choice)) { minutes = choice }
                        .buttonStyle(ChipButtonStyle(isOn: minutes == choice, tint: store.accent, minHeight: 38))
                }
            }
            Button(running ? "Start again with \(WorkTimers.length(minutes))" : "Start \(WorkTimers.length(minutes))") {
                act(WorkTimers.startAction(chatID: bot.id, minutes: minutes),
                    done: minutes == 0 ? "\(bot.name) keeps working until you stop it." : "\(bot.name) is on a \(WorkTimers.length(minutes)) timer.")
            }
            .buttonStyle(FilledButtonStyle(fill: store.accent))
            .disabled(working || !store.isConnected)
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private var goalCard: some View {
        let text = WorkTimers.goalText(goal)
        return VStack(alignment: .leading, spacing: 12) {
            label("GOAL", "Give \(bot.name) one thing to finish. It works on it step by step until it's done.")
            TextField("", text: $goal, prompt: Text("Like: leaderboard script tested in Studio").foregroundStyle(Theme.muted), axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 15))
                .foregroundStyle(Theme.text)
                .focused($goalFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
            Button("Set goal") {
                guard let text else { return }
                goalFocused = false
                store.send(text, to: bot.id)
                store.showToast("Goal sent to \(bot.name).")
                goal = ""
                dismiss()
            }
            .buttonStyle(FilledButtonStyle(fill: text == nil ? Color.white.opacity(0.12) : store.accent))
            .disabled(text == nil || !store.isConnected)
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private func label(_ title: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 11.5, weight: .bold))
                .tracking(1)
                .foregroundStyle(Theme.label)
            Text(note)
                .font(.system(size: 13))
                .foregroundStyle(Theme.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func act(_ action: SyncAction, done: String) {
        working = true
        Task {
            let reply = await store.perform(action, busyKey: "timer-\(bot.id)")
            working = false
            if reply != nil {
                store.showToast(done)
            }
        }
    }
}

/// A ring that fills as a timer runs; a spinning arc for Continuous.
struct TimerRing: View {
    let progress: Double?
    let tint: Color
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.12), lineWidth: size / 8)
            if let progress {
                Circle()
                    .trim(from: 0, to: max(0.02, 1 - progress))
                    .stroke(tint, style: StrokeStyle(lineWidth: size / 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            } else {
                TimelineView(.animation) { context in
                    let turn = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 2) / 2
                    Circle()
                        .trim(from: 0, to: 0.3)
                        .stroke(tint, style: StrokeStyle(lineWidth: size / 8, lineCap: .round))
                        .rotationEffect(.degrees(turn * 360))
                }
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
