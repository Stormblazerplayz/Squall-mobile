import CoreGraphics
import XCTest
@testable import Squall

// Tests for the live screen's motion (Squall/Uno/UnoMotion.swift): every effect comes from a real event's
// own fields and words, key names look like keys, typing finishes in time, and haptics are throttled.

@MainActor
final class UnoMotionTests: XCTestCase {
    private func event(
        _ kind: String,
        text: String = "",
        x: Double? = nil, y: Double? = nil, x2: Double? = nil, y2: Double? = nil,
        who: String = "uno"
    ) -> UnoEvent {
        UnoEvent(
            seq: 1, at: 1_764_000_000_000, sessionId: "uno-3f2a9c1b7d4e", computerId: "pc-chief",
            who: who, kind: kind, text: text, x: x, y: y, x2: x2, y2: y2, step: 1
        )
    }

    // MARK: Keys

    func testKeyNamesLookLikeKeys() {
        XCTAssertEqual(UnoMotionText.prettyKey("ctrl+l"), "Ctrl + L")
        XCTAssertEqual(UnoMotionText.prettyKey("Return"), "Enter")
        XCTAssertEqual(UnoMotionText.prettyKey("ctrl+shift+t"), "Ctrl + Shift + T")
        XCTAssertEqual(UnoMotionText.prettyKey("super"), "Win")
        XCTAssertEqual(UnoMotionText.prettyKey("Control_L+Page_Down"), "Ctrl + Page Down")
        XCTAssertEqual(UnoMotionText.prettyKey("alt+F4"), "Alt + F4")
        XCTAssertEqual(UnoMotionText.prettyKey("ctrl++"), "Ctrl + +")
        XCTAssertEqual(UnoMotionText.prettyKey("ctrl+minus"), "Ctrl + -")
        XCTAssertEqual(UnoMotionText.prettyKey("Escape"), "Esc")
        XCTAssertEqual(UnoMotionText.prettyKey("Up"), "↑")
        XCTAssertEqual(UnoMotionText.prettyKey("BackSpace"), "Backspace")
        XCTAssertEqual(UnoMotionText.prettyKey(""), "")
        XCTAssertEqual(UnoMotionText.prettyKeys("ctrl+l Return"), "Ctrl + L, Enter")
        XCTAssertEqual(UnoMotionText.prettyKeys("ctrl+l, Return"), "Ctrl + L, Enter")
    }

    func testKeycapChipsComeFromTheRealKeyEvents() {
        let one = UnoMotionText.keyChip(event("key", text: "Pressed ctrl+l"))
        XCTAssertEqual(one, UnoKeyChip(keys: [["Ctrl", "L"]], times: 1, hold: false))
        XCTAssertEqual(one?.label, "Ctrl + L")

        let many = UnoMotionText.keyChip(event("key", text: "Pressed ctrl+a, Delete 3 times"))
        XCTAssertEqual(many?.keys, [["Ctrl", "A"], ["Delete"]])
        XCTAssertEqual(many?.times, 3)
        XCTAssertEqual(many?.label, "Ctrl + A, Delete ×3")

        let held = UnoMotionText.keyChip(event("hold_key", text: "Held shift for 1 second"))
        XCTAssertEqual(held?.keys, [["Shift"]])
        XCTAssertEqual(held?.hold, true)

        // A key the feed cut short is left out.
        XCTAssertEqual(UnoMotionText.keyChip(event("key", text: "Pressed Tab, Tab, Ret…"))?.keys, [["Tab"], ["Tab"]])
        XCTAssertNil(UnoMotionText.keyChip(event("key", text: "")))
        XCTAssertNil(UnoMotionText.keyChip(event("key", text: "Something else")))
        XCTAssertNil(UnoMotionText.keyChip(event("type", text: "Pressed ctrl+l")))
    }

    // MARK: Typing and scrolling

    func testTypedTextAndScrollWayAreReadNeverMadeUp() {
        XCTAssertEqual(UnoMotionText.typedText(event("type", text: "Typed \"weather in Paris\"")), "weather in Paris")
        XCTAssertEqual(UnoMotionText.typedText(event("type", text: "Typed \"say \"hi\" there\"")), "say \"hi\" there")
        XCTAssertEqual(UnoMotionText.typedText(event("type", text: "Typed \"a long one…\"")), "a long one…")
        XCTAssertNil(UnoMotionText.typedText(event("type", text: "Typed")))
        XCTAssertNil(UnoMotionText.typedText(event("type", text: "Typed \"\"")))
        XCTAssertNil(UnoMotionText.typedText(event("key", text: "Typed \"x\"")))

        XCTAssertEqual(UnoMotionText.scrollDirection(event("scroll", text: "Scrolled down 3 at (640, 400)")), .down)
        XCTAssertEqual(UnoMotionText.scrollDirection(event("scroll", text: "Scrolled up 5")), .up)
        XCTAssertNil(UnoMotionText.scrollDirection(event("scroll", text: "Scrolled")))
        XCTAssertNil(UnoMotionText.scrollDirection(event("click", text: "Scrolled up")))
    }

