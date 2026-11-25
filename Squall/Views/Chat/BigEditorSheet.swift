import SwiftUI

/// Write a long message with room to breathe: Markdown buttons, a preview of how the teammate will see it, and Send.
struct BigEditorSheet: View {
    @Binding var draft: String
    let botName: String
    let tint: Color
    let onSend: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var preview = false
    @FocusState private var focused: Bool

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Picker("Mode", selection: $preview) {
                    Text("Write").tag(false)
                    Text("Preview").tag(true)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                if preview {
                    ScrollView {
                        Group {
                            if canSend {
                                MarkdownText(text: draft, tint: tint)
                            } else {
                                Text("Nothing to preview yet.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .glassCard(radius: 16, tint: nil, strength: 0.1)
                        .padding(.horizontal, 16)
                    }
                } else {
                    TextEditor(text: $draft)
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.text)
                        .scrollContentBackground(.hidden)
                        .focused($focused)
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.field))
                        .overlay(alignment: .topLeading) {
                            if draft.isEmpty {
                                Text("Message \(botName)…")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.muted)
                                    .padding(.horizontal, 15)
                                    .padding(.vertical, 18)
                                    .allowsHitTesting(false)
                            }
                        }
                        .padding(.horizontal, 16)
                    snippetRow
                }

                Text(BigEditor.counts(draft))
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(Theme.muted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 6)
            }
            .padding(.top, 8)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(botName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        onSend()
                        dismiss()
                    } label: {
                        Label("Send", systemImage: "arrow.up.circle.fill")
                            .labelStyle(.titleAndIcon)
                    }
                    .disabled(!canSend)
                }
            }
            .onAppear { focused = true }
        }
        .tint(tint)
        .preferredColorScheme(.dark)
    }

    private var snippetRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(BigEditor.Snippet.allCases) { snippet in
                    Button {
                        draft = BigEditor.add(snippet, to: draft)
                        focused = true
                    } label: {
                        Label(snippet.title, systemImage: snippet.icon)
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .buttonStyle(ChipButtonStyle(tint: tint, minHeight: 32))
                    .accessibilityLabel("Add \(snippet.title.lowercased())")
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }
}

/// A small button over the message box once a draft gets long, to finish it in the full editor.
struct BigEditorHint: View {
    let draft: String
    let tint: Color
    let open: () -> Void

    var body: some View {
        let show = BigEditor.shouldHint(draft)
        HStack {
            Spacer()
            if show {
                Button(action: open) {
                    Label("Open full editor", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(Theme.textBright)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Theme.field).overlay(Capsule().stroke(tint.opacity(0.45), lineWidth: 1)))
                }
                .buttonStyle(.plain)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, show ? 6 : 0)
        .animation(.easeOut(duration: 0.18), value: show)
    }
}
