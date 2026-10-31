import SwiftUI

struct TeamView: View {
    @EnvironmentObject private var store: SquallStore
    var openChat: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    header
                    ForEach(store.agents) { agent in
                        NavigationLink(value: agent.id) {
                            AgentRow(agent: agent)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Squall")
            .navigationDestination(for: UUID.self) { id in
                AgentDetailView(agentID: id, openChat: openChat)
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .foregroundStyle(Theme.bolt)
                Text("Your AI team")
                    .font(.headline)
                Spacer()
            }
            Text("\(store.workingCount) of \(store.agents.count) teammates working")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
            Button(action: openChat) {
                Label("Talk to Chief", systemImage: "bubble.left.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.top, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
    }
}

#Preview {
    TeamView(openChat: {})
        .environmentObject(SquallStore())
        .preferredColorScheme(.dark)
}
