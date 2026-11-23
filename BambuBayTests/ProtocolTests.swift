import XCTest
@testable import BambuBay

final class MQTTTests: XCTestCase {
    func testRemainingLength() {
        XCTAssertEqual(MQTTPacket.remainingLength(0), [0x00])
        XCTAssertEqual(MQTTPacket.remainingLength(127), [0x7F])
        XCTAssertEqual(MQTTPacket.remainingLength(128), [0x80, 0x01])
        XCTAssertEqual(MQTTPacket.remainingLength(16_383), [0xFF, 0x7F])
        XCTAssertEqual(MQTTPacket.remainingLength(16_384), [0x80, 0x80, 0x01])
    }

    func testConnectPacket() {
        let data = [UInt8](MQTTPacket.connect(clientID: "c", username: "bblp", password: "12345678", keepAlive: 30))
        XCTAssertEqual(data[0], 0x10)
        // 10 bytes of variable header + 3 + 6 + 10 bytes of payload
        XCTAssertEqual(Int(data[1]), 10 + 3 + 6 + 10)
        XCTAssertEqual(Array(data[2..<8]), [0, 4] + Array("MQTT".utf8))
        XCTAssertEqual(data[8], 4)        // MQTT 3.1.1
        XCTAssertEqual(data[9], 0xC2)     // username + password + clean session
        XCTAssertEqual(Array(data[10..<12]), [0, 30])
        XCTAssertEqual(data.count, 2 + Int(data[1]))
    }

