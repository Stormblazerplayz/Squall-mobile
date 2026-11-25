import Foundation

/// Copy a table from a teammate's reply: as tab-separated text that pastes straight into Numbers or Google Sheets,
/// or as a CSV file. Bold, links and `code` are taken off the cells, and short rows are padded to the header's width.
enum TableCopy {
    /// The cells as plain words, every row as wide as the widest one.
    static func cells(header: [String], rows: [[String]]) -> [[String]] {
        let all = [header] + rows
        let width = all.map(\.count).max() ?? 0
        return all.map { row in
            let plain = row.map { Markdown.inlinePlain($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            return plain + Array(repeating: "", count: max(0, width - plain.count))
        }
    }

    /// Tabs between cells and a new line per row. Tabs and new lines inside a cell become spaces.
    static func tabbed(header: [String], rows: [[String]]) -> String {
        cells(header: header, rows: rows).map { row in
            row.map { $0.replacingOccurrences(of: "\t", with: " ").replacingOccurrences(of: "\n", with: " ") }
                .joined(separator: "\t")
        }.joined(separator: "\n")
    }

    /// Comma-separated, with quotes around any cell that has a comma, a quote or a new line in it.
    static func csv(header: [String], rows: [[String]]) -> String {
        cells(header: header, rows: rows).map { row in
            row.map(quoted).joined(separator: ",")
        }.joined(separator: "\n") + "\n"
    }

    /// "3 rows · 4 columns".
    static func summary(header: [String], rows: [[String]]) -> String {
        let columns = cells(header: header, rows: rows).first?.count ?? 0
        return "\(rows.count) \(rows.count == 1 ? "row" : "rows") · \(columns) \(columns == 1 ? "column" : "columns")"
    }

    static func quoted(_ cell: String) -> String {
        guard cell.contains(",") || cell.contains("\"") || cell.contains("\n") || cell.contains("\r") else { return cell }
        return "\"" + cell.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}
