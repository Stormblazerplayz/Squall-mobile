import AVFoundation
import SwiftUI
import UIKit

/// Pairs this phone with Squall on the computer, by QR code or by typing the code.
/// Shown on first launch, and from Settings.
struct PairingView: View {
    enum Place {
        case firstRun
        case settings
    }

    let place: Place
    /// First run: finish setup. Settings: close the sheet.
    var onDone: () -> Void

    @EnvironmentObject private var pairing: PairingStore
    @EnvironmentObject private var store: SquallStore
    @Environment(\.openURL) private var openURL

    private enum Mode: Hashable {
        case scan
        case type
    }

    private enum CameraAccess {
        case checking
        case allowed
        case denied
        case unavailable
    }

    @State private var mode: Mode = .scan
    @State private var camera: CameraAccess = .checking
    @State private var address = ""
    @State private var code = ""
    @State private var lastScanned: String?
    @State private var justPaired = false

    var body: some View {
        ZStack {
            GlowBackground()
            ScrollView {
                VStack(spacing: 18) {
                    header
                    if justPaired, let computer = pairing.computer {
                        successCard(computer)
                    } else {
                        PillSegments(
                            options: [
                                (label: "Scan QR code", value: Mode.scan),
                                (label: "Type the code", value: Mode.type)
                            ],
                            selection: $mode
                        )
                        if mode == .scan {
                            scanSection
                        } else {
                            typeSection
                        }
                        if let error = pairing.errorText {
                            errorRow(error)
                        }
                        stepsCard
                    }
                }
                .padding(20)
                .readableColumn(560)
            }
            .scrollIndicators(.hidden)
            .scrollDismissesKeyboard(.interactively)
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            bottomButtons
        }
        .animation(.easeOut(duration: 0.25), value: justPaired)
        .animation(.easeOut(duration: 0.2), value: mode)
        .task { await checkCamera() }
        .onChange(of: mode) {
            pairing.errorText = nil
            lastScanned = nil
        }
        .onChange(of: code) {
            let digits = String(code.filter { $0.isASCII && $0.isNumber }.prefix(6))
            if digits != code { code = digits }
        }
        .onDisappear {
            if !justPaired { pairing.errorText = nil }
        }
    }

    // MARK: Pieces

