import Foundation

struct ChatMessage: Identifiable, Equatable {
    enum Sender: Equatable {
        case me
        case agent(name: String)
    }

    let id = UUID()
    let sender: Sender
    let text: String
    let date: Date

    var isMine: Bool { sender == .me }

    var senderName: String {
        switch sender {
        case .me: return "You"
        case .agent(let name): return name
        }
    }
}
