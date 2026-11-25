import SwiftUI
import UIKit

/// A bot's reply with its Markdown shown properly: headings, lists, task lists, quotes,
/// code blocks with a Copy button, tables, and inline bold, italic, `code` and links.
struct MarkdownText: View {
    let text: String
    var size: Double = 15
    var color: Color = Theme.text
    /// The bot's color, for quote bars, bullets and links.
    var tint: Color = Color(hex: Theme.defaultAccentHex)
    @Environment(\.mentionTargets) private var mentionTargets
    /// Which reply this is, so its task list can be ticked (see TickLists). nil leaves the boxes as written.
    @Environment(\.tickListKey) private var tickListKey
    @Environment(\.printing) private var printing
    @ObservedObject private var tickLists = TickLists.shared
    /// Headings folded shut (see MarkdownSections), by their place in the reply.
    @State private var folded = Set<Int>()

    var body: some View {
        let blocks = Markdown.blocks(text)
        let reply = printing ? nil : tickListKey
        // A page shows everything, so folding is only on screen.
        let foldable = printing ? Set<Int>() : MarkdownSections.foldable(blocks)
        let hidden = MarkdownSections.hidden(blocks, folded: folded.intersection(foldable))
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                if foldable.contains(index), case .heading(let level, let text) = block {
                    foldingHeading(level: level, text: text, index: index, blocks: blocks)
                } else if !hidden.contains(index) {
                    view(for: block, index: index, reply: reply)
                }
            }
            if let reply {
                let progress = tickLists.progress(blocks, reply: reply)
                if progress.total >= 2 {
                    TickProgress(done: progress.done, total: progress.total, tint: tint)
                }
            }
        }
        .tint(tint)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock, index: Int, reply: String?) -> some View {
        switch block {
        case .paragraph(let text):
            inline(text)
        case .heading(let level, let text):
            inline(text, size: headingSize(level), weight: level <= 2 ? .bold : .semibold, color: Theme.textBright)
                .padding(.top, level <= 2 ? 4 : 2)
                .accessibilityAddTraits(.isHeader)
        case .bullet(let indent, let text, let checked):
            if let checked, let reply {
                let done = tickLists.isDone(reply, line: index, written: checked)
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        tickLists.toggle(reply, line: index, written: checked)
                    }
                } label: {
                    bullet(indent: indent, text: text, checked: done)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(done ? "Double tap to untick" : "Double tap to tick")
                .sensoryFeedback(.selection, trigger: done)
            } else {
                bullet(indent: indent, text: text, checked: checked)
            }
        case .numbered(let indent, let number, let text):
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(number).")
                    .font(.system(size: size, weight: .semibold).monospacedDigit())
                    .foregroundStyle(tint.opacity(0.9))
                inline(text)
            }
            .padding(.leading, CGFloat(indent) * 16)
        case .quote(let text):
            HStack(alignment: .top, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(tint.opacity(0.7))
                    .frame(width: 3)
                inline(text, color: Theme.sub)
            }
            .fixedSize(horizontal: false, vertical: true)
        case .code(let language, let code):
            CodeBlockView(language: language, code: code, size: size)
        case .table(let header, let rows):
            TableBlockView(header: header, rows: rows, size: size, tint: tint)
        case .rule:
            Rectangle()
                .fill(Color.white.opacity(0.12))
                .frame(height: 1)
                .padding(.vertical, 2)
        }
    }

    /// A heading you can tap to fold its section, with a chevron, and a note of what's folded.
    @ViewBuilder
    private func foldingHeading(level: Int, text: String, index: Int, blocks: [MarkdownBlock]) -> some View {
        let shut = folded.contains(index)
        // A heading inside a folded bigger section stays out of sight too.
        if !MarkdownSections.hidden(blocks, folded: folded.subtracting([index])).contains(index) {
            Button {
                withAnimation(.easeOut(duration: 0.2)) {
                    if shut { folded.remove(index) } else { folded.insert(index) }
                }
            } label: {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    inline(text, size: headingSize(level), weight: level <= 2 ? .bold : .semibold, color: Theme.textBright)
                    if shut {
                        Text(MarkdownSections.foldedNote(blocks, heading: index))
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundStyle(Theme.muted)
                    }
                    Spacer(minLength: 6)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(tint.opacity(0.8))
                        .rotationEffect(.degrees(shut ? -90 : 0))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, level <= 2 ? 4 : 2)
            .accessibilityAddTraits(.isHeader)
            .accessibilityValue(shut ? "Folded" : "Open")
            .accessibilityHint(shut ? "Double tap to open this part" : "Double tap to fold this part")
        }
    }

    private func bullet(indent: Int, text: String, checked: Bool?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 7) {
            if let checked {
                Image(systemName: checked ? "checkmark.square.fill" : "square")
                    .font(.system(size: size - 1, weight: .semibold))
                    .foregroundStyle(checked ? Theme.green : Theme.muted)
                    .accessibilityLabel(checked ? "Done" : "Not done")
            } else {
                Text(indent == 0 ? "•" : "◦")
                    .font(.system(size: size, weight: .bold))
                    .foregroundStyle(tint.opacity(0.9))
                    .accessibilityHidden(true)
            }
            inline(text, color: checked == true ? Theme.muted : color)
                .strikethrough(checked == true, color: Theme.muted)
        }
        .padding(.leading, CGFloat(indent) * 16)
    }

    private func headingSize(_ level: Int) -> Double {
        switch level {
        case 1: return size + 5
        case 2: return size + 3
        case 3: return size + 1.5
        default: return size
        }
    }

    private func inline(_ text: String, size: Double? = nil, weight: Font.Weight = .regular, color: Color? = nil) -> some View {
        let fontSize = size ?? self.size
        return Text(MarkdownText.styled(text, size: fontSize, mentions: mentionTargets))
            .font(.system(size: fontSize, weight: weight))
            .foregroundStyle(color ?? self.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Inline Markdown with `code` in a monospaced font on a soft background, bare web links made tappable, and
    /// @mentions of teammates bold and tappable when `mentions` has the team.
    static func styled(_ text: String, size: Double, mentions: [String: String] = [:]) -> AttributedString {
        var out = Mentions.linked(ChatLinks.linked(Markdown.inline(text)), targets: mentions)
        let codeRanges = out.runs.compactMap { run -> Range<AttributedString.Index>? in
            guard let intent = run.inlinePresentationIntent, intent.contains(.code) else { return nil }
            return run.range
        }
        var code = AttributeContainer()
        code[AttributeScopes.SwiftUIAttributes.FontAttribute.self] = Font.system(size: size - 1, design: .monospaced)
        code[AttributeScopes.SwiftUIAttributes.BackgroundColorAttribute.self] = Color.white.opacity(0.1)
        for range in codeRanges {
            out[range].mergeAttributes(code)
        }
        return out
    }
}

/// A fenced code block: the language, Wrap and Copy buttons, line numbers, and the code in color (see CodeHighlight),
/// scrolling sideways unless Wrap is on.
struct CodeBlockView: View {
    let language: String
    let code: String
    var size: Double = 15
    @State private var copied = false
    @AppStorage(CodeColors.wrapKey) private var wrap = false
    @Environment(\.printing) private var printing

    var body: some View {
        let lines = code.isEmpty ? 1 : code.components(separatedBy: "\n").count
        // A page can't scroll sideways, so code on a page always wraps and has no buttons.
        let wraps = wrap || printing
        let showNumbers = !wraps && lines >= CodeColors.numbersFrom
        let font = Font.system(size: max(11, size - 2), design: .monospaced)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.muted)
                Text(language.isEmpty ? (CodeHighlight.looksLikeDiff(code) ? "diff" : "Code") : language)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(1)
                if lines > 1 {
                    Text("\(lines) lines")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(Theme.muted)
                }
                Spacer(minLength: 8)
                if lines > 1, !printing {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { wrap.toggle() }
                    } label: {
                        Image(systemName: wrap ? "arrow.left.and.right.text.vertical" : "text.justify.leading")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(wrap ? Theme.goldText : Theme.sub)
                            .frame(width: 28, height: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(wrap ? "Stop wrapping lines" : "Wrap lines")
                }
                if !printing {
                    Button {
                        UIPasteboard.general.string = code
                        withAnimation(.easeOut(duration: 0.15)) { copied = true }
                        Task {
                            try? await Task.sleep(for: .seconds(1.6))
                            withAnimation(.easeOut(duration: 0.15)) { copied = false }
                        }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(copied ? Theme.green : Theme.sub)
                            .frame(minHeight: 28)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(copied ? "Copied" : "Copy code")
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.05))
            if wraps {
                Text(CodeColors.styled(code, language: language))
                    .font(font)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .textSelection(.enabled)
            } else {
                HStack(alignment: .top, spacing: 0) {
                    if showNumbers {
                        Text((1...lines).map(String.init).joined(separator: "\n"))
                            .font(font)
                            .foregroundStyle(Theme.muted.opacity(0.7))
                            .multilineTextAlignment(.trailing)
                            .fixedSize()
                            .padding(.vertical, 10)
                            .padding(.leading, 10)
                            .padding(.trailing, 8)
                            .background(Color.white.opacity(0.03))
                            .accessibilityHidden(true)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        Text(CodeColors.styled(code, language: language))
                            .font(font)
                            .fixedSize(horizontal: true, vertical: true)
                            .padding(10)
                            .textSelection(.enabled)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.black.opacity(0.35)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

/// A Markdown table, scrolling sideways when it's wider than the bubble.
struct TableBlockView: View {
    let header: [String]
    let rows: [[String]]
    var size: Double = 15
    var tint: Color = Color(hex: Theme.defaultAccentHex)
    @Environment(\.printing) private var printing

    var body: some View {
        Group {
            // A page can't scroll sideways, so a table on a page is drawn as it is.
            if printing {
                grid.frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollView(.horizontal, showsIndicators: false) { grid }
            }
        }
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }

    private var grid: some View {
            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                GridRow {
                    ForEach(Array(header.enumerated()), id: \.offset) { _, cell in
                        Text(MarkdownText.styled(cell, size: size - 1))
                            .font(.system(size: size - 1, weight: .bold))
                            .foregroundStyle(Theme.textBright)
                    }
                }
                Rectangle()
                    .fill(tint.opacity(0.5))
                    .frame(height: 1)
                    .gridCellUnsizedAxes(.horizontal)
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    GridRow {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, cell in
                            Text(MarkdownText.styled(cell, size: size - 1))
                                .font(.system(size: size - 1))
                                .foregroundStyle(Theme.text)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: 260, alignment: .leading)
                        }
                    }
                }
            }
            .padding(10)
    }
}
