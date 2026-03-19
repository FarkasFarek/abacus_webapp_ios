import AVFoundation
import SwiftUI
import UIKit

struct QRCameraView: UIViewControllerRepresentable {
    var onScan: (String) -> Void
    func makeUIViewController(context: Context) -> QRCameraViewController {
        let vc = QRCameraViewController(); vc.onScan = onScan; return vc
    }
    func updateUIViewController(_ vc: QRCameraViewController, context: Context) {}
}

class QRCameraViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onScan: ((String) -> Void)?
    private var captureSession: AVCaptureSession?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermission()
    }

    private func checkPermission() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async { if granted { self.setupCamera() } }
            }
        default: showPermissionDenied()
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else { return }
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else { return }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr, .ean13, .ean8, .code128, .code39]
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        captureSession = session
        DispatchQueue.global(qos: .userInitiated).async { session.startRunning() }
        addOverlay()
    }

    private func addOverlay() {
        let w: CGFloat = 240
        let box = UIView(frame: CGRect(x: (view.bounds.width - w) / 2, y: (view.bounds.height - w) / 2, width: w, height: w))
        box.layer.borderColor = UIColor.systemGreen.cgColor
        box.layer.borderWidth = 2.5
        box.layer.cornerRadius = 16
        box.backgroundColor = .clear
        view.addSubview(box)
    }

    private func showPermissionDenied() {
        DispatchQueue.main.async {
            let label = UILabel()
            label.text = "Kamera hozzáférés megtagadva.\nEngedélyezd a Beállításokban."
            label.textColor = .white; label.textAlignment = .center; label.numberOfLines = 0
            label.frame = self.view.bounds
            self.view.addSubview(label)
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard !hasScanned,
              let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let code = obj.stringValue else { return }
        hasScanned = true
        captureSession?.stopRunning()
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        onScan?(code)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession?.stopRunning()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        hasScanned = false
        if !(captureSession?.isRunning ?? false) {
            DispatchQueue.global(qos: .userInitiated).async { self.captureSession?.startRunning() }
        }
    }
}
