import AVFoundation
import SwiftUI
import UIKit

/// Live camera view that reports the text of any QR code it sees.
struct QRScannerView: UIViewControllerRepresentable {
    /// Turns the camera on and off without tearing the view down.
    var isActive: Bool
    var onCode: @MainActor (String) -> Void
    /// Called if this device has no camera that can be used.
    var onFailed: @MainActor () -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        QRScannerController()
    }

    func updateUIViewController(_ controller: QRScannerController, context: Context) {
        controller.capture.onCode = onCode
        controller.capture.onFailed = onFailed
        controller.capture.setRunning(isActive)
    }

    static func dismantleUIViewController(_ controller: QRScannerController, coordinator: ()) {
        controller.capture.setRunning(false)
    }
}

/// Shows the camera picture and keeps it the right way up when an iPad turns.
final class QRScannerController: UIViewController {
    let capture = QRCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var rotationCoordinator: AVCaptureDevice.RotationCoordinator?
    private var rotationObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: capture.session)
        layer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(layer)
        previewLayer = layer
        capture.onReady = { [weak self] device in
            self?.followRotation(of: device)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        if let rotationCoordinator {
            applyRotation(rotationCoordinator.videoRotationAngleForHorizonLevelPreview)
        }
    }

    private func followRotation(of device: AVCaptureDevice) {
        guard let previewLayer else { return }
        let coordinator = AVCaptureDevice.RotationCoordinator(device: device, previewLayer: previewLayer)
        rotationCoordinator = coordinator
        applyRotation(coordinator.videoRotationAngleForHorizonLevelPreview)
        rotationObservation = coordinator.observe(\.videoRotationAngleForHorizonLevelPreview, options: [.new]) { [weak self] _, change in
            guard let angle = change.newValue else { return }
            Task { @MainActor in
                self?.applyRotation(angle)
            }
        }
    }

    private func applyRotation(_ angle: CGFloat) {
        guard let connection = previewLayer?.connection,
              connection.isVideoRotationAngleSupported(angle) else { return }
        connection.videoRotationAngle = angle
    }
}

/// Owns the camera session. Starting and stopping happen on a background queue, as Apple asks.
final class QRCaptureSession: NSObject, AVCaptureMetadataOutputObjectsDelegate, @unchecked Sendable {
    let session = AVCaptureSession()
    /// These three are set and called on the main thread.
    var onCode: (@MainActor (String) -> Void)?
    var onFailed: (@MainActor () -> Void)?
    var onReady: (@MainActor (AVCaptureDevice) -> Void)?

    private let queue = DispatchQueue(label: "com.stormblazerplayz.squall.qr")
    private var triedSetup = false
    private var ready = false
    private var wantsRunning = false

    func setRunning(_ running: Bool) {
        queue.async { [self] in
            wantsRunning = running
            if running && !triedSetup {
                setUp()
            }
            guard ready else { return }
            if wantsRunning && !session.isRunning {
                session.startRunning()
            } else if !wantsRunning && session.isRunning {
                session.stopRunning()
            }
        }
    }

    /// Runs once, on `queue`.
    private func setUp() {
        triedSetup = true
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
                ?? AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            fail()
            return
        }
        session.beginConfiguration()
        guard session.canAddInput(input) else {
            session.commitConfiguration()
            fail()
            return
        }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            fail()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        guard output.availableMetadataObjectTypes.contains(.qr) else {
            session.commitConfiguration()
            fail()
            return
        }
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration()
        ready = true
        Task { @MainActor [weak self] in
            self?.onReady?(device)
        }
    }

    private func fail() {
        Task { @MainActor [weak self] in
            self?.onFailed?()
        }
    }

    // Called on the main queue (set above).
    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let code = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              code.type == .qr,
              let text = code.stringValue else { return }
        Task { @MainActor [weak self] in
            self?.onCode?(text)
        }
    }
}
