import SwiftUI
import UIKit

/// The live screen, full size. Pinch to zoom (1x to 4x), drag to move around while zoomed in, and double-tap
/// to zoom in on a spot or back out. Turn the phone sideways for the biggest picture. It shows the same real
/// screen, mouse, clicks and motion as the live view, and keeps Pause, Resume and Stop at hand.
struct UnoBigScreenView: View {
    @EnvironmentObject private var uno: UnoModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @AppStorage(Prefs.haptics) private var haptics = true
    let agentId: String
    let agentName: String
    /// Click ripples, the moved mouse and motion effects come from the live view, which plays real events.
    var ripples: [UnoRipple] = []
    var emptyText: String
    var cursorOverride: CGPoint? = nil
    var effects = UnoScreenEffects()

    @State private var zoom = UnoZoomState.identity
    @State private var pinchStart: UnoZoomState?
    @State private var panStart: UnoZoomState?
    @State private var zoomTaps = 0

    /// Its own name, so closing the big screen never stops the live view's screen.
    private var watcher: String { "big.\(agentId)" }
    private var computerId: String { uno.computerId(forAgent: agentId) }
    private var computer: UnoComputer? { uno.computer(forAgent: agentId) }
    private var running: UnoSession? { uno.runningSession(onComputer: computerId) }
    private var compact: Bool { verticalSizeClass == .compact }

    private var liveFrame: UnoLiveFrame? {
        guard let frame = uno.frame, frame.computerId == computerId else { return nil }
        return frame
    }

    private var fallbackSize: CGSize {
        computer?.size ?? CGSize(width: 1280, height: 800)
    }

