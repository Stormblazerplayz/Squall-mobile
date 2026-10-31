import SwiftUI

struct AgentDetailView: View {
    @EnvironmentObject private var store: SquallStore
    let agentID: UUID
    var openChat: () -> Void

    var body: some View {
        Group {
            if let agent = store.agent(with: agentID) {
                content(for: agent)
            } else {
                ContentUnavailableView("Teammate not found", systemImage: "person.fill.questionmark")
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
    }

    private func content(for agent: Agent) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                AgentAvatar(agent: agent, size: 96)
                    .padding(.top, 8)

                VStack(spacing: 6) {
                    Text(agent.name)
                        .font(.largeTitle.bold())
                    Text(agent.role)
                        .foregroundStyle(Theme.textSecondary)
                }

                StatusPill(status: agent.status)

                VStack(alignment: .leading, spacing: 10) {
                    Text("About")
                        .font(.headline)
                    Text(agent.summary)
                        .foregroundStyle(Theme.textSecondary)
                    Divider()
                        .overlay(Theme.cardBorder)
                    Text("Current task")
                        .font(.headline)
                    Text(agent.currentTask)
                        .foregroundStyle(Theme.textSecondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Status")
                        .font(.headline)
                    Picker("Status", selection: statusBinding) {
                        ForEach(AgentStatus.allCases) { status in
                            Text(status.label).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()

                Button(action: openChat) {
                    Label("Open team chat", systemImage: "bubble.left.and.bubble.right.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding()
        }
    }

    private var statusBinding: Binding<AgentStatus> {
        Binding(
            get: { store.agent(with: agentID)?.status ?? .idle },
            set: { store.setStatus($0, for: agentID) }
        )
    }
}
