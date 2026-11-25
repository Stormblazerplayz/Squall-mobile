import SwiftUI

/// The replay filmstrip under the live screen: a real picture of the computer's screen for each step of
/// the task (each screenshot Squall Uno took, and the screen right after each click, typing or key).
/// Tap one to replay the task step by step. The pictures come from the PC and are only kept until
/// Squall on the PC restarts, so an older task may have none.
struct UnoFilmstrip: View {
    @EnvironmentObject private var pairing: PairingStore
    @EnvironmentObject private var lock: AppLock
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var film = UnoFilm()
    let session: UnoSession
    let agentName: String

    @State private var openShot: UnoShot?

    private var reloadKey: String { "\(session.id)|\(session.steps)|\(session.state)" }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if film.available, film.sessionId == session.id {
                header
                if film.shots.isEmpty {
                    Text(session.isActive
                         ? "A picture of the screen shows up here after each step."
                         : "No pictures are kept for this task. They're kept until Squall on your PC restarts.")
                        .font(.system(size: 13.5))
                        .foregroundStyle(UnoColors.muted)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .glassCard(radius: 16)
                } else {
                    strip
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: reloadKey) { await reload() }
        .fullScreenCover(item: $openShot) { shot in
            UnoReplayView(film: film, startId: shot.id, agentName: agentName)
                .lockCover()
                .environmentObject(pairing)
                .environmentObject(lock)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            SectionLabel(text: "Replay")
            Spacer(minLength: 8)
            if let last = film.shots.last {
                Button {
                    openShot = film.shots.first ?? last
                } label: {
                    Label("Play from the start", systemImage: "play.fill")
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(UnoColors.purple)
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.plain)
                .fixedSize()
            }
        }
    }

    private var strip: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 8) {
                    ForEach(film.shots) { shot in
                        Button {
                            openShot = shot
                        } label: {
                            UnoShotThumb(film: film, shot: shot, newest: shot.id == film.shots.last?.id && session.isActive)
                        }
                        .buttonStyle(.plain)
                        .id(shot.id)
                        .transition(reduceMotion ? AnyTransition.opacity : AnyTransition.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, 2)
                .animation(reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.85), value: film.shots.map(\.id))
            }
            .scrollIndicators(.hidden)
            .frame(height: 100)
            .onAppear {
                if let newest = film.shots.last?.id { proxy.scrollTo(newest, anchor: .trailing) }
            }
            .onChange(of: film.shots.last?.id) { _, newest in
                guard let newest else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.3)) {
                    proxy.scrollTo(newest, anchor: .trailing)
                }
            }
        }
    }

    /// Asks for the list again whenever the task takes a step. The picture after a step is kept a moment
    /// after the step itself, so a working task asks once more shortly after.
    @MainActor
    private func reload() async {
        let id = session.id
        let active = session.isActive
        await film.load(pairing, sessionId: id)
        guard active else { return }
        try? await Task.sleep(for: .milliseconds(1600))
        guard !Task.isCancelled else { return }
        await film.load(pairing, sessionId: id)
    }
}

/// One small picture in the filmstrip, with its step number.
struct UnoShotThumb: View {
    @EnvironmentObject private var pairing: PairingStore
    @ObservedObject var film: UnoFilm
    let shot: UnoShot
    /// The newest picture of a task that's still working gets a purple edge.
    var newest = false

    @State private var image: UIImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.black.opacity(0.55))
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.medium)
                        .scaledToFill()
                        .frame(width: 120, height: 75)
                        .transition(.opacity)
                } else {
                    ProgressView()
                        .controlSize(.small)
                        .tint(UnoColors.muted)
                }
            }
            .frame(width: 120, height: 75)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(alignment: .topLeading) {
                Image(systemName: UnoFilmMath.icon(shot.kind))
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(UnoColors.text)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    .padding(5)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(newest ? UnoColors.purple : Theme.cardBorder, lineWidth: newest ? 2 : 1)
            )
            Text(shot.step > 0 ? "Step \(shot.step)" : "Start")
                .font(.system(size: 11.5, weight: .semibold))
                .foregroundStyle(newest ? UnoColors.text : UnoColors.muted)
                .monospacedDigit()
                .padding(.leading, 2)
        }
        .contentShape(Rectangle())
        .task(id: shot.id) {
            if let ready = film.cached(shot) {
                image = ready
                return
            }
            let loaded = await film.image(pairing, for: shot)
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(UnoFilmMath.label(shot))
        .accessibilityHint("Opens the replay at this step.")
        .accessibilityAddTraits(.isButton)
    }
}