    private var header: some View {
        VStack(spacing: 10) {
            LogoTile(size: 64)
            Text(title)
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(Theme.textBright)
                .multilineTextAlignment(.center)
            Text(subtitle)
                .font(.system(size: 14.5))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private var scanSection: some View {
        VStack(spacing: 10) {
            switch camera {
            case .checking:
                ProgressView()
                    .tint(Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 300)
                    .glassCard(radius: 22)
            case .allowed:
                QRScannerView(
                    isActive: !pairing.busy && !justPaired,
                    onCode: handleScan,
                    onFailed: {
                        camera = .unavailable
                        mode = .type
                    }
                )
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(scanFrame)
                .overlay {
                    if pairing.busy {
                        busyOverlay
                    }
                }
                .accessibilityLabel("Camera for scanning the QR code")
                Text("Point the camera at the QR code on your computer.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.sub)
                    .multilineTextAlignment(.center)
            case .denied:
                cameraMessage(
                    title: "Squall can't use the camera",
                    text: "Turn on Camera for Squall in the Settings app, or type the code instead.",
                    showSettings: true
                )
            case .unavailable:
                cameraMessage(
                    title: "No camera here",
                    text: "Type the code from your computer instead.",
                    showSettings: false
                )
            }
        }
    }

    private var scanFrame: some View {
        ScannerViewfinder(tint: store.accent, size: 200)
    }

    private var busyOverlay: some View {
        PairingBusyOverlay(tint: store.accent)
    }

    private func cameraMessage(title: String, text: String, showSettings: Bool) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "camera.fill")
                .font(.system(size: 26))
                .foregroundStyle(Theme.sub)
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textBright)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.sub)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                if showSettings {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    }
                    .buttonStyle(GhostButtonStyle(height: 40, fontSize: 14))
                }
                Button("Type the code") { mode = .type }
                    .buttonStyle(FilledButtonStyle(fill: store.accent, height: 40))
            }
            .padding(.top, 4)
        }
        .padding(18)
        .frame(maxWidth: .infinity)
        .glassCard(radius: 22)
    }

    private var typeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: "Computer address")
            DarkField(placeholder: "Like 192.168.1.20", text: $address)
                .keyboardType(.numbersAndPunctuation)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.next)
                .accessibilityLabel("Computer address")
            SectionLabel(text: "6-digit code")
            DarkField(placeholder: "123456", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .accessibilityLabel("6-digit code")
            if !address.isEmpty, PairingTarget.parseAddress(address) == nil {
                Text(PairingError.badAddress.message)
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.redText)
            }
            Button {
                submitTyped()
            } label: {
                if pairing.busy {
                    ProgressView().tint(.white)
                } else {
                    Text("Pair")
                }
            }
            .buttonStyle(FilledButtonStyle(fill: typedTarget != nil ? store.accent : Color.white.opacity(0.12)))
            .disabled(typedTarget == nil || pairing.busy)
            .padding(.top, 4)
        }
        .padding(14)
        .glassCard(radius: 18)
    }

    private func errorRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Theme.redSoft)
            Text(text)
                .font(.system(size: 13.5))
                .foregroundStyle(Theme.redText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .glassCard(radius: 16, tint: 0xE5484D, strength: 0.12)
        .transition(.opacity)
    }

    private var stepsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ON YOUR COMPUTER")
                .font(.system(size: 11, weight: .bold))
                .tracking(0.9)
                .foregroundStyle(Theme.goldText)
            step(1, "Open Squall.")
            step(2, "Go to Settings, then Pair a phone.")
            step(3, mode == .scan ? "Scan the QR code it shows." : "Type the address and the 6-digit code it shows.")
            Text("Keep this \(deviceWord) on the same Wi-Fi as the computer.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
                .padding(.top, 2)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassCard(radius: 18, tint: Theme.goldHex, strength: 0.08)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(Theme.darkInk)
                .frame(width: 20, height: 20)
                .background(Circle().fill(Theme.gold))
            Text(text)
                .font(.system(size: 14))
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func successCard(_ computer: PairedComputer) -> some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 54))
                .foregroundStyle(Theme.green)
            Text("Paired with \(computer.name)")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(Theme.textBright)
                .multilineTextAlignment(.center)
            Text(computer.address)
                .font(Theme.mono(13))
                .foregroundStyle(Theme.sub)
            Text("Your team will show up in a moment.")
                .font(.system(size: 12.5))
                .foregroundStyle(Theme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .glassCard(radius: 22, tint: 0x4ADE80, strength: 0.12)
        .transition(.scale(scale: 0.95).combined(with: .opacity))
    }

    private var bottomButtons: some View {
        VStack(spacing: 8) {
            if justPaired {
                Button(place == .firstRun ? "Let's go" : "Done") { onDone() }
                    .buttonStyle(FilledButtonStyle(fill: store.accent, height: 50))
            } else if place == .firstRun {
                Button("Skip for now") { onDone() }
                    .buttonStyle(GhostButtonStyle(height: 46))
                    .disabled(pairing.busy)
                Text("You can pair later. Squall shows your team once it's paired.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
            } else {
                Button("Cancel") { onDone() }
                    .buttonStyle(GhostButtonStyle(height: 46))
            }
        }
        .readableColumn(560)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(Theme.background.opacity(0.95).ignoresSafeArea(edges: .bottom))
    }

    // MARK: Logic

    private var title: String {
        justPaired ? "You're paired" : "Pair with your computer"
    }

    private var subtitle: String {
        if justPaired {
            return "This \(deviceWord) and your computer know each other now."
        }
        return "Link this \(deviceWord) to Squall on your computer so you can check on your AI team from anywhere in the house."
    }

    private var deviceWord: String {
        UIDevice.current.userInterfaceIdiom == .pad ? "iPad" : "phone"
    }

    private var typedTarget: PairingTarget? {
        PairingTarget.fromTyped(address: address, code: code)
    }

    private func checkCamera() async {
        guard AVCaptureDevice.default(for: .video) != nil else {
            camera = .unavailable
            mode = .type
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            camera = .allowed
        case .notDetermined:
            let allowed = await AVCaptureDevice.requestAccess(for: .video)
            camera = allowed ? .allowed : .denied
        default:
            camera = .denied
        }
    }

    private func handleScan(_ text: String) {
        guard !pairing.busy, !justPaired, text != lastScanned else { return }
        lastScanned = text
        guard let target = PairingTarget.fromQR(text) else {
            pairing.errorText = "That QR code isn't from Squall. Scan the one on your computer's Pair a phone screen."
            allowRescan(of: text)
            return
        }
        Task { await pair(target, scanned: text) }
    }

    private func submitTyped() {
        guard let target = typedTarget else { return }
        Task { await pair(target, scanned: nil) }
    }

    private func pair(_ target: PairingTarget, scanned: String?) async {
        let worked = await pairing.pair(with: target)
        if worked {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            justPaired = true
        } else {
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            if let scanned { allowRescan(of: scanned) }
        }
    }

    /// Lets the same QR code be tried again after a short pause, so one bad scan doesn't repeat many times a second.
    private func allowRescan(of text: String) {
        Task {
            try? await Task.sleep(for: .seconds(3))
            if lastScanned == text { lastScanned = nil }
        }
    }
}
