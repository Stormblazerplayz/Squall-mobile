import Foundation

/// Which Browse this chat list is open (Links, Code, To-dos or Chat stats). Shared so the ••• menu and the keyboard
/// shortcuts open the same sheet.
enum ChatBrowse {
    enum Sheet: String, Identifiable, CaseIterable {
        case links, code, todos, stats

        var id: String { rawValue }

        var title: String {
            switch self {
            case .links: return "Links"
            case .code: return "Code"
            case .todos: return "To-dos"
            case .stats: return "Chat stats"
            }
        }

        var symbol: String {
            switch self {
            case .links: return "link"
            case .code: return "chevron.left.forwardslash.chevron.right"
            case .todos: return "checklist"
            case .stats: return "chart.bar"
            }
        }

        /// The key that opens it with ⌘⇧.
        var key: Character {
            switch self {
            case .links: return "l"
            case .code: return "c"
            case .todos: return "t"
            case .stats: return "i"
            }
        }
    }

    final class Model: ObservableObject {
        static let shared = Model()
        @Published var sheet: Sheet?
    }
}