    /// The same size UnoScreenView fits the picture by.
    private var computerSize: CGSize {
        if let liveFrame { return liveFrame.size }
        return CGSize(width: max(fallbackSize.width, 1), height: max(fallbackSize.height, 1))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            GeometryReader { geo in
                let box = geo.size
                let fit = UnoMath.fitRect(content: computerSize, in: box).size
                let shown = UnoZoomMath.clamp(zoom, content: fit, box: box)
                UnoScreenView(
                    frame: liveFrame,
                    fallbackSize: fallbackSize,
                    ripples: ripples,
                    emptyText: emptyText,
                    cursorOverride: cursorOverride,
                    effects: effects
                )
                .frame(width: fit.width, height: fit.height)
                .scaleEffect(shown.scale)
                .offset(shown.offset)
                .frame(width: box.width, height: box.height)
                .contentShape(Rectangle())
                .clipped()
                .gesture(
                    SpatialTapGesture(count: 2).onEnded { value in
                        toggleZoom(at: value.location, fit: fit, box: box)
                    }
                )
                .simultaneousGesture(pinch(fit: fit, box: box).simultaneously(with: pan(fit: fit, box: box)))
                .accessibilityElement(children: .contain)
                .accessibilityAction(named: Text(shown.isZoomed ? "Zoom out" : "Zoom in")) {
                    toggleZoom(at: CGPoint(x: box.width / 2, y: box.height / 2), fit: fit, box: box)
                }
            }
        }
        .overlay(alignment: .top) {
            topBar
        }
        .overlay(alignment: compact ? .bottomTrailing : .bottom) {
            controls
        }
        .preferredColorScheme(.dark)
        .statusBarHidden(compact)
        .sensoryFeedback(.impact(weight: .light), trigger: zoomTaps) { _, _ in haptics }
        .onAppear {
            uno.show(watcher)
            uno.showFrames(watcher, computerId: computerId)
            UnoOrientation.allowLandscape(true)
        }
        .onDisappear {
            uno.hide(watcher)
            uno.hideFrames(watcher)
            UnoOrientation.allowLandscape(false)
        }
        .onChange(of: computerId) {
            uno.showFrames(watcher, computerId: computerId)
            zoom = .identity
        }
    }

    // MARK: Bars

    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                close()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(UnoColors.text)
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color.black.opacity(0.6)))
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close big screen")
            Text(agentName)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(UnoColors.text)
                .lineLimit(1)
                .padding(.horizontal, 12)
                .frame(height: 32)
                .background(Capsule().fill(Color.black.opacity(0.6)))
            if let running {
                if running.isPaused {
                    UnoPausedPill()
                } else {
                    UnoLivePill()
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                }
            }
            Spacer(minLength: 0)
            if zoom.isZoomed {
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
                        zoom = .identity
                    }
                    zoomTaps += 1
                } label: {
                    Text(String(format: "%.1f×", zoom.scale))
                        .font(.system(size: 13, weight: .semibold))
                        .monospacedDigit()
                        .foregroundStyle(UnoColors.text)
                        .padding(.horizontal, 12)
                        .frame(height: 32)
                        .background(Capsule().fill(Color.black.opacity(0.6)))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Zoomed in. Zoom out")
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 6)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: zoom.isZoomed)
    }

    @ViewBuilder
    private var controls: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let notice = uno.notice {
                UnoNoticeText(text: notice)
            }
            if let session = running {
                HStack(spacing: 8) {
                    if !session.youHaveTheWheel {
                        UnoPauseButton(session: session, height: 40)
                    }
                    UnoStopButton(session: session, height: 40)
                }
            }
        }
        .frame(maxWidth: compact ? 280 : 360)
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    // MARK: Zoom

    /// Pinch to zoom around the spot between your fingers.
    private func pinch(fit: CGSize, box: CGSize) -> some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let start = pinchStart ?? UnoZoomMath.clamp(zoom, content: fit, box: box)
                if pinchStart == nil { pinchStart = start }
                zoom = UnoZoomMath.zoom(start, to: start.scale * value.magnification, around: value.startLocation, content: fit, box: box)
            }
            .onEnded { _ in
                pinchStart = nil
                panStart = nil
                zoom = UnoZoomMath.clamp(zoom, content: fit, box: box)
            }
    }

    /// Drag to move around while zoomed in. Does nothing at 1x.
    private func pan(fit: CGSize, box: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 4)
            .onChanged { value in
                guard pinchStart == nil else {
                    panStart = nil
                    return
                }
                let current = UnoZoomMath.clamp(zoom, content: fit, box: box)
                guard current.isZoomed else { return }
                // Starting from where the picture is now, so a drag that outlives a pinch doesn't jump.
                let start = panStart ?? UnoZoomState(
                    scale: current.scale,
                    offset: CGSize(
                        width: current.offset.width - value.translation.width,
                        height: current.offset.height - value.translation.height
                    )
                )
                if panStart == nil { panStart = start }
                zoom = UnoZoomMath.pan(start, by: value.translation, content: fit, box: box)
            }
            .onEnded { _ in
                panStart = nil
                zoom = UnoZoomMath.clamp(zoom, content: fit, box: box)
            }
    }

    /// Double tap: 2.5x around the tap, or back to 1x.
    private func toggleZoom(at point: CGPoint, fit: CGSize, box: CGSize) {
        let current = UnoZoomMath.clamp(zoom, content: fit, box: box)
        let next = UnoZoomMath.doubleTap(current, at: point, content: fit, box: box)
        withAnimation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.86)) {
            zoom = next
        }
        zoomTaps += 1
    }

    private func close() {
        UnoOrientation.allowLandscape(false)
        dismiss()
    }
}

/// Which ways the iPhone may turn. The app stays upright everywhere except the big screen, which can
/// turn sideways to fit the computer's wide screen. iPad always turns freely.
@MainActor
enum UnoOrientation {
    /// What the app delegate hands to iOS on iPhone.
    static var phoneMask: UIInterfaceOrientationMask = .portrait

    static func allowLandscape(_ allow: Bool) {
        guard UIDevice.current.userInterfaceIdiom == .phone else { return }
        let mask: UIInterfaceOrientationMask = allow ? .allButUpsideDown : .portrait
        guard mask != phoneMask else { return }
        phoneMask = mask
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                var controller = window.rootViewController
                while let current = controller {
                    current.setNeedsUpdateOfSupportedInterfaceOrientations()
                    controller = current.presentedViewController
                }
            }
            if !allow {
                windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait)) { _ in }
            }
        }
    }
}