/// Full-screen replay of a task, one real picture per step. Swipe or use the buttons to move between
/// steps, or press play to watch it go by. New pictures keep arriving while the task is still working.
struct UnoReplayView: View {
    @EnvironmentObject private var pairing: PairingStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(Prefs.haptics) private var haptics = true
    @ObservedObject var film: UnoFilm
    let agentName: String

    @State private var selection: Int
    @State private var playing = false
    /// "3/12" while the GIF is being made, nil otherwise.
    @State private var saving: String?
    @State private var saveTask: Task<Void, Never>?
    @State private var shareFile: UnoShareFile?
    @State private var saveProblem: String?

    init(film: UnoFilm, startId: Int, agentName: String) {
        self.film = film
        self.agentName = agentName
        _selection = State(initialValue: startId)
    }

    private var shots: [UnoShot] { film.shots }
    private var current: UnoShot? { shots.first { $0.id == selection } }
    private var previous: UnoShot? { UnoFilmMath.neighbor(of: selection, by: -1, in: shots) }
    private var next: UnoShot? { UnoFilmMath.neighbor(of: selection, by: 1, in: shots) }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 0) {
                topBar
                if shots.isEmpty {
                    Spacer()
                    Text("These pictures aren't kept anymore.")
                        .font(.system(size: 15))
                        .foregroundStyle(UnoColors.muted)
                        .padding(24)
                    Spacer()
                } else {
                    TabView(selection: $selection) {
                        ForEach(shots) { shot in
                            UnoReplayPage(film: film, shot: shot)
                                .tag(shot.id)
                        }
                    }
                    .tabViewStyle(.page(indexDisplayMode: .never))
                    bottomBar
                }
            }
        }
        .preferredColorScheme(.dark)
        .sensoryFeedback(.selection, trigger: selection) { _, _ in haptics && !playing }
        .task(id: playing) { await playLoop() }
        .sheet(item: $shareFile) { file in
            UnoShareSheet(items: [file.url])
                .presentationDetents([.medium, .large])
        }
        .alert("Couldn't make the GIF", isPresented: Binding(
            get: { saveProblem != nil },
            set: { if !$0 { saveProblem = nil } }
        )) {
            Button("OK", role: .cancel) { saveProblem = nil }
        } message: {
            Text(saveProblem ?? "")
        }
        .onDisappear { saveTask?.cancel() }
        .onChange(of: shots.map(\.id)) { _, ids in
            // The PC drops its oldest pictures to save room; stay on a picture that's still there.
            if !ids.contains(selection), let first = ids.first {
                selection = ids.first(where: { $0 > selection }) ?? ids.last ?? first
            }
        }
    }

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                playing = false
                saveTask?.cancel()
                dismiss()
            } label: {
                Label("Back to live", systemImage: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(UnoColors.text)
                    .padding(.horizontal, 12)
                    .frame(height: 36)
                    .background(Capsule().fill(Color.white.opacity(0.1)))
            }
            .buttonStyle(.plain)
            Spacer(minLength: 8)
            shareButton
            VStack(alignment: .trailing, spacing: 1) {
                Text("\(agentName)'s replay")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(UnoColors.text)
                    .lineLimit(1)
                Text(UnoFilmMath.position(of: selection, in: shots))
                    .font(.system(size: 12))
                    .foregroundStyle(UnoColors.muted)
                    .monospacedDigit()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var shareButton: some View {
        Button {
            makeGIF()
        } label: {
            HStack(spacing: 6) {
                if let saving {
                    ProgressView()
                        .controlSize(.small)
                        .tint(UnoColors.text)
                    Text(saving)
                        .font(.system(size: 12.5, weight: .semibold))
                        .monospacedDigit()
                } else {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .semibold))
                }
            }
            .foregroundStyle(UnoColors.text)
            .padding(.horizontal, saving == nil ? 0 : 10)
            .frame(minWidth: 36, minHeight: 36)
            .background(Capsule().fill(Color.white.opacity(0.1)))
        }
        .buttonStyle(.plain)
        .disabled(saving != nil || shots.isEmpty)
        .accessibilityLabel(saving == nil ? "Share the replay as a GIF" : "Making the GIF, \(saving ?? "")")
    }

    /// Fetches every picture, makes the GIF off the main thread, then opens the share sheet.
    private func makeGIF() {
        guard saving == nil, !shots.isEmpty else { return }
        playing = false
        saving = "0/\(shots.count)"
        let name = UnoReplayGIF.fileName(agent: agentName)
        saveTask = Task { @MainActor in
            defer { saving = nil }
            let frames = await film.gifFrames(pairing) { done, total in
                saving = "\(done)/\(total)"
            }
            guard !Task.isCancelled else { return }
            guard !frames.isEmpty else {
                saveProblem = "Your PC doesn't keep these pictures anymore."
                return
            }
            let data = await Task.detached(priority: .userInitiated) { UnoReplayGIF.make(frames) }.value
            guard !Task.isCancelled else { return }
            guard let data, let url = try? UnoReplayGIF.write(data, name: name) else {
                saveProblem = "Your phone couldn't write the GIF. Try again."
                return
            }
            shareFile = UnoShareFile(url: url)
        }
    }

    private var bottomBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let current {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: UnoFilmMath.icon(current.kind))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(UnoColors.purple)
                        .frame(width: 18)
                        .padding(.top, 1)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(UnoFilmMath.label(current))
                            .font(.system(size: 14.5, weight: .semibold))
                            .foregroundStyle(UnoColors.text)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                        if let date = current.date {
                            Text(date.formatted(date: .omitted, time: .standard))
                                .font(.system(size: 12))
                                .foregroundStyle(UnoColors.muted)
                                .monospacedDigit()
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: current.id)
            }
            HStack(spacing: 18) {
                Spacer()
                controlButton("backward.frame.fill", label: "Previous step", enabled: previous != nil) {
                    playing = false
                    move(to: previous)
                }
                Button {
                    playing.toggle()
                } label: {
                    Image(systemName: playing ? "pause.fill" : "play.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(UnoColors.purple))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(playing ? "Pause" : "Play the replay")
                controlButton("forward.frame.fill", label: "Next step", enabled: next != nil) {
                    playing = false
                    move(to: next)
                }
                Spacer()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 18)
    }

    private func controlButton(_ symbol: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(enabled ? UnoColors.text : UnoColors.wait)
                .frame(width: 48, height: 48)
                .background(Circle().fill(Color.white.opacity(enabled ? 0.1 : 0.04)))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
    }

    private func move(to shot: UnoShot?) {
        guard let shot else { return }
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { selection = shot.id }
    }

    /// Steps through the pictures while play is on. Starting at the end starts over from the first picture.
    @MainActor
    private func playLoop() async {
        guard playing else { return }
        if next == nil, let first = shots.first, first.id != selection {
            move(to: first)
        }
        while playing, !Task.isCancelled {
            try? await Task.sleep(for: .milliseconds(800))
            guard playing, !Task.isCancelled else { return }
            guard let upcoming = next else {
                playing = false
                return
            }
            move(to: upcoming)
        }
    }
}

