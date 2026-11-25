import XCTest
@testable import Squall

final class TableCopyTests: XCTestCase {
    private let header = ["Name", "**Cost**"]
    private let rows = [["Milk", "$2, cheap"], ["`Eggs`"], ["Say \"hi\"", "1"]]

    func testCellsArePlainAndPadded() {
        XCTAssertEqual(TableCopy.cells(header: header, rows: rows), [
            ["Name", "Cost"],
            ["Milk", "$2, cheap"],
            ["Eggs", ""],
            ["Say \"hi\"", "1"],
        ])
    }

    func testTabbed() {
        XCTAssertEqual(TableCopy.tabbed(header: ["A", "B"], rows: [["1", "2"]]), "A\tB\n1\t2")
        XCTAssertEqual(TableCopy.tabbed(header: ["A\tB"], rows: []), "A B")
    }

    func testCSVQuotesWhatItHasTo() {
        XCTAssertEqual(TableCopy.csv(header: header, rows: rows),
                       "Name,Cost\nMilk,\"$2, cheap\"\nEggs,\n\"Say \"\"hi\"\"\",1\n")
        XCTAssertEqual(TableCopy.quoted("plain"), "plain")
    }

    func testSummary() {
        XCTAssertEqual(TableCopy.summary(header: header, rows: rows), "3 rows · 2 columns")
        XCTAssertEqual(TableCopy.summary(header: ["A"], rows: [["1"]]), "1 row · 1 column")
    }
}
