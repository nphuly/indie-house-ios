import AVFoundation
import SwiftUI
import UIKit

/// Full-screen camera with a yellow 240 frame; camera problems show on the screen, not in a dialog.
struct QRScanView: View {
    @Environment(\.dismiss) private var dismiss
    let scanned: (String) -> Void
    @State private var failed = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if failed {
                EmptyState(icon: "alert", title: L("qr.camera_failed"), message: L("qr.camera_hint"),
                           action: L("common.cancel")) { dismiss() }
            } else {
                QRScanner(scanned: scanned, failed: { failed = true }).ignoresSafeArea()
                Theme.scrim
                    .mask {
                        Rectangle()
                            .overlay(Rectangle().frame(width: 240, height: 240).blendMode(.destinationOut))
                            .compositingGroup()
                    }
                    .ignoresSafeArea()
                    .accessibilityHidden(true)
                Rectangle().strokeBorder(Theme.accent, lineWidth: 2).frame(width: 240, height: 240)
                    .accessibilityHidden(true)
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        Text(upper(L("connect.scan"))).eyebrowStyle(Theme.soft)
                        Text(L("qr.title")).font(.ih(.bold, 20)).multilineTextAlignment(.center)
                    }
                    .padding(.top, 24)
                    Spacer()
                    Text(L("qr.hint"))
                        .font(.ih(.regular, 14))
                        .foregroundStyle(Theme.soft)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    PillButton(title: L("common.cancel"), kind: .secondary, height: 44, fill: false) { dismiss() }
                        .padding(.top, 16)
                        .padding(.bottom, 24)
                }
                .padding(.horizontal, 20)
            }
        }
        .foregroundStyle(Theme.text)
    }
}

private struct QRScanner: UIViewControllerRepresentable {
    let scanned: (String) -> Void
    let failed: () -> Void

    func makeUIViewController(context: Context) -> QRScannerController {
        let controller = QRScannerController()
        controller.scanned = scanned
        controller.failed = failed
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerController, context: Context) { }
}

final class QRScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var scanned: ((String) -> Void)?
    var failed: (() -> Void)?
    private let capture = AVCaptureSession()
    private var done = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted { self?.configure() } else { self?.failed?() }
            }
        }
    }

    private func configure() {
        guard let camera = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: camera),
              capture.canAddInput(input) else { failed?(); return }
        capture.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard capture.canAddOutput(output) else { failed?(); return }
        capture.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        let layer = AVCaptureVideoPreviewLayer(session: capture)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        let session = capture
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        (view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer)?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        let session = capture
        DispatchQueue.global(qos: .userInitiated).async { session.stopRunning() }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        guard !done, let value = (metadataObjects.first as? AVMetadataMachineReadableCodeObject)?.stringValue else { return }
        done = true
        scanned?(value)
    }
}
