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

    var body: some View {
        let blocks = Markdown.blocks(text)
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { _, block in
                view(for: block)
            }
        }
        .tint(tint)
    }

    @ViewBuilder
    private func view(for block: MarkdownBlock) -> some View {
        switch block {
        case .paragraph(let text):
            inline(text)
        case .heading(let level, let text):
            inline(text, size: headingSize(level), weight: level <= 2 ? .bold : .semibold, color: Theme.textBright)
                .padding(.top, level <= 2 ? 4 : 2)
                .accessibilityAddTraits(.isHeader)
        case .bullet(let indent, let text, let checked):
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
            }
            .padding(.leading, CGFloat(indent) * 16)
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
        return Text(MarkdownText.styled(text, size: fontSize))
            .font(.system(size: fontSize, weight: weight))
            .foregroundStyle(color ?? self.color)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Inline Markdown with `code` in a monospaced font on a soft background.
    static func styled(_ text: String, size: Double) -> AttributedString {
        var out = Markdown.inline(text)
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

/// A fenced code block: the language, a Copy button, and the code scrolling sideways so lines never wrap.
struct CodeBlockView: View {
    let language: String
    let code: String
    var size: Double = 15
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "chevron.left.forwardslash.chevron.right")
                    .font(.system(size: 10.5, weight: .bold))
                    .foregroundStyle(Theme.muted)
                Text(language.isEmpty ? "Code" : language)
                    .font(.system(size: 11.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(Theme.sub)
                    .lineLimit(1)
                Spacer(minLength: 8)
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
            .padding(.horizontal, 10)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.05))
            ScrollView(.horizontal, showsIndicators: false) {
                Text(code.isEmpty ? " " : code)
                    .font(.system(size: max(11, size - 2), design: .monospaced))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: true, vertical: true)
                    .padding(10)
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

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
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
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.white.opacity(0.04)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(Color.white.opacity(0.1), lineWidth: 1))
    }
}
