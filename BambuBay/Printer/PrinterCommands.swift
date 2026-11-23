import Foundation

/// JSON commands the printer understands on `device/<serial>/request`.
/// Layouts follow the community-documented Bambu LAN protocol (OpenBambuAPI, ha-bambulab).
enum PrinterCommand {
    case pushAll
    case pause
    case resume
    case stop
    case speed(level: Int)
    case chamberLight(on: Bool)
    case startProject(StartRequest)

    struct StartRequest: Equatable {
        var fileName: String
        var plate: Int
        var jobName: String
        var urlStyle: StartURLStyle
        var useAMS: Bool
        var amsMapping: [Int]
        var bedLeveling: Bool
        var flowCalibration: Bool
        var vibrationCalibration: Bool
        var timelapse: Bool
    }

    func payload(sequence: Int) -> Data {
        let seq = String(sequence)
        let object: [String: Any]
        switch self {
        case .pushAll:
            object = ["pushing": ["sequence_id": seq, "command": "pushall", "version": 1, "push_target": 1] as [String: Any]]
        case .pause:
            object = ["print": ["sequence_id": seq, "command": "pause", "param": ""]]
        case .resume:
            object = ["print": ["sequence_id": seq, "command": "resume", "param": ""]]
        case .stop:
            object = ["print": ["sequence_id": seq, "command": "stop", "param": ""]]
        case .speed(let level):
            object = ["print": ["sequence_id": seq, "command": "print_speed", "param": String(min(max(level, 1), 4))]]
        case .chamberLight(let on):
            object = ["system": ["sequence_id": seq, "command": "ledctrl", "led_node": "chamber_light",
                                 "led_mode": on ? "on" : "off", "led_on_time": 500, "led_off_time": 500,
                                 "loop_times": 0, "interval_time": 0] as [String: Any]]
        case .startProject(let r):
            object = ["print": [
                "sequence_id": seq,
                "command": "project_file",
                "param": "Metadata/plate_\(r.plate).gcode",
                "project_id": "0",
                "profile_id": "0",
                "task_id": "0",
                "subtask_id": "0",
                "subtask_name": r.jobName,
                "file": r.fileName,
                "url": r.urlStyle.url(for: r.fileName),
                "md5": "",
                "timelapse": r.timelapse,
                "bed_type": "auto",
                "bed_levelling": r.bedLeveling,
                "bed_leveling": r.bedLeveling,
                "flow_cali": r.flowCalibration,
                "vibration_cali": r.vibrationCalibration,
                "layer_inspect": false,
                "use_ams": r.useAMS,
                "ams_mapping": r.useAMS ? r.amsMapping : [Int]()
            ] as [String: Any]]
        }
        return (try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])) ?? Data()
    }
}
