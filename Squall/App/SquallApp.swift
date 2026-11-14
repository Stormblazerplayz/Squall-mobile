import SwiftUI

@main
struct SquallApp: App {
    @StateObject private var store = SquallStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}
