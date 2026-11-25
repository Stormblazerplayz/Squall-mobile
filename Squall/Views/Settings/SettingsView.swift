import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var pairing: PairingStore
    @EnvironmentObject private var lock: AppLock
    @Environment(\.horizontalSizeClass) private var sizeClass
    @Environment(\.openURL) private var openURL

    @State private var clearArmed = false
    @State private var unpairArmed = false
    @State private var resetSettingsArmed = false
    @State private var currentIcon: String?
    @State private var changingIcon = false

    /// Asset name (nil is the normal icon), name shown, and the small preview image.
    private static let iconChoices: [(asset: String?, title: String, preview: String)] = [
        (nil, "Chief's Bolt", "IconPreviewChiefsBolt"),
        ("Classic", "Classic", "IconPreviewClassic"),
        ("StormCloud", "Storm Cloud", "IconPreviewStormCloud"),
        ("SquallSwirl", "Squall Swirl", "IconPreviewSquallSwirl"),
        ("BotCrew", "Bot Crew", "IconPreviewBotCrew"),
        ("Orbit", "Orbit", "IconPreviewOrbit"),
        ("PowerChip", "Power Chip", "IconPreviewPowerChip")
    ]

    @AppStorage(Prefs.teamName) private var teamName = "Storm"
    @AppStorage(Prefs.chatTextSize) private var chatTextSize = 15.0
    @AppStorage(Prefs.showTyping) private var showTyping = true
    @AppStorage(Prefs.showTimes) private var showTimes = true
    @AppStorage(Prefs.sendOnReturn) private var sendOnReturn = false
    @AppStorage(Prefs.haptics) private var haptics = true
    @AppStorage(Prefs.sounds) private var sounds = true
    @AppStorage(Prefs.softGlow) private var softGlow = false
    @AppStorage(Prefs.openChat) private var openChat: Prefs.OpenChat = .chief
    @AppStorage(Prefs.defaultRole) private var defaultRole = "Generalist"
    @AppStorage(Prefs.appLock) private var appLock = false
    @AppStorage(Prefs.hideInSwitcher) private var hideInSwitcher = false
    @AppStorage(Prefs.autoLockScreen) private var autoLockScreen = true
    @ObservedObject private var alerts = SquallAlerts.shared

    private let lockMethod = AppLock.methodName
    private static let githubURL = URL(string: "https://github.com/Stormblazerplayz/Squall-mobile")!

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    profile
                    if sizeClass == .regular {
                        // iPad: two columns of settings side by side.
                        HStack(alignment: .top, spacing: 18) {
                            VStack(alignment: .leading, spacing: 14) { firstColumn }
                                .frame(maxWidth: .infinity)
                            VStack(alignment: .leading, spacing: 14) { secondColumn }
                                .frame(maxWidth: .infinity)
                        }
                    } else {
                        firstColumn
                        secondColumn
                    }
                    Text("Squall · settings save as you change them")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }
                .padding(16)
                .readableColumn(sizeClass == .regular ? 1100 : Theme.readableWidth)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .onAppear {
            // Chief's Bolt used to be an extra icon; it's the normal one now.
            let name = UIApplication.shared.alternateIconName
            currentIcon = name == "ChiefsBolt" ? nil : name
        }
        .onChange(of: appLock) { _, isOn in
            if isOn && !AppLock.canLock {
                appLock = false
                store.showToast("Set a passcode on this device first, then turn App lock on.")
            } else if !isOn {
                lock.turnedOff()
            }
        }
    }

    @ViewBuilder
    private var firstColumn: some View {
        SectionLabel(text: "Computer")
        computerSection
        SectionLabel(text: "Look")
        lookSection
        SectionLabel(text: "Chat")
        chatSection
        SectionLabel(text: "Chief")
        chiefSection
        SectionLabel(text: "New teammates")
        teammateSection
    }

    @ViewBuilder
    private var secondColumn: some View {
        SectionLabel(text: "Plan usage")
        usageSection
        SectionLabel(text: "Safety")
        safetySection
        SectionLabel(text: "Claude Code")
        claudeCodeSection
        SectionLabel(text: "Notifications")
        notificationSection
        SectionLabel(text: "Lock Screen")
        lockScreenSection
        SectionLabel(text: "Privacy")
        privacySection
        SectionLabel(text: "Data")
        dataSection
        SectionLabel(text: "About")
        aboutSection
    }

    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18)
    }

    private func rowTitle(_ title: String, _ subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Theme.text)
            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.sub)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var line: some View {
        Divider().overlay(Theme.cardBorder)
    }

    /// Opens Plan usage: the plan's windows, the slow-down switch and today's jobs.
    private var usageSection: some View {
        Button {
            store.path.append(.usage)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "gauge.with.dots.needle.50percent")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x3FD0B0))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(hex: 0x3FD0B0, opacity: 0.14)))
                VStack(alignment: .leading, spacing: 2) {
                    Text("Plan usage")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Text(usageLine)
                        .font(.system(size: 12.5))
                        .foregroundStyle(Theme.sub)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Theme.muted)
            }
            .padding(14)
            .glassCard(radius: 18)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var usageLine: String {
        guard store.hasData else { return "Pair with your computer to see it." }
        guard let usage = store.usage else { return "Update Squall on your computer to see it here." }
        var line = UsageText.summary(usage)
        if usage.slowDown, let limit = usage.limit { line += " · slows down at \(limit)%" }
        return line
    }

    private var computerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let computer = pairing.computer {
                let line = connectionLine(for: computer)
                HStack(spacing: 12) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.greenText)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.green.opacity(0.14)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Paired with \(computer.name)")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Text(line.text)
                            .font(.system(size: 12.5))
                            .foregroundStyle(line.color)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                    ConnectionDot(size: 10)
                }
                computerDetails(computer)
                HStack(spacing: 8) {
                    Button(pairing.connection == .checking ? "Checking..." : "Test connection") {
                        Task {
                            await pairing.checkConnection()
                            store.refreshNow()
                        }
                    }
                    .buttonStyle(GhostButtonStyle(height: 40, fontSize: 14, sidePadding: 10))
                    .disabled(pairing.connection == .checking || pairing.busy)
                    Button(unpairArmed ? "Tap again to unpair" : "Unpair this phone") {
                        if unpairArmed {
                            unpairArmed = false
                            Task {
                                await pairing.unpair()
                                store.showToast("Unpaired. The saved copy is gone from this phone.")
                            }
                        } else {
                            unpairArmed = true
                        }
                    }
                    .buttonStyle(GhostButtonStyle(
                        height: 40,
                        foreground: Theme.redText,
                        border: Theme.red.opacity(unpairArmed ? 0.9 : 0.45),
                        fill: Theme.red.opacity(unpairArmed ? 0.18 : 0.06),
                        fontSize: 14,
                        sidePadding: 10
                    ))
                    .disabled(pairing.busy)
                }
                if unpairArmed {
                    Text("Unpairing makes both sides forget each other, and removes the saved copy and the widgets' data from this phone.")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else if store.isDemo {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.demoText)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.demo.opacity(0.16)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Demo mode")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Text("A pretend team on this phone. Nothing here is real, and nothing is sent to a computer. Settings you change here go back when you leave.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                HStack(spacing: 8) {
                    Button("Leave demo") { store.endDemo() }
                        .buttonStyle(GhostButtonStyle(height: 40, fontSize: 14, sidePadding: 10))
                    Button("Pair for real") {
                        store.endDemo(quiet: true)
                        store.showPairing = true
                    }
                    .buttonStyle(FilledButtonStyle(fill: store.accent, height: 40))
                }
            } else {
                HStack(spacing: 12) {
                    Image(systemName: "desktopcomputer")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.sub)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Theme.field))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Not paired")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.text)
                        Text("Pair to see your team from your computer.")
                            .font(.system(size: 12.5))
                            .foregroundStyle(Theme.sub)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 0)
                }
                Button("Pair with computer") { store.showPairing = true }
                    .buttonStyle(FilledButtonStyle(fill: store.accent, height: 42))
                if store.canStartDemo {
                    TryDemoButton(height: 40)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18)
        .onChange(of: pairing.computer) {
            unpairArmed = false
        }
    }

    /// Name, address, when it was paired and when data last came in.
    private func computerDetails(_ computer: PairedComputer) -> some View {
        VStack(spacing: 0) {
            detailRow("Computer", computer.name)
            detailRow("Address", computer.address)
            detailRow("Paired", computer.pairedAt.formatted(date: .abbreviated, time: .shortened))
            if let version = store.desktop?.summary {
                detailRow("Squall on it", version)
            }
            TimelineView(.periodic(from: .now, by: 30)) { context in
                detailRow("Last synced", store.lastSynced.map { SyncAge.text($0, now: context.date) } ?? "Not yet")
            }
            detailRow("Status", statusText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
    }

    private var statusText: String {
        switch store.link {
        case .connected: return "Live"
        case .connecting: return "Connecting"
        case .offline: return store.showingSaved ? "Not answering · showing saved copy" : "Not answering"
        case .unpaired: return "Not paired"
        }
    }

    private func detailRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.sub)
            Spacer(minLength: 8)
            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Theme.text)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .frame(minHeight: 30)
    }

    private func connectionLine(for computer: PairedComputer) -> (text: String, color: Color) {
        if pairing.connection == .checking {
            return ("Checking \(computer.address)...", Theme.sub)
        }
        switch store.link {
        case .connected:
            return ("Connected · \(computer.address)", Theme.greenText)
        case .connecting:
            return ("Connecting to \(computer.address)...", Theme.sub)
        case .offline(let reason):
            return (reason, Theme.redText)
        case .unpaired:
            return (computer.address, Theme.sub)
        }
    }

    private var profile: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 14) {
                LogoTile(size: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text(Prefs.teamTitle(teamName))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(Theme.textBright)
                    Text("Chief and \(store.teammates.count) teammates")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.sub)
                }
                Spacer()
            }
            HStack(spacing: 10) {
                Text("Your name")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.sub)
                DarkField(placeholder: "Storm", text: $teamName)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
            }
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
            if let code = store.claudeCode {
                HStack {
                    Text("Version")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.text)
                    Spacer()
                    Text(code.version.isEmpty ? "Unknown" : code.version)
                        .font(Theme.mono(14))
                        .foregroundStyle(Theme.text)
                    StatusPill(
                        status: code.needsUpdate ? .waiting : .working,
                        text: code.needsUpdate ? "Update needed" : "Up to date"
                    )
                }
                if let progress = code.updating {
                    Text("Updating… \(Int(progress * 100))%")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.goldText)
                    ProgressView(value: progress).tint(Theme.goldBright)
                } else if code.needsUpdate {
                    Text(code.latest.map { "Chief stopped because this version is too old. Version \($0) or newer is needed." }
                         ?? "Chief stopped because this version is too old.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.sub)
                    Button(store.isBusy("claudeCode.update") ? "Starting update…" : (code.latest.map { "Update to \($0)" } ?? "Update Claude Code")) {
                        store.runUpdate()
                    }
                    .buttonStyle(FilledButtonStyle(fill: Theme.gold, foreground: Theme.darkInk, height: 42))
                    .disabled(store.isUpdatingClaudeCode || !store.isConnected)
                } else {
                    Text("Chief can use it on your computer.")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.greenText)
                }
            } else {
                Text(store.isConnected ? "Your computer didn't say which version it has." : "Shows once your computer is connected.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.sub)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private var lookSection: some View {
        card {
            rowTitle("Accent color")
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
            line
            rowTitle("App icon", "How Squall looks on your Home Screen")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 76), spacing: 10)], spacing: 12) {
                ForEach(Self.iconChoices.indices, id: \.self) { index in
                    iconButton(Self.iconChoices[index])
                }
            }
            line
            SwitchRow(title: "Softer glow", subtitle: "Turns the colored background light down", isOn: $softGlow, tint: store.accent)
            line
            SwitchRow(title: "Vibrate", subtitle: "A small buzz when you send, allow something, a bot needs you or a job finishes", isOn: $haptics, tint: store.accent)
            line
            SwitchRow(title: "Small sounds", subtitle: "A quick tink for OKs and finished jobs. Follows the silent switch.", isOn: $sounds, tint: store.accent)
        }
    }

    private func iconButton(_ choice: (asset: String?, title: String, preview: String)) -> some View {
        let isOn = currentIcon == choice.asset
        return Button {
            setIcon(choice.asset)
        } label: {
            VStack(spacing: 6) {
                Image(choice.preview)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 13.4, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15.5, style: .continuous)
                            .stroke(isOn ? store.accent : Color.clear, lineWidth: 2.5)
                            .padding(-4)
                    )
                Text(choice.title)
                    .font(.system(size: 11.5, weight: isOn ? .bold : .medium))
                    .foregroundStyle(isOn ? Theme.textBright : Theme.sub)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(changingIcon)
        .accessibilityLabel("\(choice.title) icon")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func setIcon(_ asset: String?) {
        let app = UIApplication.shared
        guard asset != currentIcon else { return }
        guard app.supportsAlternateIcons else {
            store.showToast("This device can't change app icons.")
            return
        }
        changingIcon = true
        Task { @MainActor in
            do {
                try await app.setAlternateIconName(asset)
                currentIcon = asset
            } catch {
                store.showToast("Couldn't change the icon. Try again.")
            }
            changingIcon = false
        }
    }

    private var chatSection: some View {
        card {
            rowTitle("Message text size")
            PillSegments(
                options: [
                    (label: "Small", value: 13.5),
                    (label: "Normal", value: 15.0),
                    (label: "Big", value: 17.0),
                    (label: "Huge", value: 19.0)
                ],
                selection: $chatTextSize
            )
            Text("Hey, this is how big messages look.")
                .font(.system(size: chatTextSize))
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassCard(radius: 14, tint: store.accentHex, strength: 0.12)
            line
            SwitchRow(title: "Show typing dots", subtitle: "See when a bot is writing back", isOn: $showTyping, tint: store.accent)
            line
            SwitchRow(title: "Show message times", isOn: $showTimes, tint: store.accent)
            line
            SwitchRow(title: "Send with Return", subtitle: "Handy with an iPad keyboard. Off makes Return start a new line.", isOn: $sendOnReturn, tint: store.accent)
            line
            rowTitle("Chat opens on", "What you see when Squall starts")
            PillSegments(
                options: Prefs.OpenChat.allCases.map { (label: $0.label, value: $0) },
                selection: $openChat
            )
        }
    }

    private var teammateSection: some View {
        card {
            rowTitle("Starting role", "New teammates begin with this role. You can still change it.")
            ScrollView(.horizontal) {
                HStack(spacing: 8) {
                    ForEach(SquallStore.roles, id: \.self) { role in
                        Button(role) { defaultRole = role }
                            .buttonStyle(ChipButtonStyle(isOn: defaultRole == role, tint: store.accent))
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private var notificationSection: some View {
        card {
            if alerts.permission == .denied {
                permissionRow("Notifications are off for Squall in the Settings app.", button: "Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                line
            } else if alerts.permission == .notDetermined {
                permissionRow("Let Squall ping you when a bot needs you, even when the app is closed.", button: "Turn on") {
                    Task { await alerts.askNow() }
                }
                line
            }
            SwitchRow(title: "When a bot needs me", subtitle: "Questions and OKs", isOn: $store.settings.notifyNeedsMe, tint: store.accent)
            line
            SwitchRow(title: "When something breaks", subtitle: "Errors get stacked, so one ping per problem", isOn: $store.settings.notifyErrors, tint: store.accent)
            line
            SwitchRow(title: "When work is done", subtitle: "Off keeps your phone quiet", isOn: $store.settings.notifyDone, tint: store.accent)
            line
            SwitchRow(title: "Play a sound", isOn: $store.settings.notifySound, tint: store.accent)
            line
            SwitchRow(title: "Quiet hours", subtitle: quietSubtitle, isOn: $store.settings.quietHours, tint: store.accent)
            if store.settings.quietHours {
                HStack(spacing: 10) {
                    hourPicker("From", selection: $store.settings.quietStart)
                    hourPicker("To", selection: $store.settings.quietEnd)
                }
            }
            line
            rowTitle("Pings from", "Turn a bot off to stop its pings. It keeps working.")
            ForEach(store.displayBots) { bot in
                HStack(spacing: 10) {
                    Sphere(bot: bot, size: 28)
                    Toggle(isOn: pingBinding(bot.id)) {
                        Text(bot.name)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(Theme.text)
                    }
                    .tint(store.accent)
                }
                .frame(minHeight: 40)
            }
        }
        .animation(.easeOut(duration: 0.2), value: store.settings.quietHours)
    }

    private func permissionRow(_ text: String, button: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "bell.badge.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.goldText)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 6)
            Button(button, action: action)
                .buttonStyle(GhostButtonStyle(height: 34, expand: false, fontSize: 13.5, sidePadding: 10))
        }
    }

    private var lockScreenSection: some View {
        card {
            SwitchRow(
                title: "Show on Lock Screen by itself",
                subtitle: "A new OK request, or your team when it starts working, shows up on the Lock Screen without a tap. iPhone only.",
                isOn: $autoLockScreen,
                tint: store.accent
            )
            line
            Text("Allow, Deny and Pause on the Lock Screen, in notifications, in widgets and in Control Center go straight to your computer, even when Squall is closed. Allow asks for Face ID first.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.sub)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var quietSubtitle: String {
        guard store.settings.quietHours else { return "No pings at night" }
        return "No pings from \(AppSettings.clock(store.settings.quietStart)) to \(AppSettings.clock(store.settings.quietEnd))"
    }

    private func hourPicker(_ title: String, selection: Binding<Int>) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(Theme.sub)
            Picker(title, selection: selection) {
                ForEach(0..<24, id: \.self) { hour in
                    Text(AppSettings.clock(hour * 60)).tag(hour * 60)
                }
            }
            .pickerStyle(.menu)
            .tint(Theme.text)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 40)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.field))
    }

    private func pingBinding(_ id: String) -> Binding<Bool> {
        Binding(
            get: { !store.settings.mutedBots.contains(id) },
            set: { isOn in
                if isOn {
                    store.settings.mutedBots.remove(id)
                } else {
                    store.settings.mutedBots.insert(id)
                }
            }
        )
    }

    private var privacySection: some View {
        card {
            SwitchRow(title: "Lock with \(lockMethod)", subtitle: "Asks every time you come back to Squall", isOn: $appLock, tint: store.accent)
            line
            SwitchRow(title: "Hide in app switcher", subtitle: "Covers your chats when you swipe between apps", isOn: $hideInSwitcher, tint: store.accent)
        }
    }

    private var dataSection: some View {
        card {
            ShareLink(item: store.chatExport, preview: SharePreview("Squall chats")) {
                Label("Export chats", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(GhostButtonStyle(height: 42, fontSize: 14))
            armedButton(
                resetSettingsArmed ? "Tap again to reset settings" : "Reset settings",
                armed: resetSettingsArmed
            ) {
                if resetSettingsArmed {
                    resetSettingsArmed = false
                    store.resetSettings()
                } else {
                    resetSettingsArmed = true
                }
            }
            armedButton(clearArmed ? "Tap again to clear every chat" : "Clear all chats", armed: clearArmed) {
                if clearArmed {
                    clearArmed = false
                    store.clearAllChats()
                } else {
                    clearArmed = true
                }
            }
            .disabled(!store.isConnected)
        }
    }

    private func armedButton(_ title: String, armed: Bool, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .buttonStyle(GhostButtonStyle(
                height: 42,
                foreground: Theme.redText,
                border: Theme.red.opacity(armed ? 0.9 : 0.45),
                fill: Theme.red.opacity(armed ? 0.18 : 0.06),
                fontSize: 14
            ))
    }

    private var versionText: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (build \(build))"
    }

    private var makerName: String {
        let name = teamName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Storm" : name
    }

    private var aboutSection: some View {
        card {
            HStack {
                rowTitle("Version")
                Spacer()
                Text(versionText)
                    .font(Theme.mono(13.5))
                    .foregroundStyle(Theme.text)
            }
            line
            Button {
                openURL(Self.githubURL)
            } label: {
                Label("Squall on GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .buttonStyle(GhostButtonStyle(height: 42, fontSize: 14))
            Text("Made by \(makerName) with Claude.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.sub)
        }
    }
}
