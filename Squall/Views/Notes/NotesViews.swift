import SwiftUI

/// The book button in the Inbox header that opens Notes.
struct NotesButton: View {
    @EnvironmentObject private var store: SquallStore
    @EnvironmentObject private var lock: AppLock
    @State private var show = false

    var body: some View {
        Button {
            show = true
        } label: {
            Image(systemName: "book.closed.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.text)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.field))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Notes")
        .sheet(isPresented: $show) {
            NotesView()
                .lockCover()
                .environmentObject(store)
                .environmentObject(lock)
        }
    }
}

/// Search and read the notes in the Obsidian vault on the computer, and add to the end of one.
struct NotesView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var feed = HistoryFeed.shared

    @State private var words = ""
    @State private var asked: String?
    @State private var loading = false
    @State private var failed = false
    @State private var reading: String?

    var body: some View {
        let state = feedState
        NavigationStack {
            ZStack {
                GlowBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        searchField
                        if let state, !state.results.isEmpty {
                            Text(state.query.isEmpty ? "ALL NOTES · \(state.results.count)" : "\(state.results.count) FOUND")
                                .font(.system(size: 11.5, weight: .bold))
                                .tracking(1)
                                .foregroundColor(Theme.label)
                            VStack(spacing: 0) {
                                ForEach(Array(state.results.enumerated()), id: \.element.id) { index, row in
                                    NoteRow(row: row, accent: store.accent, isLast: index == state.results.count - 1) {
                                        open(row.path)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                            .glassCard(radius: 18)
                        } else {
                            empty(state)
                        }
                    }
                    .padding(16)
                    .readableColumn()
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .refreshable { await search(words) }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(item: $reading) { path in
                NoteReader(path: path)
            }
        }
        .preferredColorScheme(.dark)
        .task { await search("") }
        .task(id: words) {
            // Wait for a pause in typing before asking the computer.
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled, asked != nil, words.trimmingCharacters(in: .whitespaces) != asked else { return }
            await search(words)
        }
        .onDisappear {
            Task { await store.perform(VaultNotes.closeAction, quiet: true) }
        }
    }

    private var feedState: VaultNotes.State? {
        _ = feed.stamp
        return VaultNotes.state(from: feed.latest)
    }

    // MARK: - Parts

    private var searchField: some View {
        HStack(spacing: 8) {
            if loading {
                ProgressView().controlSize(.small).tint(Theme.muted)
            } else {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Theme.muted)
            }
            TextField("", text: $words, prompt: Text("Search your notes").foregroundColor(Theme.muted))
                .font(.system(size: 15))
                .foregroundColor(Theme.text)
                .submitLabel(.search)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .onSubmit { Task { await search(words) } }
            if !words.isEmpty {
                Button {
                    words = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .frame(height: 42)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
    }

    @ViewBuilder
    private func empty(_ state: VaultNotes.State?) -> some View {
        VStack(spacing: 10) {
            Image(systemName: failed ? "exclamationmark.triangle" : "book.closed")
                .font(.system(size: 28))
                .foregroundColor(Theme.muted)
            Text(emptyText(state))
                .font(.system(size: 14))
                .foregroundColor(Theme.sub)
                .multilineTextAlignment(.center)
            if failed {
                Button("Try again") { Task { await search(words) } }
                    .buttonStyle(GhostButtonStyle(height: 38, expand: false))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }

    private func emptyText(_ state: VaultNotes.State?) -> String {
        if !store.isConnected { return "Connect to your computer to see your notes." }
        if failed { return "Couldn't load your notes. Make sure Squall on your computer is up to date." }
        if loading || state == nil { return "Loading your notes…" }
        if !state!.query.isEmpty { return "No notes match \"\(state!.query)\"." }
        return "Your vault has no notes yet. Notes your team writes show up here."
    }

    @MainActor
    private func search(_ text: String) async {
        let query = text.trimmingCharacters(in: .whitespacesAndNewlines)
        asked = query
        loading = true
        defer { loading = false }
        let reply = await store.perform(VaultNotes.searchAction(query), busyKey: "notes.search", quiet: true)
        failed = reply == nil && store.isConnected
    }

    private func open(_ path: String) {
        reading = path
        Task {
            if await store.perform(VaultNotes.openAction(path), busyKey: "notes.open", quiet: true) == nil {
                store.showToast("Couldn't open that note.")
            }
        }
    }
}

/// One search result: the note's name, its folder and a bit of what it says.
private struct NoteRow: View {
    let row: VaultNotes.Row
    let accent: Color
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(accent)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(accent.opacity(0.16)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(row.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.textBright)
                        .lineLimit(1)
                    if !row.folder.isEmpty {
                        Text(row.folder)
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(Theme.label)
                            .lineLimit(1)
                    }
                    if !row.snippet.isEmpty {
                        Text(VaultNotes.plain(row.snippet))
                            .font(.system(size: 13))
                            .foregroundColor(Theme.sub)
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Theme.muted)
                    .padding(.top, 8)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle().fill(Theme.cardBorder).frame(height: 1).padding(.leading, 58)
            }
        }
    }
}

/// One note, read nicely, with a box at the bottom to add to the end of it.
struct NoteReader: View {
    let path: String

    @EnvironmentObject private var store: SquallStore
    @ObservedObject private var feed = HistoryFeed.shared
    @FocusState private var typing: Bool
    @State private var addition = ""
    @State private var adding = false

    var body: some View {
        let note = currentNote
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let note {
                        Text(note.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundColor(Theme.textBright)
                        Text(note.path)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Theme.label)
                            .padding(.bottom, 6)
                        let blocks = VaultNotes.blocks(note.text)
                        if blocks.isEmpty {
                            Text("This note is empty.")
                                .font(.system(size: 14))
                                .foregroundColor(Theme.sub)
                        }
                        ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                            BlockView(block: block, accent: store.accent)
                        }
                        if note.cut {
                            Label("This note is long. Open it on your computer to read the rest.", systemImage: "scissors")
                                .font(.system(size: 12.5, weight: .medium))
                                .foregroundColor(Theme.yellow)
                                .padding(.top, 8)
                        }
                    } else {
                        ProgressView()
                            .tint(Theme.muted)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .readableColumn()
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom) {
            if note != nil { addBar }
        }
        .navigationTitle(note?.name ?? "Note")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var currentNote: VaultNotes.Note? {
        _ = feed.stamp
        guard let note = VaultNotes.state(from: feed.latest)?.note, note.path == path else { return nil }
        return note
    }

    private var addBar: some View {
        let text = addition.trimmingCharacters(in: .whitespacesAndNewlines)
        let tooLong = addition.count > VaultNotes.maxAdd
        return VStack(alignment: .trailing, spacing: 4) {
            HStack(alignment: .bottom, spacing: 8) {
                TextField("", text: $addition, prompt: Text("Add to the end of this note").foregroundColor(Theme.muted), axis: .vertical)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.text)
                    .lineLimit(1...5)
                    .focused($typing)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.field))
                Button {
                    Task { await add(text) }
                } label: {
                    Group {
                        if adding {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "plus")
                                .font(.system(size: 16, weight: .bold))
                        }
                    }
                    .foregroundColor(.white)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(text.isEmpty || tooLong ? Theme.field : store.accent))
                }
                .buttonStyle(.plain)
                .disabled(text.isEmpty || tooLong || adding)
                .accessibilityLabel("Add to note")
            }
            if tooLong {
                Text("Keep it under \(VaultNotes.maxAdd) characters.")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(Theme.redText)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }

    @MainActor
    private func add(_ text: String) async {
        guard !text.isEmpty else { return }
        adding = true
        defer { adding = false }
        let reply = await store.perform(VaultNotes.appendAction(path: path, text: text), busyKey: "notes.append")
        if reply != nil {
            addition = ""
            typing = false
            store.showToast("Added to \(currentNote?.name ?? VaultNotes.noteName(path)).")
        }
    }
}

/// Draws one block of a note.
private struct BlockView: View {
    let block: VaultNotes.Block
    let accent: Color

    var body: some View {
        switch block {
        case .heading(let level, let text):
            Text(inline(text))
                .font(.system(size: level == 1 ? 22 : level == 2 ? 19 : 16.5, weight: .bold))
                .foregroundColor(Theme.textBright)
                .padding(.top, level <= 2 ? 8 : 4)
        case .bullet(let text, let done):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let done {
                    Image(systemName: done ? "checkmark.square.fill" : "square")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(done ? accent : Theme.muted)
                } else {
                    Circle().fill(Theme.muted).frame(width: 5, height: 5).offset(y: -3)
                }
                Text(inline(text))
                    .font(.system(size: 15))
                    .foregroundColor(done == true ? Theme.muted : Theme.text)
                    .strikethrough(done == true, color: Theme.muted)
            }
            .padding(.leading, 4)
        case .quote(let text):
            Text(inline(text))
                .font(.system(size: 15).italic())
                .foregroundColor(Theme.sub)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2).fill(accent.opacity(0.7)).frame(width: 3)
                }
        case .code(let text):
            ScrollView(.horizontal, showsIndicators: false) {
                Text(text)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(Theme.commandText)
                    .padding(12)
            }
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.35)))
        case .text(let text):
            Text(inline(text))
                .font(.system(size: 15))
                .foregroundColor(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        case .gap:
            Color.clear.frame(height: 4)
        }
    }

    /// Bold, italic, code and links inside a line.
    private func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}
