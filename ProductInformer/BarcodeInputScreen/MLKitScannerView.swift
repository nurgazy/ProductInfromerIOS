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
        guard canDetectBarcodes, !hasDetectedBarcode, !isProcessingFrame else { return }
        isProcessingFrame = true

        guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            isProcessingFrame = false
            return
        }

        // Обрезаем буфер строго по области белой рамки
        guard let croppedImage = cropToScanArea(imageBuffer: imageBuffer) else {
            isProcessingFrame = false
            return
        }

        let visionImage = VisionImage(image: croppedImage)
        visionImage.orientation = .up // Изображение уже правильно ориентировано после обрезки

        barcodeScanner.process(visionImage) { [weak self] barcodes, error in
            guard let self = self else { return }
            defer { self.isProcessingFrame = false }
            
            guard self.canDetectBarcodes, !self.hasDetectedBarcode else { return }
            guard error == nil, let barcodes = barcodes, !barcodes.isEmpty else { return }
            
            if let firstBarcode = barcodes.first, let rawValue = firstBarcode.rawValue {
                self.hasDetectedBarcode = true
                self.canDetectBarcodes = false
                self.captureSession.stopRunning()
                self.delegate?.didDetectBarcode(code: rawValue)
            }
        }
    }

    // Вырезает из кадра камеры только то, что пользователь видит внутри белой рамки
    private func cropToScanArea(imageBuffer: CVImageBuffer) -> UIImage? {
        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        
        // Поворачиваем кадр камеры в портретную ориентацию
        let rotatedCIImage = ciImage.oriented(.right)
        
        guard let preview = self.previewLayer else { return nil }
        
        let viewBounds = preview.bounds
        guard viewBounds.width > 0, viewBounds.height > 0 else { return nil }
        
        let imageSize = rotatedCIImage.extent.size
        
        // Коэффициенты масштабирования видео под размер экрана (.resizeAspectFill)
        let scaleX = imageSize.width / viewBounds.width
        let scaleY = imageSize.height / viewBounds.height
        let scale = max(scaleX, scaleY)
        
        let scaledWidth = viewBounds.width * scale
        let scaledHeight = viewBounds.height * scale
        let offsetX = (scaledWidth - imageSize.width) / 2.0
        let offsetY = (scaledHeight - imageSize.height) / 2.0
        
        // Перевод координат рамки из экрана в координаты повернутого изображения
        // CIImage имеет начало координат (0,0) в левом нижнем углу
        let cropX = (scanAreaInView.origin.x * scale) - offsetX
        let cropY = imageSize.height - ((scanAreaInView.origin.y + scanAreaInView.height) * scale) + offsetY
        let cropWidth = scanAreaInView.width * scale
        let cropHeight = scanAreaInView.height * scale
        
        let cropRect = CGRect(x: max(0, cropX), y: max(0, cropY), width: cropWidth, height: cropHeight)
        
        guard cropRect.width > 0, cropRect.height > 0 else { return nil }
        
        let croppedCI = rotatedCIImage.cropped(to: cropRect)
        let context = CIContext(options: nil)
        guard let cgImage = context.createCGImage(croppedCI, from: croppedCI.extent) else { return nil }
        
        return UIImage(cgImage: cgImage)
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
