import SwiftUI
import WidgetKit

/// The SquallActivities extension only holds Live Activities.
/// The app starts them; see Squall/LiveActivities/LiveActivities.swift.
@main
struct SquallActivitiesBundle: WidgetBundle {
    var body: some Widget {
        BuildActivityWidget()
        ApprovalActivityWidget()
        RoutineActivityWidget()
        CallActivityWidget()
        TeamActivityWidget()
    }
}
