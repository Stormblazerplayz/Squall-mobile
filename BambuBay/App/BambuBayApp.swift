import SwiftUI
import UIKit

@main
struct BambuBayApp: App {
    @State private var app: AppModel
    @State private var models: ModelStore
    @State private var watch: WatchCenter
    @State private var router = Router()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Notifier.shared.setUp()
        let app = AppModel()
        let models = ModelStore()
        let watch = WatchCenter()
        watch.app = app
        watch.models = models
        _app = State(initialValue: app)
        _models = State(initialValue: models)
        _watch = State(initialValue: watch)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .environment(models)
                .environment(watch)
                .environment(router)
                .tint(Theme.accent)
                .preferredColorScheme(.dark)
                .task {
                    app.start()
                    watch.start()
                }
                .onOpenURL { url in
                    router.openFile(url)
                }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active:
                watch.isActive = true
                app.becameActive()
                UIApplication.shared.isIdleTimerDisabled = app.settings.keepScreenOn
            case .background:
                watch.isActive = false
                UIApplication.shared.isIdleTimerDisabled = false
                BackgroundCheck.schedule()
            default:
                break
            }
        }
        .backgroundTask(.appRefresh(BackgroundCheck.identifier)) {
            await BackgroundCheck.run()
        }
    }
}

/// Which tab is showing, and a file waiting to be added to the queue.
@MainActor
@Observable
final class Router {
    enum Tab: Hashable { case printers, queue, watch, history, settings }

    var tab: Tab = .printers
    var incomingFile: IncomingFile?

    struct IncomingFile: Identifiable {
        let id = UUID()
        let url: URL
    }

    func openFile(_ url: URL) {
        guard url.isFileURL else { return }
        tab = .queue
        incomingFile = IncomingFile(url: url)
    }
}
