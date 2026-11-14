import SwiftUI

/// Make a new routine: who wakes up, what they do and when.
struct RoutineEditorView: View {
    @EnvironmentObject private var store: SquallStore

    @State private var botID = "barry"
    @State private var task = "Check the Farside build. If it fails, find out why and tell me."
    @State private var repeatMode: Routine.Repeat = .daily
    @State private var days = Array(repeating: true, count: 7)
    @State private var minutes = 9 * 60
    @State private var pingWhenDone = true
    @State private var askBeforePush = true
    @State private var skipIfBusy = false

    private let ideas = ["Check the Farside build", "Tidy my notes", "Look for bugs in Nimbus", "Write a daily recap"]

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    SectionLabel(text: "Who wakes up")
                    whoPicker
                    SectionLabel(text: "What should \(botName) do")
                    DarkField(placeholder: "Tell \(botName) what to do", text: $task, axis: .vertical)
                    ScrollView(.horizontal) {
                        HStack(spacing: 8) {
                            ForEach(ideas, id: \.self) { idea in
                                Button(idea) { task = idea + "." }
                                    .buttonStyle(ChipButtonStyle(tint: store.accent, minHeight: 34))
                            }
                        }
                    }
                    .scrollIndicators(.hidden)

                    SectionLabel(text: "When")
                    whenSection

                    SectionLabel(text: "Rules")
                    VStack(spacing: 4) {
                        SwitchRow(title: "Ping me when it finishes", subtitle: "Shows up in your Inbox", isOn: $pingWhenDone, tint: store.accent)
                        Divider().overlay(Theme.cardBorder)
                        SwitchRow(title: "Ask me before pushing code", subtitle: "Nothing goes to GitHub without your OK", isOn: $askBeforePush, tint: store.accent)
                        Divider().overlay(Theme.cardBorder)
                        SwitchRow(title: "Skip if the bot is busy", subtitle: "Otherwise it waits until the bot is free", isOn: $skipIfBusy, tint: store.accent)
                    }
                    .padding(14)
                    .glassCard(radius: 18)

                    SectionLabel(text: "Preview")
                    preview
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            Button(saveLabel) { save() }
                .buttonStyle(FilledButtonStyle(fill: canSave ? store.accent : Color.white.opacity(0.12)))
                .disabled(!canSave)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Theme.background.opacity(0.95))
        }
        .onChange(of: repeatMode) {
            if let preset = repeatMode.presetDays {
                days = preset
            }
        }
    }

    private var bot: Bot? { store.bot(botID) }
    private var botName: String { bot?.name ?? "your bot" }
    private var cleanTask: String { task.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasDay: Bool { days.contains(true) }
    private var canSave: Bool { hasDay && !cleanTask.isEmpty }

    private var saveLabel: String {
        if !hasDay { return "Pick a day first" }
        if cleanTask.isEmpty { return "Add a job first" }
        return "Save routine"
    }

    private var whoPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(store.teammates) { teammate in
                    let isOn = teammate.id == botID
                    Button {
                        botID = teammate.id
                    } label: {
                        VStack(spacing: 5) {
                            Sphere(bot: teammate, size: 42, glow: isOn ? 0.7 : 0.2)
                                .overlay(Circle().stroke(Color.white.opacity(isOn ? 0.9 : 0), lineWidth: 2).padding(-3))
                            Text(teammate.name)
                                .font(.system(size: 11.5, weight: .semibold))
                                .foregroundStyle(isOn ? Theme.textBright : Theme.muted)
                                .lineLimit(1)
                        }
                        .frame(width: 58)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(teammate.name)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    private var whenSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            PillSegments(
                options: Routine.Repeat.allCases.map { (label: $0.label, value: $0) },
                selection: $repeatMode
            )
            HStack(spacing: 6) {
                ForEach(0..<7, id: \.self) { index in
                    Button {
                        days[index].toggle()
                        repeatMode = matchingMode(for: days)
                    } label: {
                        Text(Routine.dayShort[index])
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(days[index] ? Theme.textBright : Theme.muted)
                            .frame(maxWidth: .infinity, minHeight: 40)
                            .background(Circle().fill(days[index] ? store.accent.opacity(0.55) : Theme.field))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(Routine.dayFull[index])
                    .accessibilityAddTraits(days[index] ? .isSelected : [])
                }
            }
            HStack(spacing: 12) {
                stepButton("minus", label: "30 minutes earlier") { minutes = (minutes + 24 * 60 - 30) % (24 * 60) }
                VStack(spacing: 2) {
                    Text(TimeText.time(minutes: minutes))
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.textBright)
                        .monospacedDigit()
                    Text(partOfDay)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.sub)
                }
                .frame(maxWidth: .infinity)
                stepButton("plus", label: "30 minutes later") { minutes = (minutes + 30) % (24 * 60) }
            }
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private func matchingMode(for days: [Bool]) -> Routine.Repeat {
        if days == Routine.Repeat.daily.presetDays { return .daily }
        if days == Routine.Repeat.weekdays.presetDays { return .weekdays }
        return .custom
    }

    private var partOfDay: String {
        switch minutes / 60 {
        case 5..<12: return "Morning"
        case 12..<17: return "Afternoon"
        case 17..<21: return "Evening"
        default: return "Night"
        }
    }

    private func stepButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(Theme.text)
                .frame(width: 46, height: 46)
                .background(Circle().fill(Theme.field))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private var preview: some View {
        HStack(alignment: .top, spacing: 12) {
            if let bot {
                Sphere(bot: bot, size: 36)
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("\(botName) wakes up \(Routine.whenText(mode: repeatMode, days: days, minutes: minutes)) and will: \(cleanTask.isEmpty ? "…" : cleanTask)")
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.text)
                Text(Routine.nextRun(days: days, minutes: minutes))
                    .font(.system(size: 12.5, weight: .semibold))
                    .foregroundStyle(hasDay ? Theme.greenText : Theme.redText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassCard(radius: 18, tint: bot?.hex, strength: 0.12)
    }

    private func save() {
        guard canSave else { return }
        let routine = Routine(
            botID: botID,
            task: cleanTask,
            repeatMode: repeatMode,
            days: days,
            minutes: minutes,
            isOn: true,
            pingWhenDone: pingWhenDone,
            askBeforePush: askBeforePush,
            skipIfBusy: skipIfBusy
        )
        store.saveRoutine(routine)
    }
}
