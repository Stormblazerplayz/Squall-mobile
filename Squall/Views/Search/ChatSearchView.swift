import SwiftUI

/// Search every chat with a teammate. Tap a result to open that chat right at the message.
struct ChatSearchView: View {
    @EnvironmentObject private var store: SquallStore
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""
    /// A bot id to search only that chat, or nil for every chat.
    @State private var only: String?
    @FocusState private var fieldFocused: Bool
    @AppStorage(ChatSearchView.recentKey) private var recentText = ""

    static let recentKey = "squall.recentSearches"
    private static let maxRecent = 6

    private var recent: [String] {
        recentText.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    private var chats: [ChatSearch.Chat] {
        store.displayBots.map { ChatSearch.Chat(id: $0.id, messages: store.messages(for: $0.id)) }
    }

    var body: some View {
        // Every chat's hits, so the chips can show counts; the list shows the picked chat's.
        let all = ChatSearch.run(query, in: chats)
        let hits = only.map { id in all.filter { $0.chatID == id } } ?? all
        ZStack {
            GlowBackground()
            VStack(alignment: .leading, spacing: 12) {
                header
                searchField
                if !store.displayBots.isEmpty {
                    scopeChips(all)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if ChatSearch.words(query).isEmpty {
                            startState
                        } else if hits.isEmpty {
                            noResults
                        } else {
                            summary(hits)
                            ForEach(groups(hits)) { group in
                                section(group.chatID, hits: group.hits)
                            }
                        }
                    }
                    .padding(.bottom, 24)
                    .animation(.easeOut(duration: 0.18), value: hits.map(\.id))
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .readableColumn(Theme.readableWidth)
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { fieldFocused = true }
        }
    }

    // MARK: - Top

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Search")
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(Theme.textBright)
            Spacer()
            Button("Done") { dismiss() }
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(store.accent)
                .keyboardShortcut(.cancelAction)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(fieldFocused ? store.accent : Theme.sub)
            TextField("", text: $query, prompt: Text("Search every chat").foregroundColor(Theme.muted))
                .focused($fieldFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .onSubmit { remember(query) }
                .foregroundStyle(Theme.textBright)
                .font(.system(size: 16))
            if !query.isEmpty {
                Button {
                    query = ""
                    fieldFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.muted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.field))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(fieldFocused ? store.accent.opacity(0.7) : Theme.cardBorder, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.15), value: fieldFocused)
    }

    private func scopeChips(_ all: [ChatSearch.Hit]) -> some View {
        let counts = Dictionary(grouping: all, by: \.chatID).mapValues(\.count)
        let searching = !ChatSearch.words(query).isEmpty
        return ScrollView(.horizontal) {
            HStack(spacing: 8) {
                scopeChip(title: "All chats", hex: nil, count: searching ? all.count : nil, isOn: only == nil) {
                    only = nil
                }
                ForEach(store.displayBots) { bot in
                    scopeChip(title: bot.name, hex: bot.hex, count: searching ? (counts[bot.id] ?? 0) : nil, isOn: only == bot.id) {
                        only = only == bot.id ? nil : bot.id
                    }
                }
            }
            .padding(.vertical, 2)
        }
        .scrollIndicators(.hidden)
    }

    private func scopeChip(title: String, hex: UInt32?, count: Int?, isOn: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let hex {
                    Sphere(hex: hex, letter: String(title.prefix(1)).uppercased(), size: 18, glow: 0)
                }
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                if let count {
                    Text("\(count)")
                        .font(.system(size: 11.5, weight: .bold).monospacedDigit())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(Capsule().fill(Color.white.opacity(isOn ? 0.22 : 0.08)))
                }
            }
            .foregroundStyle(isOn ? Theme.textBright : Theme.text)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(Capsule().fill(isOn ? store.accent.opacity(0.32) : Theme.field))
            .overlay(Capsule().stroke(isOn ? store.accent.opacity(0.8) : Theme.cardBorder, lineWidth: 1))
            .opacity(count == 0 && !isOn ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count.map { "\(title), \($0) found" } ?? title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // MARK: - Before typing, and nothing found

    private var startState: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !recent.isEmpty {
                HStack {
                    SectionLabel(text: "Recent")
                    Spacer()
                    Button("Clear") { recentText = "" }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.sub)
                }
                VStack(spacing: 0) {
                    ForEach(recent, id: \.self) { item in
                        Button {
                            query = item
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "clock.arrow.circlepath")
                                    .foregroundStyle(Theme.muted)
                                Text(item)
                                    .foregroundStyle(Theme.text)
                                    .lineLimit(1)
                                Spacer()
                                Image(systemName: "arrow.up.left")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Theme.muted)
                            }
                            .font(.system(size: 15))
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if item != recent.last {
                            Rectangle().fill(Theme.cardBorder).frame(height: 1).padding(.leading, 40)
                        }
                    }
                }
                .glassCard(radius: 16, strength: 0.06)
            }
            VStack(spacing: 10) {
                Image(systemName: "text.magnifyingglass")
                    .font(.system(size: 34))
                    .foregroundStyle(store.accent)
                Text("Find anything your team said")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.textBright)
                Text("Searches every chat on your computer. Every word you type has to be in the message.")
                    .font(.system(size: 13.5))
                    .foregroundStyle(Theme.sub)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        }
    }

    private var noResults: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 30))
                .foregroundStyle(Theme.sub)
            Text("Nothing found for “\(query.trimmingCharacters(in: .whitespaces))”")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textBright)
                .multilineTextAlignment(.center)
            Text(only == nil ? "Try fewer words." : "Try all chats, or fewer words.")
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
            if only != nil {
                Button("Search all chats") { only = nil }
                    .buttonStyle(GhostButtonStyle(height: 38, expand: false, fontSize: 14))
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 36)
    }

    // MARK: - Results

    private func summary(_ hits: [ChatSearch.Hit]) -> some View {
        let chatCount = Set(hits.map(\.chatID)).count
        let messages = hits.count >= ChatSearch.maxHits ? "\(ChatSearch.maxHits)+ messages" : "\(hits.count) message\(hits.count == 1 ? "" : "s")"
        return Text("\(messages) in \(chatCount) chat\(chatCount == 1 ? "" : "s")")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(Theme.sub)
    }

    private struct ChatGroup: Identifiable {
        let chatID: String
        let hits: [ChatSearch.Hit]
        var id: String { chatID }
    }

    private func groups(_ hits: [ChatSearch.Hit]) -> [ChatGroup] {
        var order: [String] = []
        var byChat: [String: [ChatSearch.Hit]] = [:]
        for hit in hits {
            if byChat[hit.chatID] == nil { order.append(hit.chatID) }
            byChat[hit.chatID, default: []].append(hit)
        }
        return order.map { ChatGroup(chatID: $0, hits: byChat[$0] ?? []) }
    }

    private func section(_ chatID: String, hits: [ChatSearch.Hit]) -> some View {
        let bot = store.bot(chatID)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                if let bot {
                    Sphere(bot: bot, size: 24, glow: 0.25)
                }
                Text(bot?.name ?? "Chat")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Theme.textBright)
                Text("\(hits.count)")
                    .font(.system(size: 12, weight: .bold).monospacedDigit())
                    .foregroundStyle(Theme.sub)
                Spacer()
            }
            VStack(spacing: 8) {
                ForEach(hits) { hit in
                    row(hit, bot: bot)
                }
            }
        }
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private func row(_ hit: ChatSearch.Hit, bot: Bot?) -> some View {
        let tint = bot?.hex ?? Theme.goldHex
        return Button {
            open(hit)
        } label: {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(authorName(hit.author))
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(hit.author == ChatMessage.meID ? store.accent : Color.shade(tint, towardWhite: true, 0.35))
                    Spacer()
                    Text(hit.time)
                        .font(.system(size: 11.5))
                        .foregroundStyle(Theme.muted)
                }
                Text(highlighted(hit))
                    .font(.system(size: 14))
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassCard(radius: 14, tint: tint, strength: 0.07)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(authorName(hit.author)) at \(hit.time): \(hit.snippet)")
        .accessibilityHint("Opens the chat at this message")
    }

    private func authorName(_ author: String) -> String {
        if author == ChatMessage.meID { return "You" }
        return store.bot(author)?.name ?? "Squall"
    }

    /// The snippet with the search words picked out in the accent color.
    private func highlighted(_ hit: ChatSearch.Hit) -> AttributedString {
        let chars = Array(hit.snippet)
        var out = AttributedString()
        var cursor = 0
        func add(_ from: Int, _ to: Int, bright: Bool) {
            guard from < to else { return }
            var piece = AttributedString(String(chars[from..<to]))
            piece.foregroundColor = bright ? Theme.textBright : Theme.text
            if bright {
                piece.backgroundColor = store.accent.opacity(0.35)
                piece.font = .system(size: 14, weight: .bold)
            }
            out.append(piece)
        }
        for range in hit.matches {
            let start = min(max(range.lowerBound, cursor), chars.count)
            let end = min(range.upperBound, chars.count)
            add(cursor, start, bright: false)
            add(start, end, bright: true)
            cursor = max(cursor, end)
        }
        add(cursor, chars.count, bright: false)
        return out
    }

    private func open(_ hit: ChatSearch.Hit) {
        remember(query)
        SearchJump.shared.target = SearchJump.Target(chatID: hit.chatID, messageID: hit.messageID)
        store.openChat(hit.chatID)
        dismiss()
    }

    private func remember(_ raw: String) {
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        let list = [text] + recent.filter { $0.caseInsensitiveCompare(text) != .orderedSame }
        recentText = list.prefix(Self.maxRecent).joined(separator: "\n")
    }
}
