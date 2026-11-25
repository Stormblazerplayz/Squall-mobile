import SwiftUI

/// The Squall Uno tab: every teammate's own computer, what is running right now, and recent tasks.
/// Everything here comes from the PC. Before it answers, the tab says why it can't show anything yet.
struct UnoTabView: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var uno: UnoModel

    @Environment(\.horizontalSizeClass) private var sizeClass
    @AppStorage(Prefs.haptics) private var haptics = true
    @State private var stopAllPresses = 0

    /// The name this tab uses when it asks the PC for updates.
    static let watcher = "unoTab"

    private var isWide: Bool { sizeClass == .regular }

    /// Chief first, then the rest of the team.
    private var agents: [Bot] {
        [store.chief] + store.teammates
    }

    /// The newest tasks on any computer, newest first.
    private var recent: [UnoSession] {
        Array(uno.sessions.sorted { ($0.startedAt ?? 0) > ($1.startedAt ?? 0) }.prefix(12))
    }

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    Text("Every teammate has its own computer inside Squall. Give one a task and watch Squall Uno click and type live.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.sub)
                        .fixedSize(horizontal: false, vertical: true)

                    if !uno.loaded, let problem = uno.problem {
                        UnoMessageCard(icon: "desktopcomputer", text: problem)
                    } else if !uno.loaded {
                        UnoMessageCard(icon: "desktopcomputer", text: "Asking your PC…")
                    } else {
                        if let problem = uno.problem {
                            Text(problem)
                                .font(.system(size: 12.5, weight: .semibold))
                                .foregroundStyle(Theme.redText)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        setupHints
                        if uno.anyRunning {
                            stopEverything
                        }
                        computers
                        recentTasks
                    }
                }
                .padding(16)
                .readableColumn(isWide ? Theme.wideWidth : Theme.readableWidth)
            }
            .scrollIndicators(.hidden)
            .refreshable {
                await uno.refresh()
            }
        }
        .sensoryFeedback(.warning, trigger: stopAllPresses) { _, _ in haptics }
        .onAppear { uno.show(Self.watcher) }
        .onDisappear { uno.hide(Self.watcher) }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Squall Uno")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textBright)
            if uno.anyRunning {
                HStack(spacing: 0) {
                    UnoLiveDot(size: 7)
                    Text("LIVE")
                        .font(.system(size: 11, weight: .heavy))
                        .tracking(0.7)
                        .foregroundStyle(Theme.redText)
                }
                .accessibilityLabel("Squall Uno is working right now")
            }
            Spacer()
            IconButton(systemName: "gearshape", label: "Squall Uno settings") {
                store.path.append(.unoSettings)
            }
        }
    }

    /// What the PC still needs before a task can run, in plain words.
    @ViewBuilder
    private var setupHints: some View {
        if let settings = uno.settings {
            if !settings.hasKey {
                Button {
                    store.path.append(.unoSettings)
                } label: {
                    UnoMessageCard(icon: "key.fill", text: "Squall Uno needs an Anthropic API key first. Tap here to add it in Squall Uno settings.")
                }
                .buttonStyle(.plain)
            }
            if !settings.dockerReady {
                UnoMessageCard(
                    icon: "shippingbox.fill",
                    text: settings.dockerText.isEmpty ? "Squall Uno needs Docker Desktop running on your PC." : settings.dockerText
                )
            }
        }
    }

    private var stopEverything: some View {
        Button {
            stopAllPresses += 1
            Task { @MainActor in
                await uno.stopAll()
            }
        } label: {
            Label(uno.isBusy("stopAll") ? "Stopping everything…" : "Stop everything", systemImage: "stop.fill")
        }
        .buttonStyle(FilledButtonStyle(fill: Theme.red, height: 44))
        .disabled(uno.isBusy("stopAll"))
        .accessibilityHint("Stops Squall Uno on every computer")
    }

    private var computers: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("COMPUTERS")
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: isWide ? 340 : 280), spacing: 10)],
                spacing: 10
            ) {
                ForEach(agents) { agent in
                    UnoComputerRow(agent: agent)
                }
            }
        }
    }

    @ViewBuilder
    private var recentTasks: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("RECENT TASKS")
            if recent.isEmpty {
                Text("No tasks yet. Open a computer above and tell Squall Uno what to do.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: isWide ? 340 : 280), spacing: 8)],
                    spacing: 8
                ) {
                    ForEach(recent) { session in
                        Button {
                            store.path.append(.uno(session.agentId))
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.agentName.isEmpty ? "Squall Uno" : "\(session.agentName)'s computer")
                                    .font(.system(size: 11, weight: .bold))
                                    .tracking(0.5)
                                    .foregroundStyle(Theme.muted)
                                    .padding(.leading, 4)
                                UnoSessionRow(session: session)
                            }
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens this computer")
                    }
                }
            }
        }
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11.5, weight: .heavy))
            .tracking(1.1)
            .foregroundStyle(Theme.muted)
            .padding(.top, 6)
    }
}
