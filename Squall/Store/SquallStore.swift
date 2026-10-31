import SwiftUI

/// Holds the crew and the team chat. Runs in demo mode for now:
/// replies are made on the phone until Squall desktop linking is added.
@MainActor
final class SquallStore: ObservableObject {
    @Published var agents: [Agent] = Agent.samples
    @Published private(set) var messages: [ChatMessage] = []
    @Published private(set) var isTyping = false

    init() {
        messages = [
            ChatMessage(
                sender: .agent(name: "Chief"),
                text: "Hey! I'm Chief. Send me a job and I'll hand it to the right teammate.",
                date: Date()
            )
        ]
    }

    var workingCount: Int {
        agents.filter { $0.status == .working }.count
    }

    func agent(with id: UUID) -> Agent? {
        agents.first { $0.id == id }
    }

    func setStatus(_ status: AgentStatus, for id: UUID) {
        guard let index = agents.firstIndex(where: { $0.id == id }) else { return }
        agents[index].status = status
    }

    func send(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(ChatMessage(sender: .me, text: text, date: Date()))
        isTyping = true
        let reply = makeReply(to: text)

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard let self else { return }
            self.isTyping = false
            self.messages.append(reply)
        }
    }

    private func makeReply(to text: String) -> ChatMessage {
        let lower = text.lowercased()
        let name: String
        let reply: String

        if lower.contains("code") || lower.contains("bug") || lower.contains("build") || lower.contains("script") {
            name = "Forge"
            reply = "I'll take that one. I'll write it, build it and test it before I hand it back."
        } else if lower.contains("design") || lower.contains("icon") || lower.contains("look") || lower.contains("color") {
            name = "Prism"
            reply = "On it. I'll sketch a couple of looks and send you the best one."
        } else if lower.contains("research") || lower.contains("find") || lower.contains("search") || lower.contains("compare") {
            name = "Scout"
            reply = "I'll dig into it and bring back a short answer."
        } else if lower.contains("write") || lower.contains("readme") || lower.contains("text") {
            name = "Echo"
            reply = "I'll draft it and keep it short and clear."
        } else {
            name = "Chief"
            reply = "Got it. Once the app is linked to Squall desktop, I'll send this to the team for real."
        }

        return ChatMessage(sender: .agent(name: name), text: reply, date: Date())
    }
}
