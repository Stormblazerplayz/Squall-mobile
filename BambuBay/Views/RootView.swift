import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app
    @Environment(WatchCenter.self) private var watch
    @Environment(Router.self) private var router

    var body: some View {
        @Bindable var router = router
        @Bindable var watch = watch
        TabView(selection: $router.tab) {
            PrintersScreen()
                .tabItem { Label("Printers", systemImage: "printer.fill") }
                .tag(Router.Tab.printers)
            QueueScreen()
                .tabItem { Label("Queue", systemImage: "list.bullet.rectangle.portrait.fill") }
                .badge(app.waitingJobs.count)
                .tag(Router.Tab.queue)
            WatchScreen()
                .tabItem { Label("Watch", systemImage: "eye.fill") }
                .tag(Router.Tab.watch)
            HistoryScreen()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
                .tag(Router.Tab.history)
            SettingsScreen()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
                .tag(Router.Tab.settings)
        }
        .sheet(item: $router.incomingFile) { incoming in
            AddJobSheet(source: incoming.url)
        }
        .sheet(item: $watch.alert) { alert in
            SpaghettiAlertSheet(alert: alert)
                .presentationDetents([.medium, .large])
        }
        .overlay(alignment: .top) {
            if let message = app.banner {
                BannerView(message: message) { app.banner = nil }
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: message) {
                        try? await Task.sleep(nanoseconds: 6_000_000_000)
                        if app.banner == message { app.banner = nil }
                    }
            }
        }
        .animation(.spring(duration: 0.35), value: app.banner)
    }
}

struct BannerView: View {
    var message: String
    var close: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(Theme.warn)
            Text(message).font(.subheadline).frame(maxWidth: .infinity, alignment: .leading)
            Button(action: close) {
                Image(systemName: "xmark").font(.caption.weight(.bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(radius: 10)
    }
}

struct SpaghettiAlertSheet: View {
    let alert: WatchCenter.Alert
    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Capsule().fill(Color.white.opacity(0.2)).frame(width: 40, height: 5).padding(.top, 8)
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill").font(.title2).foregroundStyle(Theme.bad)
                VStack(alignment: .leading) {
                    Text(alert.paused ? "Paused \(alert.printerName)" : "Possible spaghetti")
                        .font(.title2.weight(.bold))
                    Text("\(alert.printerName) · the model is \(Int((alert.score * 100).rounded()))% sure"
                         + (alert.label.map { " (\($0))" } ?? ""))
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            }
            if let image = alert.image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            if alert.paused {
                Text("The print is paused. Check the bed before you resume.")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    Button("Keep paused") { dismiss() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    Button("Resume") {
                        app.link(for: alert.printerID)?.resume()
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                }
            } else {
                HStack {
                    Button("It's fine") { dismiss() }
                        .buttonStyle(.bordered)
                        .frame(maxWidth: .infinity)
                    Button(role: .destructive) {
                        app.link(for: alert.printerID)?.pause()
                        dismiss()
                    } label: {
                        Label("Pause print", systemImage: "pause.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.bad)
                    .frame(maxWidth: .infinity)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
        .background(Theme.background)
    }
}
