import CoreGraphics
import Foundation

/// Page layout for a chat saved as a PDF: Letter pages with margins, and messages kept whole on a page when they fit.
enum ChatPDFLayout {
    static let pageSize = CGSize(width: 612, height: 792)
    static let margin: CGFloat = 36
    static let gap: CGFloat = 12

    static var contentWidth: CGFloat { pageSize.width - margin * 2 }
    static var contentHeight: CGFloat { pageSize.height - margin * 2 }

    struct Placement: Equatable {
        let index: Int
        let page: Int
        /// From the top of the page's content area.
        let top: CGFloat
    }

    /// Where each block goes. A block starts a new page when it doesn't fit what's left; one taller than a whole page
    /// gets a page of its own and is cut at the bottom.
    static func place(_ heights: [CGFloat], pageHeight: CGFloat = contentHeight, gap: CGFloat = gap) -> [Placement] {
        var out: [Placement] = []
        var page = 0
        var y: CGFloat = 0
        for (index, height) in heights.enumerated() {
            let needed = (y == 0 ? 0 : gap) + height
            if y > 0, y + needed > pageHeight {
                page += 1
                y = 0
            }
            let top = y == 0 ? 0 : y + gap
            out.append(Placement(index: index, page: page, top: top))
            y = top + height
        }
        return out
    }

    static func pageCount(_ placements: [Placement]) -> Int {
        (placements.map(\.page).max() ?? -1) + 1
    }

    /// "Rex chat 2026-11-25.pdf".
    static func fileName(title: String, now: Date, calendar: Calendar = .current) -> String {
        let markdownName = ChatExport.fileName(title: title, now: now, calendar: calendar)
        return (markdownName as NSString).deletingPathExtension + ".pdf"
    }
}