/// One picture in the replay, fitted to the screen, with a ring where the mouse was.
struct UnoReplayPage: View {
    @EnvironmentObject private var pairing: PairingStore
    @ObservedObject var film: UnoFilm
    let shot: UnoShot

    @State private var image: UIImage?
    @State private var missing = false

    var body: some View {
        GeometryReader { geo in
            let rect = UnoMath.fitRect(content: shot.size, in: geo.size)
            ZStack {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .interpolation(.medium)
                        .frame(width: rect.width, height: rect.height)
                        .position(x: rect.midX, y: rect.midY)
                        .accessibilityLabel("The screen at \(UnoFilmMath.label(shot))")
                    if let cursor = shot.cursor {
                        Circle()
                            .fill(UnoColors.blueBright.opacity(0.3))
                            .overlay(Circle().stroke(UnoColors.blueBright, lineWidth: 2))
                            .frame(width: 24, height: 24)
                            .position(
                                x: rect.minX + cursor.x / shot.size.width * rect.width,
                                y: rect.minY + cursor.y / shot.size.height * rect.height
                            )
                            .accessibilityHidden(true)
                    }
                } else if missing {
                    Text("This picture isn't kept anymore.")
                        .font(.system(size: 14))
                        .foregroundStyle(UnoColors.muted)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                } else {
                    ProgressView()
                        .tint(.white)
                        .position(x: geo.size.width / 2, y: geo.size.height / 2)
                }
            }
        }
        .padding(.horizontal, 6)
        .task(id: shot.id) {
            if let ready = film.cached(shot) {
                image = ready
                return
            }
            let loaded = await film.image(pairing, for: shot)
            guard !Task.isCancelled else { return }
            image = loaded
            missing = loaded == nil
        }
    }
}

/// A file ready to share, as a sheet item.
struct UnoShareFile: Identifiable {
    let url: URL
    var id: String { url.path }
}

/// The system share sheet (Save Image, Messages, AirDrop, …).
struct UnoShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
