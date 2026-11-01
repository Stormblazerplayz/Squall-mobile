import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: SquallStore

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
                .environmentObject(store)
        }
        .sheet(item: $store.handoffTarget) { target in
            HandoffSheet(botID: target.id)
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $store.showCall) {
            CallChiefView()
                .environmentObject(store)
        }
    }

    @ViewBuilder
    private var tabContent: some View {
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
            LiveWorkView().navigationTitle("Live work").pushedScreen()
        case .group:
            // The group screen sets its own title (it changes to the group's name).
            GroupChatView().pushedScreen()
        case .newRoutine:
            RoutineEditorView().navigationTitle("New routine").pushedScreen()
        case .mission:
            MissionControlView().navigationTitle("Mission control").pushedScreen()
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
        HStack(spacing: 0) {
            ForEach(AppTab.allCases) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
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
                        if tab == .inbox, store.unreadInboxCount > 0 {
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
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
