import SwiftUI
import WidgetKit

/// The SquallActivities extension holds the Live Activities and the team widget.
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
    }
}
