import SwiftUI
import AVFoundation
import MLKitBarcodeScanning
import MLKitVision

struct MLKitScannerView: UIViewControllerRepresentable {
    typealias ResultHandler = (Result<String, ScannerError>) -> Void
    var completion: ResultHandler
    
    enum ScannerError: Error {
        case notAuthorized
        case inputDeviceError
        case sessionFailed
    }

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

        func didFailWithError(error: ScannerError) {
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
    func didFailWithError(error: MLKitScannerView.ScannerError)
}

class MLKitScannerViewController: UIViewController, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var delegate: MLKitScannerDelegate?
    
    private let captureSession = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer!
    private lazy var barcodeScanner: BarcodeScanner = {
        // Выбираем формат сканирования (EAN-13, EAN-8, QR и т.д.)
        let options = BarcodeScannerOptions(formats: [.all])
        return BarcodeScanner.barcodeScanner(options: options)
    }()
    
    private var isProcessingFrame = false // Флаг для пропуска кадров при высокой нагрузке

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
        if !captureSession.isRunning {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession.startRunning()
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
            self.captureSession.sessionPreset = .hd1280x720 // Оптимально для быстрой обработки ML Kit

            guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let input = try? AVCaptureDeviceInput(device: camera),
                  self.captureSession.canAddInput(input) else {
                self.delegate?.didFailWithError(error: .inputDeviceError)
                return
            }
            
            // Настройка автофокуса
            try? camera.lockForConfiguration()
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            camera.unlockForConfiguration()
            
            self.captureSession.addInput(input)

            // Вывод кадров для ML Kit
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.alwaysDiscardsLateVideoFrames = true
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "camera.frame.processing"))

            guard self.captureSession.canAddOutput(videoOutput) else {
                self.delegate?.didFailWithError(error: .sessionFailed)
                return
            }
            self.captureSession.addOutput(videoOutput)
            self.captureSession.commitConfiguration()

            DispatchQueue.main.async {
                self.previewLayer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                self.previewLayer.videoGravity = .resizeAspectFill
                self.previewLayer.frame = self.view.bounds
                self.view.layer.addSublayer(self.previewLayer)
                
                self.captureSession.startRunning()
            }
        }
    }

    // MARK: - Обработка каждого кадра через ML Kit
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        // Если предыдущий кадр еще распознается — пробиваем текущий для экономии CPU
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
