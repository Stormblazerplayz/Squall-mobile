import SwiftUI
import WidgetKit

/// The SquallActivities extension holds the Live Activities, the team widget and the
/// Control Center buttons.
/// The app starts the Live Activities (see Squall/LiveActivities/LiveActivities.swift)
/// and saves the data the widget draws (see Shared/SquallWidgetData.swift).
@main
struct SquallActivitiesBundle: WidgetBundle {
    var body: some Widget {
        TeamStatusWidget()
        BuildActivityWidget()
        ApprovalActivityWidget()
        RoutineActivityWidget()
        CallActivityWidget()
        TeamActivityWidget()
        // Control Center buttons need iOS 18.
        if #available(iOS 18.0, *) {
            PauseTeamControl()
            CallChiefControl()
        }
    }
}
