import SwiftUI
import AVFoundation
import MLKitBarcodeScanning
import MLKitVision

struct MLKitScannerView: View {
    typealias ResultHandler = (Result<String, MLKitScannerViewController.ScannerError>) -> Void
    var completion: ResultHandler
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Сканер
            MLKitScannerRepresentable(completion: completion)
                .ignoresSafeArea()

            // Визуальный оверлей с рамкой
            ScannerOverlayView()

            // Кнопка закрытия внизу экрана
            VStack {
                Spacer()
                
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .bold))
                        Text("Закрыть")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.vertical, 14)
                    .padding(.horizontal, 28)
                    .background(Color.black.opacity(0.65))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 0, y: 4)
                }
                .padding(.bottom, 40)
            }
        }
    }
}

// Визуальная рамка во всю ширину экрана
private struct ScannerOverlayView: View {
    private let horizontalPadding: CGFloat = 16

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - (horizontalPadding * 2)
            let height: CGFloat = 200

            ZStack {
                // Полупрозрачный затемняющий слой с прозрачным вырезом по центру
                Color.black.opacity(0.5)
                    .mask(
                        CutoutShape(rectSize: CGSize(width: width, height: height))
                            .fill(style: FillStyle(eoFill: true))
                    )

                // Белая рамка с закругленными углами
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: width, height: height)
                    .shadow(color: .black.opacity(0.3), radius: 5)
            }
        }
        .ignoresSafeArea()
    }
}

// Форма для создания прозрачной области по центру
private struct CutoutShape: Shape {
    let rectSize: CGSize

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addRect(rect)
        
        let boxRect = CGRect(
            x: (rect.width - rectSize.width) / 2,
            y: (rect.height - rectSize.height) / 2,
            width: rectSize.width,
            height: rectSize.height
        )
        path.addRoundedRect(in: boxRect, cornerSize: CGSize(width: 16, height: 16))
        return path
    }
}

// UIViewControllerRepresentable обертка
struct MLKitScannerRepresentable: UIViewControllerRepresentable {
    typealias ResultHandler = (Result<String, MLKitScannerViewController.ScannerError>) -> Void
    var completion: ResultHandler

    func makeUIViewController(context: Context) -> MLKitScannerViewController {
        let viewController = MLKitScannerViewController()
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: MLKitScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    class Coordinator: NSObject, MLKitScannerDelegate {
        var completion: ResultHandler
        private var didFindCode = false

        init(completion: @escaping ResultHandler) {
            self.completion = completion
        }

        func didDetectBarcode(code: String) {
            guard !didFindCode else { return }
            didFindCode = true
            DispatchQueue.main.async {
                self.completion(.success(code))
            }
        }

        func didFailWithError(error: MLKitScannerViewController.ScannerError) {
            guard !didFindCode else { return }
            didFindCode = true
            DispatchQueue.main.async {
                self.completion(.failure(error))
            }
        }
    }
}

// MARK: - Controller & Camera Logic

protocol MLKitScannerDelegate: AnyObject {
    func didDetectBarcode(code: String)
    func didFailWithError(error: MLKitScannerViewController.ScannerError)
}

class MLKitScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    
    enum ScannerError: Error {
        case notAuthorized
        case inputDeviceError
        case sessionFailed
    }

    weak var delegate: MLKitScannerDelegate?
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var barcodeScanner: BarcodeScanner = {
        let options = BarcodeScannerOptions(formats: [.all])
        return BarcodeScanner.barcodeScanner(options: options)
    }()
    
    private var isProcessingFrame = false
    private var isSessionConfigured = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionsAndSetup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if isSessionConfigured && !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if captureSession.isRunning {
            captureSession.stopRunning()
        }
    }

    private func checkPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted { self?.setupSession() }
                else { self?.delegate?.didFailWithError(error: .notAuthorized) }
            }
        default:
            delegate?.didFailWithError(error: .notAuthorized)
        }
    }

    private func setupSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            self.captureSession.sessionPreset = .hd1280x720

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.captureSession.canAddInput(input) else {
                self.captureSession.commitConfiguration()
                self.delegate?.didFailWithError(error: .inputDeviceError)
                return
            }
            
            try? camera.lockForConfiguration()
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            camera.unlockForConfiguration()
            
            self.captureSession.addInput(input)

            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing"))

            guard self.captureSession.canAddOutput(videoOutput) else {
                self.captureSession.commitConfiguration()
                self.delegate?.didFailWithError(error: .sessionFailed)
                return
            }
            self.captureSession.addOutput(videoOutput)

            self.captureSession.commitConfiguration()
            self.isSessionConfigured = true

            DispatchQueue.main.async {
                self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                self.previewLayer.videoGravity = .resizeAspectFill
                self.previewLayer.frame = self.view.bounds
                self.view.layer.addSublayer(self.previewLayer)
            }

            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
            }
        }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard !isProcessingFrame else { return }
        isProcessingFrame = true

        let image = VisionImage(buffer: sampleBuffer)
        image.orientation = imageOrientation(deviceOrientation: UIDevice.current.orientation, cameraPosition: .back)

        barcodeScanner.process(image) { [weak self] barcodes, error in
            defer { self?.isProcessingFrame = false }
            
            guard error == nil, let barcodes = barcodes, !barcodes.isEmpty else { return }
            
            if let firstBarcode = barcodes.first, let rawValue = firstBarcode.rawValue {
                self?.delegate?.didDetectBarcode(code: rawValue)
            }
        }
    }

    private func imageOrientation(deviceOrientation: UIDeviceOrientation, cameraPosition: AVCaptureDevice.Position) -> UIImage.Orientation {
        switch deviceOrientation {
        case .portrait: return .right
        case .landscapeLeft: return .up
        case .landscapeRight: return .down
        case .portraitUpsideDown: return .left
        default: return .right
        }
    }
}
