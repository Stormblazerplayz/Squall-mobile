import XCTest
import CoreML
@testable import BambuBay

final class ZipAndThreeMFTests: XCTestCase {
    func testZipStoredDeflatedAndEmpty() throws {
        let zip = try ZipReader(data: Fixtures.simpleZip)
        XCTAssertEqual(Set(zip.names), ["hello.txt", "big.txt", "empty.txt"])
        XCTAssertEqual(String(decoding: try zip.extract("hello.txt"), as: UTF8.self), "Hello, Bambu!")
        XCTAssertEqual(String(decoding: try zip.extract("big.txt"), as: UTF8.self), String(repeating: "abc123 ", count: 1000))
        XCTAssertEqual(try zip.extract("empty.txt").count, 0)
        XCTAssertThrowsError(try zip.extract("nope.txt"))
    }

    func testModelZipUnpacksSafely() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: folder) }
        let zipURL = folder.appendingPathExtension("zip")
        defer { try? FileManager.default.removeItem(at: zipURL) }
        try Fixtures.zippedPackage.write(to: zipURL)
        try ModelStore.unzip(zipURL, to: folder)
        let found = try XCTUnwrap(ModelStore.findModel(in: folder))
        XCTAssertEqual(found.lastPathComponent, "Spaghetti.mlpackage")
        XCTAssertTrue(FileManager.default.fileExists(atPath: found.appendingPathComponent("Manifest.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.deletingLastPathComponent().appendingPathComponent("evil.txt").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.appendingPathComponent("__MACOSX").path))
    }

    func testNotAZip() {
        XCTAssertThrowsError(try ZipReader(data: Data("hello there, definitely not a zip file at all".utf8)))
        XCTAssertThrowsError(try ZipReader(data: Data()))
    }

    func testSliceInfo() throws {
        let info = try ThreeMFInfo.read(zip: ZipReader(data: Fixtures.sample3MF))
        XCTAssertEqual(info.slicerVersion, "02.04.00.70")
        XCTAssertEqual(info.plates.map(\.index), [1, 2])
        XCTAssertTrue(info.isSliced)
        XCTAssertEqual(info.slicedPlates.map(\.index), [1])
        XCTAssertEqual(info.filamentCount, 3)

        let plate = info.plates[0]
        XCTAssertEqual(plate.seconds, 3725)
        XCTAssertEqual(plate.grams ?? 0, 12.34, accuracy: 0.001)
        XCTAssertEqual(plate.printerModelID, "N2S")
        XCTAssertEqual(plate.nozzle, "0.4")
        XCTAssertEqual(plate.objectNames, ["Benchy"])
        XCTAssertEqual(plate.filaments.map(\.id), [1, 3])
        XCTAssertEqual(plate.filaments.first?.type, "PLA")
        XCTAssertEqual(plate.filaments.first?.colorHex, "#FF0000")
        XCTAssertEqual(plate.warnings.count, 1)
        XCTAssertNotNil(plate.thumbnail)

        XCTAssertFalse(info.plates[1].isSliced)
        XCTAssertNil(info.plates[1].thumbnail)
    }
}

final class FilamentMatcherTests: XCTestCase {
    private func tray(_ slot: Int, _ type: String, _ color: String, remain: Int? = nil) -> PrinterState.Tray {
        PrinterState.Tray(slot: slot, type: type, colorHex: color, remainPercent: remain, name: "")
    }

    func testTypeBeatsColorAndSpoolsAreSpread() {
        let trays = [tray(0, "PLA", "FF0000FF"), tray(1, "PETG", "FF0000FF"), tray(2, "PLA", "0000FFFF"), tray(254, "PLA", "FF0000FF")]
        let needs = [ThreeMFInfo.Filament(id: 1, type: "PETG", colorHex: "#00FF00", grams: 3),
                     ThreeMFInfo.Filament(id: 2, type: "PLA", colorHex: "#FF1010", grams: 3),
                     ThreeMFInfo.Filament(id: 4, type: "PLA", colorHex: "#FF0000", grams: 3)]
        let map = FilamentMatcher.autoMap(needs: needs, trays: trays)
        XCTAssertEqual(map[1], 1)      // only PETG
        XCTAssertEqual(map[2], 0)      // red PLA
        XCTAssertEqual(map[4], 2)      // red is taken, so the other PLA
        XCTAssertEqual(FilamentMatcher.amsMappingArray(filamentCount: 4, mapping: map), [1, 0, -1, 2])
    }

    func testPLABasicMatchesPLA() {
        XCTAssertTrue(FilamentMatcher.sameType("PLA", "pla"))
        XCTAssertTrue(FilamentMatcher.sameType("PLA Basic", "PLA"))
        XCTAssertTrue(FilamentMatcher.sameType("PLA-CF", "PLA"))
        XCTAssertFalse(FilamentMatcher.sameType("PLA", "PETG"))
        XCTAssertFalse(FilamentMatcher.sameType("", "PLA"))
    }

    func testWarningsNeverEmptyForProblems() {
        let trays = [tray(0, "PETG", "FF0000FF"), tray(1, "", ""), tray(2, "PLA", "FFFFFFFF", remain: 4)]
        let needs = [ThreeMFInfo.Filament(id: 1, type: "PLA", colorHex: "#FF0000", grams: 10),
                     ThreeMFInfo.Filament(id: 2, type: "PLA", colorHex: "#FF0000", grams: 10),
                     ThreeMFInfo.Filament(id: 3, type: "PLA", colorHex: "#FF0000", grams: 10)]
        let warnings = FilamentMatcher.warnings(needs: needs, trays: trays, mapping: [1: 0, 2: 1, 3: 2], useSpoolHolder: false)
        XCTAssertEqual(warnings.count, 3)
        let fine = FilamentMatcher.warnings(needs: [needs[0]], trays: [tray(0, "PLA", "FF0000FF", remain: 90)],
                                            mapping: [1: 0], useSpoolHolder: false)
        XCTAssertTrue(fine.isEmpty)
        let spool = FilamentMatcher.warnings(needs: needs, trays: [tray(254, "TPU", "000000FF")], mapping: [:], useSpoolHolder: true)
        XCTAssertEqual(spool.count, 2)
    }

    func testColorDistance() {
        XCTAssertEqual(FilamentMatcher.colorDistance("#FF0000", "FF0000FF"), 0)
        XCTAssertLessThan(FilamentMatcher.colorDistance("FF0000", "EE1111"), FilamentMatcher.colorDistance("FF0000", "0000FF"))
        XCTAssertEqual(FilamentMatcher.colorDistance("zz", "FF0000"), 500)
    }
}

final class DetectionTests: XCTestCase {
    func testVoterNeedsMostChecksToAgree() {
        var voter = FailureVoter()
        voter.window = 4; voter.needed = 3; voter.threshold = 0.6; voter.cooldown = 60
        let start = Date(timeIntervalSince1970: 1_000)
        XCTAssertFalse(voter.add(0.9, at: start))
        XCTAssertFalse(voter.add(0.1, at: start))
        XCTAssertFalse(voter.add(0.8, at: start))
        XCTAssertTrue(voter.add(0.7, at: start))        // 3 of the last 4
        XCTAssertFalse(voter.add(0.9, at: start + 1))   // cooling down
        XCTAssertFalse(voter.add(0.9, at: start + 2))
        XCTAssertFalse(voter.add(0.9, at: start + 3))
        XCTAssertTrue(voter.add(0.9, at: start + 61))   // cool-down over, still bad
        voter.reset()
        XCTAssertEqual(voter.hits, 0)
    }

    func testVoterOldScoresDropOut() {
        var voter = FailureVoter()
        voter.window = 3; voter.needed = 2; voter.threshold = 0.5; voter.cooldown = 0
        XCTAssertFalse(voter.add(0.9))
        XCTAssertFalse(voter.add(0.1))
        XCTAssertFalse(voter.add(0.1))
        XCTAssertFalse(voter.add(0.9))   // the first 0.9 dropped out
        XCTAssertTrue(voter.add(0.9))
    }

    func testFailureLabels() {
        let words = FailureLabels.words(from: FailureLabels.defaultWords)
        XCTAssertTrue(words.contains("spaghetti"))
        XCTAssertTrue(FailureLabels.isFailure("Spaghetti", words: words))
        XCTAssertTrue(FailureLabels.isFailure("print_failure", words: words))
        XCTAssertFalse(FailureLabels.isFailure("good", words: words))
        XCTAssertFalse(FailureLabels.isFailure("nozzle", words: words))
        XCTAssertEqual(FailureLabels.words(from: " A, b\n\n c ,"), ["a", "b", "c"])
    }

    func testUltralyticsNames() {
        XCTAssertEqual(FailureDetector.parseNames("{0: 'spaghetti', 1: \"stringing\", 2: 'zits'}"), ["spaghetti", "stringing", "zits"])
        XCTAssertEqual(FailureDetector.parseNames("{1: 'b', 0: 'a'}"), ["a", "b"])
        XCTAssertEqual(FailureDetector.parseNames("nothing"), [])
    }

    func testHalfFloat() {
        XCTAssertEqual(FailureDetector.halfToFloat(0x3C00), 1)
        XCTAssertEqual(FailureDetector.halfToFloat(0xC000), -2)
        XCTAssertEqual(FailureDetector.halfToFloat(0x3800), 0.5)
        XCTAssertEqual(FailureDetector.halfToFloat(0x0000), 0)
        XCTAssertEqual(FailureDetector.halfToFloat(0x0001), Float(pow(2.0, -24.0)))
        XCTAssertEqual(FailureDetector.halfToFloat(0x7BFF), 65504)
        XCTAssertTrue(FailureDetector.halfToFloat(0x7C00).isInfinite)
    }

    func testDecodeYOLOv8Output() throws {
        // [1, 4 + 2 classes, 8 boxes], pixel coordinates on a 640 x 640 input. Boxes 3...7 are empty.
        let array = try MLMultiArray(shape: [1, 6, 8], dataType: .float32)
        let values: [[Float]] = [
            [320, 100, 600],   // cx
            [320, 100, 600],   // cy
            [64, 20, 30],      // w
            [64, 20, 30],      // h
            [0.92, 0.10, 0.3], // spaghetti
            [0.05, 0.99, 0.1]  // nozzle
        ]
        for f in 0..<6 {
            for n in 0..<8 {
                array[[0, NSNumber(value: f), NSNumber(value: n)]] = NSNumber(value: n < 3 ? values[f][n] : 0)
            }
        }
        let result = try XCTUnwrap(FailureDetector.decodeYOLO(array, names: ["spaghetti", "nozzle"],
                                                              words: ["spaghetti"], inputSize: CGSize(width: 640, height: 640)))
        XCTAssertEqual(result.score, 0.92, accuracy: 0.001)
        XCTAssertEqual(result.label, "spaghetti")
        XCTAssertEqual(result.boxes.count, 2)    // boxes 0 and 2 pass 0.25; the nozzle box doesn't count
        XCTAssertEqual(result.boxes[0].midX, 0.5, accuracy: 0.001)
        XCTAssertEqual(result.boxes[0].width, 0.1, accuracy: 0.001)
    }

    func testDecodeYOLOv5OutputUsesObjectness() throws {
        // [1, 8 boxes, 5 + 1 class], 0...1 coordinates. Only the first box counts.
        let array = try MLMultiArray(shape: [1, 8, 6], dataType: .double)
        let rows: [[Double]] = [[0.5, 0.5, 0.2, 0.2, 0.5, 0.9],
                                [0.2, 0.2, 0.1, 0.1, 0.01, 1.0]]
        for n in 0..<8 {
            for f in 0..<6 {
                array[[0, NSNumber(value: n), NSNumber(value: f)]] = NSNumber(value: n < 2 ? rows[n][f] : 0)
            }
        }
        let result = try XCTUnwrap(FailureDetector.decodeYOLO(array, names: [], words: ["spaghetti"], inputSize: CGSize(width: 640, height: 640)))
        XCTAssertEqual(result.score, 0.45, accuracy: 0.001)
        XCTAssertEqual(result.boxes.count, 1)
    }
}
