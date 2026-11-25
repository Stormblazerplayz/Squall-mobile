import SwiftUI
import UIKit

/// Problems in this chat, from Browse this chat: every error the teammate hit, newest first. Tap to copy it (to paste
/// into a message asking for a fix), press and hold to ask the teammate to fix it or go to its message.
struct ChatProblemsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: SquallStore
    let bot: Bot
    let messages: [ChatMessage]

    var body: some View {
        let all = ChatProblemList.entries(messages)
        NavigationStack {
            Group {
                if all.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.seal")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundStyle(Theme.green)
                        Text("No problems")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.textBright)
                        Text("\(bot.name) hasn't hit any problems in this chat.")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.sub)
                            .multilineTextAlignment(.center)
                    }
                    .padding(30)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        Section {
                            ForEach(all) { entry in
                                row(entry)
                                    .listRowBackground(Color.white.opacity(0.05))
                            }
                        } header: {
                            Text(ChatProblemList.summary(all))
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Problems")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                if !all.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        Menu {
                            Button {
                                UIPasteboard.general.string = ChatProblemList.report(all, name: bot.name)
                                store.showToast(all.count == 1 ? "Problem copied." : "\(all.count) problems copied.")
                            } label: {
                                Label("Copy all problems", systemImage: "doc.on.doc")
                            }
                            ShareLink(item: ChatProblemList.report(all, name: bot.name)) {
                                Label("Share the problems", systemImage: "square.and.arrow.up")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                        .accessibilityLabel("Problem actions")
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .preferredColorScheme(.dark)
    }

    private func row(_ entry: ChatProblemList.Entry) -> some View {
        Button {
            copy(entry)
        } label: {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.red)
                    .frame(width: 32, height: 32)
                    .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(Theme.red.opacity(0.16)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                        .lineLimit(2)
                    Text(byline(entry))
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                if entry.count > 1 {
                    Text("×\(entry.count)")
                        .font(.system(size: 12, weight: .bold).monospacedDigit())
                        .foregroundStyle(Theme.red)
                        .padding(.top, 2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(spoken(entry))
        .accessibilityHint("Copies the problem")
        .contextMenu {
            Button {
                copy(entry)
            } label: {
                Label("Copy the problem", systemImage: "doc.on.doc")
            }
            Button {
                ask(entry)
            } label: {
                Label("Ask \(bot.name) to fix it", systemImage: "wrench.and.screwdriver")
            }
            Button {
                dismiss()
                ChatDayJump.Model.shared.go(chatID: bot.id, messageID: entry.messageID)
            } label: {
                Label("Go to message", systemImage: "text.bubble")
            }
        }
    }

    private func spoken(_ entry: ChatProblemList.Entry) -> String {
        let times = entry.count > 1 ? ", \(entry.count) times" : ""
        return "\(entry.title)\(times), \(byline(entry))"
    }

    private func byline(_ entry: ChatProblemList.Entry) -> String {
        guard let at = entry.at else { return entry.time.isEmpty ? bot.name : "\(bot.name) · \(entry.time)" }
        return "\(bot.name) · \(TeamHistory.dayTitle(at)), \(TeamHistory.clock(at))"
    }

    /// Puts the ask and the error in this chat's message box, for you to send.
    private func ask(_ entry: ChatProblemList.Entry) {
        dismiss()
        SavedPrompts.shared.insert = SavedPrompts.Insert(chatID: bot.id, text: ChatProblemList.askDraft(entry))
    }

    private func copy(_ entry: ChatProblemList.Entry) {
        UIPasteboard.general.string = entry.text
        store.showToast("Problem copied.")
    }
}
