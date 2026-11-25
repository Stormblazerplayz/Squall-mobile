import XCTest
@testable import Squall

// Tests for links in chats: which bare links become tappable, which links get a card, and what each card says.

final class ChatLinksTests: XCTestCase {
    func testBareLinksNeedHttpOrWww() {
        let text = "Open https://github.com/stormblazerplayz/squall-mobile and www.squall.dev, not README.md or app.py"
        let found = ChatLinks.bare(in: text)
        XCTAssertEqual(found.map(\.url.absoluteString), ["https://github.com/stormblazerplayz/squall-mobile", "http://www.squall.dev"])
        XCTAssertEqual(found.first?.start, 5)
        XCTAssertEqual(found.first?.length, "https://github.com/stormblazerplayz/squall-mobile".count)
    }

    func testNoLinksNoWork() {
        XCTAssertEqual(ChatLinks.bare(in: "Fixed the login page in LoginView.swift"), [])
        XCTAssertEqual(ChatLinks.bare(in: ""), [])
        // An email address is not a web link.
        XCTAssertEqual(ChatLinks.bare(in: "Mail http-team@example.com"), [])
    }

    func testTrailingDotIsNotPartOfTheLink() {
        let found = ChatLinks.bare(in: "See https://example.com/a.")
        XCTAssertEqual(found.first?.url.absoluteString, "https://example.com/a")
    }

    func testLinksInAMessage() {
        let text = """
        Read [the docs](https://docs.squall.dev/start) and https://github.com/a/b.

        ```
        curl https://inside.code.block/skip
        ```

        - again https://github.com/a/b
        - [app](squall://chat/rex) and [mail](mailto:a@b.com)
        """
        XCTAssertEqual(ChatLinks.links(in: text).map(\.absoluteString),
                       ["https://docs.squall.dev/start", "https://github.com/a/b"])
    }

    func testCardsStopAtThree() {
        let text = "https://a.com https://b.com https://c.com https://d.com"
        XCTAssertEqual(ChatLinks.cards(for: text).map(\.site), ["a.com", "b.com", "c.com"])
    }

    func testCardWords() {
        let pr = ChatLinks.card(URL(string: "https://www.github.com/stormblazerplayz/squall-mobile/pull/74/")!)
        XCTAssertEqual(pr.site, "github.com")
        XCTAssertEqual(pr.detail, "stormblazerplayz/squall-mobile/pull/74")
        XCTAssertEqual(pr.place, .web)

        let front = ChatLinks.card(URL(string: "https://apple.com/")!)
        XCTAssertEqual(front.detail, "")

        let search = ChatLinks.card(URL(string: "https://example.com/find?q=red%20car")!)
        XCTAssertEqual(search.detail, "find?q=red car")

        let long = ChatLinks.card(URL(string: "https://example.com/" + String(repeating: "a", count: 80))!)
        XCTAssertEqual(long.detail.count, ChatLinks.maxDetail)
        XCTAssertTrue(long.detail.hasSuffix("…"))
    }

    func testWhereLinksOpen() {
        let local = ChatLinks.card(URL(string: "http://localhost:3000/app")!)
        XCTAssertEqual(local.site, "localhost:3000")
        XCTAssertEqual(local.place, .computer)

        let lan = ChatLinks.card(URL(string: "http://192.168.1.20:8080")!)
        XCTAssertEqual(lan.site, "192.168.1.20:8080")
        XCTAssertEqual(lan.place, .network)

        XCTAssertEqual(ChatLinks.place(of: "127.0.0.1"), .computer)
        XCTAssertEqual(ChatLinks.place(of: "[::1]"), .computer)
        XCTAssertEqual(ChatLinks.place(of: "10.0.0.4"), .network)
        XCTAssertEqual(ChatLinks.place(of: "172.20.1.1"), .network)
        XCTAssertEqual(ChatLinks.place(of: "172.40.1.1"), .web)
        XCTAssertEqual(ChatLinks.place(of: "storm-pc.local"), .network)
        XCTAssertEqual(ChatLinks.place(of: "8.8.8.8"), .web)
        XCTAssertEqual(ChatLinks.place(of: "1.2.3"), .web)
        XCTAssertEqual(ChatLinks.place(of: "github.com"), .web)

        // A web site keeps no port on its card.
        XCTAssertEqual(ChatLinks.card(URL(string: "https://example.com:8443/x")!).site, "example.com")
    }

    func testLinkedLeavesLinksAndCodeAlone() {
        let out = ChatLinks.linked(Markdown.inline("[docs](https://a.com/docs) `https://b.com` and https://c.com"))
        let links = out.runs.compactMap(\.link).map(\.absoluteString)
        XCTAssertEqual(links, ["https://a.com/docs", "https://c.com"])
        XCTAssertEqual(String(out.characters), "docs https://b.com and https://c.com")
    }

    func testOnlyWebLinks() {
        XCTAssertTrue(ChatLinks.isWeb(URL(string: "https://a.com")!))
        XCTAssertTrue(ChatLinks.isWeb(URL(string: "HTTP://a.com")!))
        XCTAssertFalse(ChatLinks.isWeb(URL(string: "squall://chat/rex")!))
        XCTAssertFalse(ChatLinks.isWeb(URL(string: "mailto:a@b.com")!))
        XCTAssertFalse(ChatLinks.isWeb(URL(string: "file:///tmp/a")!))
    }
}
