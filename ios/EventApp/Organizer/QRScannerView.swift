import SwiftUI
import AVFoundation

/// QR Scanner for organizer check-in. Scans `eventapp://checkin/{regID}/{hmac}` payloads.
struct QRScannerView: View {
    let event: Event
    @StateObject private var vm = QRScannerViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                // Camera preview.
                QRCameraPreview(onCodeScanned: { code in
                    Task { await vm.handleScan(code: code, eventID: event.id) }
                })
                .ignoresSafeArea()

                // Overlay.
                VStack {
                    Spacer()

                    VStack(spacing: AppTheme.Spacing.md) {
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

        // Parse: eventapp://checkin/{regID}/{hmac}
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

    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: .zero)
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }

        session.addInput(input)

        let output = AVCaptureMetadataOutput()
        session.addOutput(output)
        output.setMetadataObjectsDelegate(context.coordinator, queue: .main)
        output.metadataObjectTypes = [.qr]

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.frame = UIScreen.main.bounds
        view.layer.addSublayer(previewLayer)

        context.coordinator.previewLayer = previewLayer

        DispatchQueue.global(qos: .userInitiated).async {
            session.startRunning()
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.previewLayer?.frame = uiView.bounds
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onCodeScanned: onCodeScanned)
    }

    class Coordinator: NSObject, AVCaptureMetadataOutputObjectsDelegate {
        let onCodeScanned: (String) -> Void
        var previewLayer: AVCaptureVideoPreviewLayer?

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
