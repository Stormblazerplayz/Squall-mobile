import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    @EnvironmentObject private var pairing: PairingStore

    var body: some View {
        NavigationStack(path: $store.path) {
            tabContent
                .toolbar(.hidden, for: .navigationBar)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    SquallTabBar()
                }
                .navigationDestination(for: Route.self) { route in
                    destination(for: route)
                }
        }
        .tint(store.accent)
        .background {
            KeyCommands()
        }
        .overlay(alignment: .top) {
            if let toast = store.toast {
                ToastView(toast: toast) { action in
                    store.handleToast(action)
                }
                .padding(.top, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: store.toast)
        .sheet(isPresented: $store.showNewTeammate) {
            NewTeammateSheet()
                .lockCover()
                .environmentObject(store)
                .environmentObject(lock)
        }
        .sheet(item: $store.handoffTarget) { target in
            HandoffSheet(botID: target.id)
                .lockCover()
                .environmentObject(store)
                .environmentObject(lock)
        }
        .fullScreenCover(isPresented: $store.showCall) {
            CallChiefView()
                .lockCover()
                .environmentObject(store)
                .environmentObject(lock)
                .environmentObject(pairing)
        }
        .sheet(isPresented: $store.showPairing) {
            PairingView(place: .settings) {
                store.showPairing = false
            }
            .lockCover()
            .environmentObject(pairing)
            .environmentObject(store)
            .environmentObject(lock)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        if store.hasData {
            // Live data, or the last real copy from this computer while it's away.
            connectedTab
        } else {
            // Nothing to show until the computer sends the team.
            NotConnectedView()
        }
    }

    @ViewBuilder
    private var connectedTab: some View {
        switch store.tab {
        case .team:
            TeamView()
        case .chat:
            ChatView()
        case .inbox:
            InboxView()
        case .board:
            BoardView()
        case .routines:
            RoutinesView()
        }
    }

    @ViewBuilder
    private func destination(for route: Route) -> some View {
        switch route {
        case .settings:
            SettingsView().navigationTitle("Settings").pushedScreen()
        case .live:
            connected { LiveWorkView() }.navigationTitle("Live work").pushedScreen()
        case .group:
            // The group screen sets its own title (it changes to the group's name).
            connected { GroupChatView() }.pushedScreen()
        case .newRoutine:
            connected { RoutineEditorView() }.navigationTitle("New routine").pushedScreen()
        case .mission:
            connected { MissionControlView() }.navigationTitle("Mission control").pushedScreen()
        case .todo:
            connected { TodoView() }.navigationTitle("To do").pushedScreen()
        }
    }

    /// The screen when there's real data from the computer, or the "Not connected" screen.
    @ViewBuilder
    private func connected<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        if store.hasData {
            content()
        } else {
            NotConnectedView()
        }
    }
}

extension View {
    /// Look for screens that slide in on top of the tabs.
    func pushedScreen() -> some View {
        self
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.visible, for: .navigationBar)
            .toolbarBackground(Theme.background.opacity(0.92), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

/// The bar along the bottom: Team, Chat, Inbox, Board, Routines.
struct SquallTabBar: View {
    @EnvironmentObject private var store: SquallStore

    var body: some View {
        VStack(spacing: 2) {
            ConnectionStrip()
            HStack(spacing: 0) {
                ForEach(AppTab.allCases) { tab in
                    tabButton(tab)
                }
            }
        }
        .readableColumn(Theme.tabBarWidth)
        .padding(.horizontal, 8)
        .padding(.top, 4)
        .padding(.bottom, 4)
        .background(
            Theme.background.opacity(0.94)
                .overlay(alignment: .top) {
                    Rectangle().fill(Theme.cardBorder).frame(height: 1)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(_ tab: AppTab) -> some View {
        let isOn = store.tab == tab
        return Button {
            if tab == .chat, store.tab != .chat {
                store.openChat(store.currentChatID)
            } else {
                store.tab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 18, weight: .semibold))
                    .overlay(alignment: .topTrailing) {
                        if tab == .inbox, store.hasData, store.unreadInboxCount > 0 {
                            Text("\(store.unreadInboxCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(minWidth: 16, minHeight: 16)
                                .background(Circle().fill(Theme.red))
                                .offset(x: 10, y: -6)
                        }
                    }
                Text(tab.label)
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(isOn ? Theme.textBright : Theme.muted)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .keyboardShortcut(Self.key(for: tab), modifiers: .command)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// ⌘1 to ⌘5 on a keyboard, in the order of the tabs.
    private static func key(for tab: AppTab) -> KeyEquivalent {
        let number = (AppTab.allCases.firstIndex(of: tab) ?? 0) + 1
        return KeyEquivalent(Character(String(number)))
    }
}

/// Keyboard shortcuts for iPad (and iPhone with a keyboard). Hold ⌘ to see them all.
/// The tabs are ⌘1 to ⌘5, on the tab bar itself.
private struct KeyCommands: View {
    @EnvironmentObject private var store: SquallStore

    var body: some View {
        Group {
            Button("Refresh") {
                store.refreshNow()
            }
            .keyboardShortcut("r", modifiers: .command)
            Button("Call Chief") {
                store.showCall = true
            }
            .keyboardShortcut("k", modifiers: [.command, .shift])
            Button("New teammate") {
                if store.isConnected {
                    store.showNewTeammate = true
                } else {
                    store.showToast("Connect to your computer first.", action: .pair)
                }
            }
            .keyboardShortcut("n", modifiers: .command)
            Button("Mission control") {
                store.open(SquallLink.mission)
            }
            .keyboardShortcut("m", modifiers: [.command, .shift])
            Button("To do") {
                if store.path.last != .todo { store.path = [.todo] }
            }
            .keyboardShortcut("t", modifiers: [.command, .shift])
            Button("Settings") {
                if store.path.last != .settings { store.path = [.settings] }
            }
            .keyboardShortcut(",", modifiers: .command)
            Button("Back") {
                if !store.path.isEmpty { store.path.removeLast() }
            }
            .keyboardShortcut("[", modifiers: .command)
        }
        .frame(width: 0, height: 0)
        .opacity(0)
        .accessibilityHidden(true)
    }
}