    func testParserRoundTripAndSplitReads() throws {
        let payload = Data(#"{"print":{"gcode_state":"RUNNING"}}"#.utf8)
        let packet = MQTTPacket.publish(topic: "device/ABC/report", payload: payload) + MQTTPacket.pingreq
        var parser = MQTTParser()
        // Feed one byte at a time, like a slow socket.
        var frames: [MQTTFrame] = []
        for byte in packet {
            parser.append(Data([byte]))
            while let frame = try parser.next() { frames.append(frame) }
        }
        XCTAssertEqual(frames.count, 2)
        let parts = try XCTUnwrap(frames[0].publishParts())
        XCTAssertEqual(parts.topic, "device/ABC/report")
        XCTAssertNil(parts.packetID)
        XCTAssertEqual(parts.payload, payload)
        XCTAssertEqual(frames[1].kind, .pingreq)
        XCTAssertEqual(parser.pendingBytes, 0)
    }

    func testParserQoS1PublishHasPacketID() throws {
        // PUBLISH, QoS 1: header 0x32, topic "t", packet id 7, payload "x"
        var parser = MQTTParser()
        parser.append(Data([0x32, 6, 0, 1, UInt8(ascii: "t"), 0, 7, UInt8(ascii: "x")]))
        let frame = try XCTUnwrap(try parser.next())
        let parts = try XCTUnwrap(frame.publishParts())
        XCTAssertEqual(parts.topic, "t")
        XCTAssertEqual(parts.packetID, 7)
        XCTAssertEqual(parts.payload, Data("x".utf8))
    }

    func testParserRejectsBadLength() {
        var parser = MQTTParser()
        parser.append(Data([0x30, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF]))
        XCTAssertThrowsError(try parser.next())
    }

    func testSubscribePacket() {
        let data = [UInt8](MQTTPacket.subscribe(packetID: 1, topic: "a/b"))
        XCTAssertEqual(data, [0x82, 8, 0, 1, 0, 3] + Array("a/b".utf8) + [0])
    }
}

final class PrinterStateTests: XCTestCase {
    func testMergeKeepsOlderFields() {
        var state = PrinterState()
        XCTAssertTrue(state.merge(json: Data(#"{"print":{"gcode_state":"RUNNING","mc_percent":42,"mc_remaining_time":17,"nozzle_temper":219.5,"subtask_name":"Benchy","command":"push_status"}}"#.utf8)))
        XCTAssertTrue(state.merge(json: Data(#"{"print":{"mc_percent":43}}"#.utf8)))
        XCTAssertEqual(state.phase, .running)
        XCTAssertEqual(state.percent, 43)
        XCTAssertEqual(state.remainingMinutes, 17)
        XCTAssertEqual(state.nozzleTemp, 219.5)
        XCTAssertTrue(state.phase.isBusy)
        XCTAssertFalse(state.phase.canStartJob)
        XCTAssertNil(state.raw["command"])
    }

    func testNonPrintMessageIsIgnored() {
        var state = PrinterState()
        XCTAssertFalse(state.merge(json: Data(#"{"info":{"command":"get_version"}}"#.utf8)))
        XCTAssertFalse(state.merge(json: Data("not json".utf8)))
        XCTAssertEqual(state.phase, .unknown)
    }

    func testTraysFromAMSAndSpoolHolder() {
        var state = PrinterState()
        state.merge(json: Data(#"""
        {"print":{"ams":{"ams":[{"id":"0","tray":[
            {"id":"0","tray_type":"PLA","tray_color":"FF0000FF","remain":80},
            {"id":"1","tray_type":"PETG","tray_color":"00FF00FF","remain":-1},
            {"id":"2"}
        ]}]},"vt_tray":{"id":"254","tray_type":"TPU","tray_color":"000000FF"}}}
        """#.utf8))
        let trays = state.trays
        XCTAssertEqual(trays.map(\.slot), [0, 1, 2, 254])
        XCTAssertEqual(trays[0].type, "PLA")
        XCTAssertEqual(trays[0].remainPercent, 80)
        XCTAssertNil(trays[1].remainPercent)
        XCTAssertTrue(trays[2].isEmpty)
        XCTAssertEqual(trays[3].slotLabel, "Spool")
        XCTAssertTrue(state.hasAMS)

        // A later AMS block without the unit list keeps the trays we know.
        state.merge(json: Data(#"{"print":{"ams":{"tray_now":"0"}}}"#.utf8))
        XCTAssertEqual(state.trays.count, 4)
    }

    func testHMSErrorCode() {
        var state = PrinterState()
        state.merge(json: Data(#"{"print":{"hms":[{"attr":50331904,"code":65543}]}}"#.utf8))
        XCTAssertEqual(state.hmsErrors.first?.codeString, "0300_0100_0001_0007")
    }

    func testPhaseFromLowercaseAndUnknown() {
        var state = PrinterState()
        state.merge(json: Data(#"{"print":{"gcode_state":"finish"}}"#.utf8))
        XCTAssertEqual(state.phase, .finish)
        XCTAssertTrue(state.phase.canStartJob)
        state.merge(json: Data(#"{"print":{"gcode_state":"SOMETHING_NEW"}}"#.utf8))
        XCTAssertEqual(state.phase, .unknown)
    }
}

final class CommandTests: XCTestCase {
    private func object(_ command: PrinterCommand) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: command.payload(sequence: 5)) as? [String: Any])
    }

    func testPauseAndSpeed() throws {
        let pause = try XCTUnwrap(try object(.pause)["print"] as? [String: Any])
        XCTAssertEqual(pause["command"] as? String, "pause")
        XCTAssertEqual(pause["sequence_id"] as? String, "5")
        let speed = try XCTUnwrap(try object(.speed(level: 9))["print"] as? [String: Any])
        XCTAssertEqual(speed["param"] as? String, "4")
    }

    func testPushAll() throws {
        let push = try XCTUnwrap(try object(.pushAll)["pushing"] as? [String: Any])
        XCTAssertEqual(push["command"] as? String, "pushall")
    }

    func testStartProject() throws {
        let request = PrinterCommand.StartRequest(fileName: "Benchy.gcode.3mf", plate: 2, jobName: "Benchy",
                                                  urlStyle: .ftp, useAMS: true, amsMapping: [0, -1, 3],
                                                  bedLeveling: true, flowCalibration: false,
                                                  vibrationCalibration: false, timelapse: false)
        let print = try XCTUnwrap(try object(.startProject(request))["print"] as? [String: Any])
        XCTAssertEqual(print["command"] as? String, "project_file")
        XCTAssertEqual(print["param"] as? String, "Metadata/plate_2.gcode")
        XCTAssertEqual(print["url"] as? String, "ftp:///Benchy.gcode.3mf")
        XCTAssertEqual(print["ams_mapping"] as? [Int], [0, -1, 3])
        XCTAssertEqual(print["use_ams"] as? Bool, true)

        var noAMS = request
        noAMS.useAMS = false
        noAMS.urlStyle = .sdcard
        let print2 = try XCTUnwrap(try object(.startProject(noAMS))["print"] as? [String: Any])
        XCTAssertEqual(print2["ams_mapping"] as? [Int], [])
        XCTAssertEqual(print2["url"] as? String, "file:///sdcard/Benchy.gcode.3mf")
    }

    func testLight() throws {
        let system = try XCTUnwrap(try object(.chamberLight(on: true))["system"] as? [String: Any])
        XCTAssertEqual(system["led_mode"] as? String, "on")
    }
}

final class FTPSAndCameraTests: XCTestCase {
    func testFinalReply() {
        XCTAssertEqual(FTPSUploader.finalReply(["220 Ready"])?.code, 220)
        XCTAssertNil(FTPSUploader.finalReply(["220-Welcome"]))
        XCTAssertNil(FTPSUploader.finalReply(["220-Welcome", " more"]))
        XCTAssertEqual(FTPSUploader.finalReply(["220-Welcome", "220 Ready"])?.code, 220)
        XCTAssertNil(FTPSUploader.finalReply([]))
        XCTAssertNil(FTPSUploader.finalReply(["hi"]))
    }

    func testPassivePort() {
        XCTAssertEqual(FTPSUploader.passivePort("227 Entering Passive Mode (192,168,1,20,195,80)"), 50000)
        XCTAssertNil(FTPSUploader.passivePort("227 nothing here"))
        XCTAssertNil(FTPSUploader.passivePort("227 (1,2,3,4,300,1)"))
    }

    func testSafeFileName() {
        XCTAssertEqual(FTPSUploader.safeFileName("My Benchy (2).3mf"), "My_Benchy_2.gcode.3mf")
        XCTAssertEqual(FTPSUploader.safeFileName("cube.gcode.3mf"), "cube.gcode.3mf")
        XCTAssertEqual(FTPSUploader.safeFileName("???.3mf"), "print.gcode.3mf")
        XCTAssertEqual(FTPSUploader.safeFileName(String(repeating: "a", count: 100) + ".3mf").count, 60 + 10)
    }

    func testCameraAuthPacket() {
        let data = [UInt8](CameraStream.authPacket(accessCode: "12345678"))
        XCTAssertEqual(data.count, 80)
        XCTAssertEqual(Array(data[0..<8]), [0x40, 0, 0, 0, 0x00, 0x30, 0, 0])
        XCTAssertEqual(Array(data[16..<20]), Array("bblp".utf8))
        XCTAssertEqual(data[20], 0)
        XCTAssertEqual(Array(data[48..<56]), Array("12345678".utf8))
        XCTAssertEqual(data[56], 0)
    }

    func testCameraFrameSize() {
        XCTAssertEqual(CameraStream.payloadSize(header: Data([0x10, 0x27, 0, 0] + Array(repeating: 0, count: 12))), 10_000)
        XCTAssertEqual(CameraStream.payloadSize(header: Data([1])), 0)
    }

    func testConfigTopicsAndURLs() {
        let config = PrinterConfig(id: UUID(), name: "A1", host: " 192.168.1.20 ", serial: " 03919a1 ")
        XCTAssertEqual(config.trimmedHost, "192.168.1.20")
        XCTAssertEqual(config.reportTopic, "device/03919A1/report")
        XCTAssertEqual(config.requestTopic, "device/03919A1/request")
        XCTAssertEqual(PrinterModel.name(forSlicerID: "N2S"), "A1")
        XCTAssertNil(PrinterModel.name(forSlicerID: "zzz"))
    }
}
