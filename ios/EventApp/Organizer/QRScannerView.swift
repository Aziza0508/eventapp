import SwiftUI
import AVFoundation

/// QR Scanner for organizer check-in. Scans `eventapp://checkin/{regID}/{hmac}` payloads.
struct QRScannerView: View {
    let event: Event
    @StateObject private var vm = QRScannerViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var cameraMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                QRCameraPreview(
                    onCodeScanned: { code in
                        Task { await vm.handleScan(code: code, eventID: event.id) }
                    },
                    onCameraError: { message in
                        cameraMessage = message
                    }
                )
                .ignoresSafeArea()

                VStack {
                    Spacer()

                    VStack(spacing: AppTheme.Spacing.md) {
                        if let cameraMessage {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(AppTheme.warning)
                            Text(cameraMessage)
                                .font(.subheadline)
                                .foregroundStyle(.white)
                                .multilineTextAlignment(.center)
                        } else {
                            switch vm.state {
                            case .idle:
                                Text("Point camera at participant's QR code")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)

                            case .loading:
                                ProgressView()
                                    .tint(.white)
                                Text("Checking in...")
                                    .font(.subheadline)
                                    .foregroundStyle(.white)

                            case .success(let reg):
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(AppTheme.success)
                                Text("\(reg.user?.fullName ?? "Participant") checked in!")
                                    .font(.headline)
                                    .foregroundStyle(.white)
                                Button("Scan Next") {
                                    vm.reset()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.primary)

                            case .failure(let error):
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundStyle(AppTheme.error)
                                Text(error.localizedDescription)
                                    .font(.subheadline)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                Button("Try Again") {
                                    vm.reset()
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppTheme.primary)
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.xl)
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("QR Check-In")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - ViewModel

@MainActor
final class QRScannerViewModel: ObservableObject {
    @Published var state: Loadable<Registration> = .idle

    private let api = APIClient.shared
    private var lastScanned = ""

    func handleScan(code: String, eventID: Int) async {
        guard state.value == nil && !state.isLoading else { return }
        guard code != lastScanned else { return }
        lastScanned = code

        guard code.hasPrefix("eventapp://checkin/") else {
            state = .failure(NSError(domain: "", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Invalid QR code format"
            ]))
            return
        }

        let parts = code.replacingOccurrences(of: "eventapp://checkin/", with: "").split(separator: "/")
        guard parts.count == 2,
              let regID = Int(parts[0]) else {
            state = .failure(NSError(domain: "", code: 0, userInfo: [
                NSLocalizedDescriptionKey: "Could not parse QR code"
            ]))
            return
        }

        let hmac = String(parts[1])

        state = .loading
        do {
            let reg: Registration = try await api.request(
                .checkinByQR(regID: regID, qrHMAC: hmac),
                responseType: Registration.self
            )
            state = .success(reg)
        } catch {
            state = .failure(error)
        }
    }

    func reset() {
        state = .idle
        lastScanned = ""
    }
}

// MARK: - Camera Preview (AVFoundation)

struct QRCameraPreview: UIViewRepresentable {
    let onCodeScanned: (String) -> Void
    let onCameraError: (String) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        view.backgroundColor = .black
        configureCamera(on: view, context: context)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    private func configureCamera(on view: UIView, context: Context) {
        #if targetEnvironment(simulator)
        onCameraError("Camera is unavailable in the iOS Simulator. Use a physical iPhone to scan QR codes.")
        return
        #else
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startSession(on: view, context: context)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if granted {
                        startSession(on: view, context: context)
                    } else {
                        onCameraError("Camera access is required for QR check-in. Enable it in Settings.")
                    }
                }
            }
        case .denied, .restricted:
            onCameraError("Camera access is disabled. Enable it in Settings to scan participant QR codes.")
        @unknown default:
            onCameraError("Couldn't access the camera on this device.")
        }
        #endif
    }

    private func startSession(on view: UIView, context: Context) {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video) else {
            onCameraError("This device doesn't have a usable camera.")
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            onCameraError("Couldn't start the camera for QR scanning.")
            return
        }
        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            onCameraError("Couldn't read QR codes from the camera feed.")
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = view.bounds

        view.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer
        context.coordinator.session = session

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCodeScanned: (String) -> Void
        var previewLayer: AVCaptureVideoPreviewLayer?
        var session: AVCaptureSession?

        init(onCodeScanned: @escaping (String) -> Void) {
            self.onCodeScanned = onCodeScanned
        }

        func metadataOutput(
            _ output: AVCaptureMetadataOutput,
            didOutput metadataObjects: [AVMetadataObject],
            from connection: AVCaptureConnection
        ) {
            guard let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else { return }
            onCodeScanned(value)
        }
    }
}
