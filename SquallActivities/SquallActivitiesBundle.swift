import SwiftUI
import WidgetKit

/// The SquallActivities extension holds the Live Activities, the team and teammate widgets and the
/// Control Center buttons.
/// The app starts the Live Activities (see Squall/LiveActivities/LiveActivities.swift)
/// and saves the data the widget draws (see Shared/SquallWidgetData.swift).
@main
struct SquallActivitiesBundle: WidgetBundle {
    var body: some Widget {
        TeamStatusWidget()
        TeammateWidget()
        BuildActivityWidget()
        ApprovalActivityWidget()
        RoutineActivityWidget()
        CallActivityWidget()
        TeamActivityWidget()
        WorkTimerActivityWidget()
        // Control Center buttons need iOS 18.
        if #available(iOS 18.0, *) {
            PauseTeamControl()
            CallChiefControl()
        }
    }
}
