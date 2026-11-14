import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: SquallStore
    @State private var clearArmed = false

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    profile
                    SectionLabel(text: "Chief")
                    chiefSection
                    SectionLabel(text: "Safety")
                    safetySection
                    SectionLabel(text: "Claude Code")
                    claudeCodeSection
                    SectionLabel(text: "Look")
                    lookSection
                    SectionLabel(text: "Notifications")
                    notificationSection
                    SectionLabel(text: "Danger zone")
                    dangerSection
                    Text("Squall concept · settings save as you change them")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
    }

    private var profile: some View {
        HStack(spacing: 14) {
            LogoTile(size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text("Storm's AI team")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Text("Chief and \(store.teammates.count) teammates")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.sub)
            }
            Spacer()
        }
        .padding(16)
        .glassCard(radius: 20, tint: store.accentHex, strength: 0.16)
    }

    private var chiefSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SwitchRow(title: "Nap when there is no work", subtitle: "Chief sleeps to save usage, then wakes to check in", isOn: $store.settings.napWhenIdle, tint: store.accent)
            Divider().overlay(Theme.cardBorder)
            Text("Check for work every")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.text)
            PillSegments(
                options: AppSettings.CheckInterval.allCases.map { (label: $0.label, value: $0) },
                selection: $store.settings.checkEvery
            )
            Divider().overlay(Theme.cardBorder)
            SwitchRow(title: "Chief can hand out work", subtitle: "Chief gives jobs to whoever is free", isOn: $store.settings.chiefHandsOut, tint: store.accent)
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SwitchRow(title: "Ask before running commands", subtitle: "You OK each terminal command first", isOn: $store.settings.askBeforeCommands, tint: store.accent)
            Divider().overlay(Theme.cardBorder)
            SwitchRow(title: "Ask before pushing code", subtitle: "Nothing goes to GitHub without you", isOn: $store.settings.askBeforePush, tint: store.accent)
            Divider().overlay(Theme.cardBorder)
            Stepper(value: $store.settings.maxBotsAtOnce, in: 1...9) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bots working at once")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text(store.settings.maxBotsAtOnce == 1 ? "One at a time" : "Up to \(store.settings.maxBotsAtOnce) at the same time")
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.sub)
                }
            }
            .frame(minHeight: 44)
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private var claudeCodeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Version")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.text)
                Spacer()
                Text(store.claudeCode == .upToDate ? ClaudeCodeUpdate.newVersion : ClaudeCodeUpdate.oldVersion)
                    .font(Theme.mono(14))
                    .foregroundStyle(Theme.text)
                StatusPill(
                    status: store.claudeCode == .upToDate ? .working : .waiting,
                    text: store.claudeCode == .upToDate ? "Up to date" : "Update needed"
                )
            }
            switch store.claudeCode {
            case .needed:
                Text("Chief stopped because this version is too old. Version \(ClaudeCodeUpdate.newVersion) or newer is needed.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
                Button("Update to \(ClaudeCodeUpdate.newVersion)") { store.runUpdate() }
                    .buttonStyle(FilledButtonStyle(fill: Theme.gold, foreground: Theme.darkInk, height: 42))
            case .updating(let progress):
                Text("Updating… \(Int(progress * 100))%")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.goldText)
                ProgressView(value: progress).tint(Theme.goldBright)
            case .upToDate:
                Text("Chief is awake and can work again.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.greenText)
            }
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private var lookSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accent color")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.text)
            HStack(spacing: 12) {
                ForEach(Theme.accentChoices.indices, id: \.self) { index in
                    let choice = Theme.accentChoices[index]
                    let isOn = choice.hex == store.accentHex
                    Button {
                        store.accentHex = choice.hex
                    } label: {
                        Circle()
                            .fill(Color(hex: choice.hex))
                            .frame(width: 34, height: 34)
                            .overlay(Circle().stroke(Color.white, lineWidth: isOn ? 2.5 : 0))
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(choice.name)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18)
    }

    private var notificationSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SwitchRow(title: "When a bot needs me", subtitle: "Questions and OKs", isOn: $store.settings.notifyNeedsMe, tint: store.accent)
            Divider().overlay(Theme.cardBorder)
            SwitchRow(title: "When something breaks", subtitle: "Errors get stacked, so one ping per problem", isOn: $store.settings.notifyErrors, tint: store.accent)
            Divider().overlay(Theme.cardBorder)
            SwitchRow(title: "When work is done", subtitle: "Off keeps your phone quiet", isOn: $store.settings.notifyDone, tint: store.accent)
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private var dangerSection: some View {
        Button(clearArmed ? "Tap again to clear every chat" : "Clear all chats") {
            if clearArmed {
                store.clearAllChats()
                clearArmed = false
            } else {
                clearArmed = true
            }
        }
        .buttonStyle(GhostButtonStyle(foreground: Theme.redText, border: Theme.red.opacity(clearArmed ? 0.9 : 0.45), fill: Theme.red.opacity(clearArmed ? 0.18 : 0.06)))
    }
}
