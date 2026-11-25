import SwiftUI
import UIKit

/// The book in a chat's header. It opens Saved prompts for this chat.
struct SavedPromptsButton: View {
    let bot: Bot

    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    @State private var show = false
    @State private var draft = ""

    var body: some View {
        Button {
            draft = SavedPrompts.shared.currentDraft
            show = true
        } label: {
            Image(systemName: "text.book.closed.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.sub)
                .frame(width: 32, height: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Saved prompts")
        .sheet(isPresented: $show) {
            SavedPromptsView(botName: bot.name, tintHex: bot.hex, draft: draft) { text in
                SavedPrompts.shared.insert = SavedPrompts.Insert(chatID: bot.id, text: text)
            } send: { text in
                store.send(text, to: bot.id)
            }
            .lockCover()
            .environmentObject(store)
            .environmentObject(lock)
            .presentationDetents([.medium, .large])
        }
    }
}

/// Every saved prompt: search, sort, tap to put one in the message box, or send it right away.
struct SavedPromptsView: View {
    let botName: String
    let tintHex: UInt32
    /// What's in the message box now, so it can be saved as a prompt.
    let draft: String
    let insert: (String) -> Void
    let send: (String) -> Void

    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var prompts = SavedPrompts.shared
    @AppStorage("squall.savedPrompts.order") private var orderRaw = SavedPrompts.Order.mostUsed.rawValue
    @State private var words = ""
    @State private var editing: PromptEditor.Target?
    @State private var confirmDelete: SavedPrompts.Item?

    private var order: SavedPrompts.Order { SavedPrompts.Order(rawValue: orderRaw) ?? .mostUsed }

    var body: some View {
        let list = SavedPrompts.sorted(SavedPrompts.filter(prompts.items, words: words), by: order)
        NavigationStack {
            ZStack {
                GlowBackground(topHex: tintHex)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if canSaveDraft {
                            saveDraftCard
                        }
                        if prompts.items.count > 1 {
                            orderPicker
                        }
                        if list.isEmpty {
                            empty
                        } else {
                            LazyVStack(spacing: 10) {
                                ForEach(list) { item in
                                    row(item)
                                        .transition(.opacity.combined(with: .scale(scale: 0.97)))
                                }
                            }
                        }
                        if !prompts.items.isEmpty {
                            Text("Tip: write {name} for the teammate's name and {today} for today's date.")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.muted)
                                .padding(.top, 4)
                        }
                    }
                    .padding(16)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .animation(.easeOut(duration: 0.2), value: list)
            .navigationTitle("Saved prompts")
            .navigationBarTitleDisplayMode(.inline)
            .searchable(text: $words, placement: .navigationBarDrawer(displayMode: .automatic), prompt: "Search prompts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        editing = .new(text: "")
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("New prompt")
                    .disabled(prompts.items.count >= SavedPrompts.maxItems)
                }
            }
            .sheet(item: $editing) { target in
                PromptEditor(target: target)
                    .environmentObject(store)
                    .presentationDetents([.large])
            }
            .confirmationDialog("Delete this prompt?", isPresented: deleteBinding, titleVisibility: .visible,
                                presenting: confirmDelete) { item in
                Button("Delete \"\(item.title)\"", role: .destructive) {
                    prompts.remove(item.id)
                }
            } message: { _ in
                Text("Messages you already sent with it stay in their chats.")
            }
        }
        .preferredColorScheme(.dark)
    }

    private var deleteBinding: Binding<Bool> {
        Binding(get: { confirmDelete != nil }, set: { if !$0 { confirmDelete = nil } })
    }

    private var canSaveDraft: Bool {
        !SavedPrompts.cleanText(draft).isEmpty && prompts.problem(text: draft) == nil
    }

    // MARK: - Parts

    private var saveDraftCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Save what you typed")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Text(SavedPrompts.cleanText(draft))
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(2)
            }
            Spacer(minLength: 4)
            Button("Save") {
                editing = .new(text: draft)
            }
            .buttonStyle(GhostButtonStyle(height: 34, expand: false, fontSize: 13.5, sidePadding: 14))
        }
        .padding(14)
        .glassCard(radius: 18, tint: store.accentHex, strength: 0.12)
    }

    private var orderPicker: some View {
        HStack(spacing: 8) {
            ForEach(SavedPrompts.Order.allCases) { choice in
                Button(choice.label) { orderRaw = choice.rawValue }
                    .buttonStyle(ChipButtonStyle(isOn: order == choice, tint: Color(hex: tintHex)))
            }
        }
    }

    private var empty: some View {
        VStack(spacing: 10) {
            Image(systemName: prompts.items.isEmpty ? "text.book.closed" : "magnifyingglass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Color(hex: tintHex))
            Text(prompts.items.isEmpty ? "No saved prompts yet" : "Nothing matches")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.textBright)
            Text(prompts.items.isEmpty
                 ? "Save messages you send a lot, like \"Run the tests and tell me what broke.\" Tap + to add one, or press and hold one of your messages and tap Save as prompt."
                 : "Try other words.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
            if prompts.items.isEmpty {
                Button("New prompt") { editing = .new(text: "") }
                    .buttonStyle(GhostButtonStyle(height: 38, expand: false, fontSize: 14, sidePadding: 16))
                    .padding(.top, 6)
            }
        }
        .padding(.vertical, 40)
        .frame(maxWidth: .infinity)
    }

    private func row(_ item: SavedPrompts.Item) -> some View {
        let preview = SavedPrompts.fill(item.text, name: botName)
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                if let text = prompts.use(item.id, name: botName) {
                    insert(text)
                    dismiss()
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(item.title)
                            .font(.system(size: 14.5, weight: .bold))
                            .foregroundStyle(Theme.textBright)
                            .lineLimit(1)
                        if SavedPrompts.hasBlanks(item.text) {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(Color(hex: tintHex))
                                .accessibilityLabel("Fills in blanks")
                        }
                        Spacer(minLength: 4)
                        Text(usesText(item))
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.muted)
                    }
                    Text(preview)
                        .font(.system(size: 13.5))
                        .foregroundStyle(Theme.sub)
                        .lineLimit(3)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Puts it in the message box")
            HStack(spacing: 8) {
                Button("Send to \(botName)") {
                    if let text = prompts.use(item.id, name: botName) {
                        send(text)
                        dismiss()
                    }
                }
                .buttonStyle(GhostButtonStyle(height: 34, expand: false, foreground: Theme.textBright,
                                              border: Color(hex: tintHex).opacity(0.6), fontSize: 13.5, sidePadding: 14))
                .disabled(!store.isConnected)
                Spacer(minLength: 0)
                Menu {
                    Button {
                        editing = .edit(item)
                    } label: {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button {
                        UIPasteboard.general.string = preview
                        store.showToast("Copied.")
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    Button(role: .destructive) {
                        confirmDelete = item
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.sub)
                        .frame(width: 34, height: 34)
                }
                .accessibilityLabel("More for \(item.title)")
            }
        }
        .padding(14)
        .glassCard(radius: 18, tint: tintHex, strength: 0.08)
    }

    private func usesText(_ item: SavedPrompts.Item) -> String {
        switch item.uses {
        case 0: return "Not used yet"
        case 1: return "Used once"
        default: return "Used \(item.uses) times"
        }
    }
}

