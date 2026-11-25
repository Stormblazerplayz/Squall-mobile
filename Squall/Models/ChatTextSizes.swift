import Foundation

/// The message text sizes, shared by Settings and pinching in a chat. Pinching snaps to the same four sizes Settings has,
/// so the two always agree.
enum ChatTextSizes {
    struct Step: Equatable {
        let label: String
        let size: Double
    }

    static let steps = [
        Step(label: "Small", size: 13.5),
        Step(label: "Normal", size: 15),
        Step(label: "Big", size: 17),
        Step(label: "Huge", size: 19),
    ]

    /// The step closest to a size.
    static func nearest(_ size: Double) -> Step {
        steps.min { abs($0.size - size) < abs($1.size - size) } ?? steps[1]
    }

    /// The size for a pinch that started at `start` and is now `scale` times as big, snapped to a step.
    static func size(start: Double, scale: Double) -> Double {
        guard scale.isFinite, scale > 0 else { return nearest(start).size }
        // A pinch is a bit much one for one; half as strong feels right on a phone.
        let eased = 1 + (scale - 1) * 0.6
        return nearest(start * eased).size
    }

    static func label(_ size: Double) -> String {
        nearest(size).label
    }
}
