import SwiftUI
import AVFoundation
import MLKitBarcodeScanning
import MLKitVision

struct MLKitScannerView: View {
    typealias ResultHandler = (Result<String, MLKitScannerViewController.ScannerError>) -> Void
    var completion: ResultHandler
    
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        GeometryReader { geometry in
            let frameWidth = geometry.size.width - 32
            let frameHeight: CGFloat = 200
            let frameRect = CGRect(
                x: 16,
                y: (geometry.size.height - frameHeight) / 2,
                width: frameWidth,
                height: frameHeight
            )

            ZStack {
                // Передаем координаты рамки прямо в контроллер для фильтрации зоны ROI
                MLKitScannerRepresentable(scanAreaRect: frameRect, completion: completion)
                    .ignoresSafeArea()

                // Визуальный оверлей с рамкой
                ScannerOverlayView(scanRect: frameRect)

                // Кнопка закрытия
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
}

// Визуальная рамка с прозрачным окном
private struct ScannerOverlayView: View {
    let scanRect: CGRect

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .mask(
                    CutoutShape(rect: scanRect)
                        .fill(style: FillStyle(eoFill: true))
                )

            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.white, lineWidth: 3)
                .frame(width: scanRect.width, height: scanRect.height)
                .position(x: scanRect.midX, y: scanRect.midY)
                .shadow(color: .black.opacity(0.4), radius: 5)
        }
        .ignoresSafeArea()
    }
}

private struct CutoutShape: Shape {
    let rect: CGRect

    func path(in fullBounds: CGRect) -> Path {
        var path = Path()
        path.addRect(fullBounds)
        path.addRoundedRect(in: rect, cornerSize: CGSize(width: 16, height: 16))
        return path
    }
}

// Representable-обертка с передачей scanAreaRect
struct MLKitScannerRepresentable: UIViewControllerRepresentable {
    typealias ResultHandler = (Result<String, MLKitScannerViewController.ScannerError>) -> Void
    var scanAreaRect: CGRect
    var completion: ResultHandler

    func makeUIViewController(context: Context) -> MLKitScannerViewController {
        let viewController = MLKitScannerViewController()
        viewController.scanAreaInView = scanAreaRect
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(_ uiViewController: MLKitScannerViewController, context: Context) {
        uiViewController.scanAreaInView = scanAreaRect
    }

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
    var scanAreaInView: CGRect = .zero
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var barcodeScanner: BarcodeScanner = {
        let options = BarcodeScannerOptions(formats: [.all])
        return BarcodeScanner.barcodeScanner(options: options)
    }()
    
    private var isProcessingFrame = false
    private var isSessionConfigured = false
    private var hasDetectedBarcode = false
    
    // Защита от моментального срабатывания: сканер начинает считывать только через 0.6 сек
    private var canDetectBarcodes = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionsAndSetup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        hasDetectedBarcode = false
        canDetectBarcodes = false
        
        // Даем пользователю 0.6 секунды на прицеливание
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { [weak self] in
            self?.canDetectBarcodes = true
        }

        if isSessionConfigured && !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.captureSession.startRunning()
            }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        canDetectBarcodes = false
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
        // Игнорируем кадры, если еще идет стартовая пауза или штрихкод уже считан
        guard canDetectBarcodes, !hasDetectedBarcode, !isProcessingFrame else { return }
        isProcessingFrame = true

        let image = VisionImage(buffer: sampleBuffer)
        image.orientation = imageOrientation(deviceOrientation: UIDevice.current.orientation, cameraPosition: .back)

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessingFrame = false
            return
        }
        
        let bufferWidth = CGFloat(CVPixelBufferGetWidth(imageBuffer))
        let bufferHeight = CGFloat(CVPixelBufferGetHeight(imageBuffer))

        barcodeScanner.process(image) { [weak self] barcodes, error in
            guard let self = self else { return }
            defer { self.isProcessingFrame = false }
            
            guard self.canDetectBarcodes, !self.hasDetectedBarcode else { return }
            guard error == nil, let barcodes = barcodes, !barcodes.isEmpty else { return }
            
            // Фильтруем штрихкоды: берем только те, центр которых находится строго внутри рамки
            for barcode in barcodes {
                guard let rawValue = barcode.rawValue else { continue }
                
                let barcodeCenterInView = self.convertPointToViewCoordinates(
                    point: CGPoint(x: barcode.frame.midX, y: barcode.frame.midY),
                    bufferWidth: bufferWidth,
                    bufferHeight: bufferHeight
                )
                
                // Проверяем попадание центра штрихкода в прямоугольник рамки
                if self.scanAreaInView.contains(barcodeCenterInView) {
                    self.hasDetectedBarcode = true
                    self.canDetectBarcodes = false
                    self.captureSession.stopRunning()
                    self.delegate?.didDetectBarcode(code: rawValue)
                    break
                }
            }
        }
    }

    // Преобразование координат кадра камеры в систему координат экрана UI
    private func convertPointToViewCoordinates(point: CGPoint, bufferWidth: CGFloat, bufferHeight: CGFloat) -> CGPoint {
        // Для ориентации .portrait ширина и высота буфера инвертированы по отношению к экрану
        let normalizedPoint = CGPoint(x: point.y / bufferHeight, y: 1.0 - (point.x / bufferWidth))
        
        guard let preview = self.previewLayer else {
            return .zero
        }
        return preview.layerPointConverted(fromCaptureDevicePoint: normalizedPoint)
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