/// Make a new prompt or change one.
struct PromptEditor: View {
    enum Target: Identifiable {
        case new(text: String)
        case edit(SavedPrompts.Item)

        var id: String {
            switch self {
            case .new: return "new"
            case .edit(let item): return item.id
            }
        }
    }

    let target: Target

    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var prompts = SavedPrompts.shared
    @State private var title = ""
    @State private var text = ""
    @State private var loaded = false
    @FocusState private var textFocused: Bool

    private var editingID: String? {
        if case .edit(let item) = target { return item.id }
        return nil
    }

    var body: some View {
        let problem = prompts.problem(text: text, editing: editingID)
        let empty = SavedPrompts.cleanText(text).isEmpty
        NavigationStack {
            ZStack {
                GlowBackground(topHex: store.accentHex)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        field("NAME") {
                            TextField("", text: $title,
                                      prompt: Text(SavedPrompts.cleanTitle("", text: text)).foregroundStyle(Theme.muted))
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.text)
                        }
                        field("PROMPT") {
                            TextField("", text: $text, prompt: Text("Run the tests and tell me what broke.").foregroundStyle(Theme.muted),
                                      axis: .vertical)
                                .lineLimit(4...14)
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.text)
                                .focused($textFocused)
                        }
                        HStack(spacing: 8) {
                            Button("Add {name}") { text += text.isEmpty || text.hasSuffix(" ") ? "{name}" : " {name}" }
                                .buttonStyle(ChipButtonStyle(tint: store.accent))
                            Button("Add {today}") { text += text.isEmpty || text.hasSuffix(" ") ? "{today}" : " {today}" }
                                .buttonStyle(ChipButtonStyle(tint: store.accent))
                        }
                        Text("{name} becomes the teammate's name and {today} becomes today's date when you use it.")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.muted)
                        if let problem, !empty {
                            Text(problem)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.redText)
                        }
                        Text("\(SavedPrompts.cleanText(text).count) of \(SavedPrompts.maxText) characters")
                            .font(.system(size: 11.5))
                            .foregroundStyle(Theme.muted)
                    }
                    .padding(16)
                    .readableColumn()
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(editingID == nil ? "New prompt" : "Edit prompt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(problem != nil)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            guard !loaded else { return }
            loaded = true
            switch target {
            case .new(let start):
                text = SavedPrompts.cleanText(start)
            case .edit(let item):
                title = item.title
                text = item.text
            }
            if text.isEmpty { textFocused = true }
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(Theme.label)
            content()
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
        }
    }

    private func save() {
        let done: Bool
        if let editingID {
            done = prompts.update(editingID, title: title, text: text)
        } else {
            done = prompts.add(title: title, text: text) != nil
        }
        if done {
            store.showToast(editingID == nil ? "Prompt saved." : "Prompt changed.")
            dismiss()
        }
    }
}
