import SwiftUI
import AVFoundation // Требуется для операций с камерой
import UIKit // Требуется для UIViewController

// MARK: - CodeScannerView (Оболочка для нативного сканера)

/// Структура, оборачивающая нативный UIViewController (AVCaptureSession) для сканирования штрихкодов.
struct CodeScannerView: UIViewControllerRepresentable {
    
    // Стандартный обработчик результатов для сканера: Success (String) или Failure (Error)
    typealias ResultHandler = (Result<String, ScannerError>) -> Void
    var completion: ResultHandler
    
    // Определение типа ошибок
    enum ScannerError: Error {
        case simulatedError
        case notAuthorized // Ошибка доступа к камере
        case inputDeviceError
        case unableToStartSession // Не удалось запустить сессию захвата
        
        var localizedDescription: String {
            switch self {
            case .simulatedError: return "Сканирование прервано пользователем."
            case .notAuthorized: return "Доступ к камере запрещен. Разрешите его в настройках."
            case .inputDeviceError: return "Ошибка настройки камеры."
            case .unableToStartSession: return "Не удалось запустить камеру."
            }
        }
    }
    
    // MARK: UIViewControllerRepresentable methods
    
    func makeUIViewController(context: Context) -> ScannerViewController {
        let viewController = ScannerViewController()
        viewController.delegate = context.coordinator // Назначаем координатора делегатом
        return viewController
    }

    func updateUIViewController(_ uiViewController: ScannerViewController, context: Context) {
        // Обновление не требуется.
    }
    
    // MARK: Coordinator
    
    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }
    
    /// Координатор действует как мост между UIKit (камера) и SwiftUI
    class Coordinator: NSObject, ScannerViewControllerDelegate, AVCaptureMetadataOutputObjectsDelegate {
        var completion: ResultHandler
        var didScan = false // Флаг для предотвращения повторных сканирований

        init(completion: @escaping ResultHandler) {
            self.completion = completion
        }
        
        // MARK: - ScannerViewControllerDelegate
        
        func scannerDidFail(error: CodeScannerView.ScannerError) {
            // Убеждаемся, что completion вызывается только один раз
            guard !didScan else { return }
            didScan = true
            completion(.failure(error))
        }

        // MARK: - AVCaptureMetadataOutputObjectsDelegate
        
        func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
            
            // Если мы уже отсканировали код, игнорируем новые события
            guard !didScan else { return }
            
            if let metadataObject = metadataObjects.first {
                guard let readableObject = metadataObject as? AVMetadataMachineReadableCodeObject else { return }
                guard let stringValue = readableObject.stringValue else { return }
                
                // Проверяем, что это штрихкод (EAN-13, QR, etc.)
                if readableObject.type == .ean13 || readableObject.type == .qr {
                    // Успешное сканирование
                    didScan = true
                    // Отправляем результат обратно в SwiftUI
                    completion(.success(stringValue))
                }
            }
        }
    }
}

// MARK: - UIKit Implementation

/// Протокол для делегирования результатов сканирования
protocol ScannerViewControllerDelegate: AnyObject {
    func scannerDidFail(error: CodeScannerView.ScannerError)
}

/// UIViewController, который управляет реальной сессией камеры (AVCaptureSession)
class ScannerViewController: UIViewController {
    
    weak var delegate: ScannerViewControllerDelegate?
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        checkPermissionsAndSetup()
        addDismissButton()
    }
    
    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        // Обеспечиваем, что previewLayer заполняет весь экран при изменении ориентации
        previewLayer?.frame = view.layer.bounds
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // Начинаем сессию, если она не активна
        if (captureSession?.isRunning == false) {
            DispatchQueue.global(qos: .userInitiated).async {
                self.captureSession?.startRunning()
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Останавливаем сессию при закрытии представления
        if (captureSession?.isRunning == true) {
            captureSession?.stopRunning()
        }
    }
    
    // MARK: - Setup Logic

    private func checkPermissionsAndSetup() {
        // Проверяем статус доступа к камере
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            // Доступ есть, настраиваем сессию
            setupCaptureSession()
        case .notDetermined:
            // Запрашиваем доступ
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        self?.handleError(.notAuthorized)
                    }
                }
            }
        case .denied, .restricted:
            // Доступ запрещен
            handleError(.notAuthorized)
        @unknown default:
            handleError(.inputDeviceError)
        }
    }
    
    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        
        guard let videoCaptureDevice = AVCaptureDevice.default(for: .video) else {
            handleError(.inputDeviceError)
            return
        }
        
        let videoInput: AVCaptureDeviceInput
        
        do {
            videoInput = try AVCaptureDeviceInput(device: videoCaptureDevice)
        } catch {
            handleError(.inputDeviceError)
            return
        }
        
        guard captureSession!.canAddInput(videoInput) else {
            handleError(.inputDeviceError)
            return
        }
        captureSession!.addInput(videoInput)
        
        let metadataOutput = AVCaptureMetadataOutput()
        
        guard captureSession!.canAddOutput(metadataOutput) else {
            handleError(.inputDeviceError)
            return
        }
        captureSession!.addOutput(metadataOutput)
        
        // Настраиваем вывод для обработки метаданных
        metadataOutput.setMetadataObjectsDelegate(delegate as? AVCaptureMetadataOutputObjectsDelegate, queue: DispatchQueue.main)
        // Указываем, какие типы штрихкодов мы ищем (EAN-13 и QR как основные)
        metadataOutput.metadataObjectTypes = [.ean13, .qr, .code128, .ean8]
        
        // Настройка слоя предпросмотра
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        previewLayer.frame = view.layer.bounds
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        
        // Запускаем сессию
        DispatchQueue.global(qos: .userInitiated).async {
            self.captureSession?.startRunning()
        }
    }
    
    private func handleError(_ error: CodeScannerView.ScannerError) {
        // Останавливаем сессию на всякий случай
        captureSession?.stopRunning()
        
        // Отправляем ошибку обратно в SwiftUI, что закроет модальное окно и покажет alert
        delegate?.scannerDidFail(error: error)
        
        // Отображаем заглушку, если сессия не стартовала
        showErrorUI(message: error.localizedDescription)
    }
    
    private func showErrorUI(message: String) {
        let label = UILabel()
        label.text = "Ошибка камеры: \(message)"
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        view.subviews.forEach { $0.removeFromSuperview() } // Удаляем старые UI элементы
        view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
        ])
    }
    
    // MARK: - UI
    
    private func addDismissButton() {
        let dismissButton = UIButton(type: .system)
        dismissButton.setTitle("Отмена", for: .normal)
        dismissButton.setTitleColor(.white, for: .normal)
        dismissButton.backgroundColor = UIColor(white: 0, alpha: 0.5)
        dismissButton.layer.cornerRadius = 10
        dismissButton.contentEdgeInsets = UIEdgeInsets(top: 10, left: 20, bottom: 10, right: 20)
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.addTarget(self, action: #selector(dismissScanner), for: .touchUpInside)
        
        view.addSubview(dismissButton)
        
        NSLayoutConstraint.activate([
            dismissButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            dismissButton.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
    }

    @objc private func dismissScanner() {
        // Принудительное закрытие пользователем
        delegate?.scannerDidFail(error: .simulatedError)
    }
}