    func testTypingFinishesWithinTheLimitHoweverLong() {
        XCTAssertEqual(UnoMotionText.tickerStep(length: 0), 0)
        XCTAssertEqual(UnoMotionText.tickerStep(length: 10), 0.045, accuracy: 1e-9)
        XCTAssertEqual(UnoMotionText.tickerTotal(length: 10), 0.45, accuracy: 1e-9)
        XCTAssertEqual(UnoMotionText.tickerStep(length: 60), 0.02, accuracy: 1e-9)
        XCTAssertLessThanOrEqual(UnoMotionText.tickerTotal(length: 60), 1.2 + 1e-9)
        XCTAssertLessThanOrEqual(UnoMotionText.tickerTotal(length: 5000), 1.2 + 1e-9)

        XCTAssertEqual(UnoMotionText.tickerShown(length: 10, elapsed: 0), 1)
        XCTAssertEqual(UnoMotionText.tickerShown(length: 10, elapsed: 0.044), 1)
        XCTAssertEqual(UnoMotionText.tickerShown(length: 10, elapsed: 0.046), 2)
        XCTAssertEqual(UnoMotionText.tickerShown(length: 10, elapsed: 0.449), 10)
        XCTAssertEqual(UnoMotionText.tickerShown(length: 10, elapsed: 99), 10)
        XCTAssertEqual(UnoMotionText.tickerShown(length: 60, elapsed: 1.2), 60)
        XCTAssertEqual(UnoMotionText.tickerShown(length: 0, elapsed: 1), 0)
        XCTAssertEqual(UnoMotionText.tickerShown(length: 10, elapsed: -1), 1)
    }

    // MARK: Events to effects

    func testEachRealEventMapsToOneEffect() {
        XCTAssertEqual(UnoMotion.of(event("click", x: 10, y: 20)), .click(at: CGPoint(x: 10, y: 20), count: 1))
        XCTAssertEqual(UnoMotion.of(event("double_click", x: 1, y: 2)), .click(at: CGPoint(x: 1, y: 2), count: 2))
        XCTAssertEqual(UnoMotion.of(event("triple_click", x: 1, y: 2)), .click(at: CGPoint(x: 1, y: 2), count: 3))
        XCTAssertNil(UnoMotion.of(event("click")))   // no spot, no ripple anywhere
        XCTAssertEqual(UnoMotion.of(event("move", x: 5, y: 6)), .move(to: CGPoint(x: 5, y: 6)))
        XCTAssertEqual(
            UnoMotion.of(event("drag", x: 1, y: 2, x2: 30, y2: 40)),
            .drag(from: CGPoint(x: 1, y: 2), to: CGPoint(x: 30, y: 40))
        )
        XCTAssertEqual(UnoMotion.of(event("drag", x: 1, y: 2)), .move(to: CGPoint(x: 1, y: 2)))
        XCTAssertEqual(UnoMotion.of(event("type", text: "Typed \"hi\"")), .type(text: "hi"))
        XCTAssertNil(UnoMotion.of(event("type")))
        XCTAssertEqual(UnoMotion.of(event("key", text: "Pressed Return")), .key(UnoKeyChip(keys: [["Enter"]], times: 1, hold: false)))
        XCTAssertEqual(
            UnoMotion.of(event("scroll", text: "Scrolled down 3 at (4, 5)", x: 4, y: 5)),
            .scroll(direction: .down, at: CGPoint(x: 4, y: 5))
        )
        XCTAssertEqual(UnoMotion.of(event("scroll", text: "Scrolled up 3")), .scroll(direction: .up, at: nil))
        XCTAssertEqual(UnoMotion.of(event("screenshot")), .flash(zoom: nil))
        XCTAssertEqual(
            UnoMotion.of(event("zoom", x: 100, y: 50, x2: 20, y2: 250)),
            .flash(zoom: CGRect(x: 20, y: 50, width: 80, height: 200))
        )
        for kind in ["say", "wait", "done", "start", "error", "message"] {
            XCTAssertNil(UnoMotion.of(event(kind, x: 1, y: 1)), kind)
        }
    }

    // MARK: Haptics

    func testHapticsAreThrottledToFourASecond() {
        var gate = UnoHapticGate(perSecond: 4)
        let start = Date(timeIntervalSince1970: 1_764_000_000)
        XCTAssertTrue(gate.allow(at: start))
        XCTAssertFalse(gate.allow(at: start.addingTimeInterval(0.1)))
        XCTAssertFalse(gate.allow(at: start.addingTimeInterval(0.24)))
        XCTAssertTrue(gate.allow(at: start.addingTimeInterval(0.26)))
        XCTAssertFalse(gate.allow(at: start.addingTimeInterval(0.35)))
        XCTAssertTrue(gate.allow(at: start.addingTimeInterval(1)))

        // Ten clicks in one second get at most four taps.
        var burst = UnoHapticGate(perSecond: 4)
        let taps = (0..<10).filter { burst.allow(at: start.addingTimeInterval(Double($0) * 0.1)) }.count
        XCTAssertLessThanOrEqual(taps, 4)
        XCTAssertGreaterThanOrEqual(taps, 3)
    }
}
