import SwiftUI

struct RootView: View {
    enum AppTab: Hashable {
        case team
        case chat
        case settings
    }

    @State private var selectedTab: AppTab = .team

    var body: some View {
        TabView(selection: $selectedTab) {
            TeamView(openChat: { selectedTab = .chat })
                .tabItem { Label("Team", systemImage: "person.3.fill") }
                .tag(AppTab.team)

            ChatView()
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right.fill") }
                .tag(AppTab.chat)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(AppTab.settings)
        }
        .tint(Theme.accent)
    }
}

#Preview {
    RootView()
        .environmentObject(SquallStore())
        .preferredColorScheme(.dark)
}
