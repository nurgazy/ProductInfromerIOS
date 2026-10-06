import Foundation
import SwiftUI
import Combine
import KeychainAccess

final class BarcodeInputViewModel: ObservableObject {
    
    @Published var isSearching: Bool = false
    @Published var isActiveLink: Bool = false
    @Published var productDetailJSONString: String? = nil
    
    @Published var barcode: String = ""
    @Published var isScanning: Bool = false
    @Published var scannedCode: String? = nil
    @Published var statusMessage: String = ""
    
    @Published var showingAlert: Bool = false
    @Published var alertMessage: String = ""
    
    private var connectionSettings: ConnectionSettings
    private var coordinatorPath: Binding<NavigationPath?>
    
    init(coordinatorPath: Binding<NavigationPath?>) {
        self.coordinatorPath = coordinatorPath
        self.connectionSettings = BarcodeInputViewModel.loadConnectionSettings()
    }
    
    private static func loadConnectionSettings() -> ConnectionSettings {
        let defaults = UserDefaults.standard
        let keychain = Keychain(service: Bundle.main.bundleIdentifier ?? "com.productinformer.keys")
        
        let protocolSelection = defaults.string(forKey: AppSettingKey.protocolSelection) ?? "HTTPS"
        let serverAddress = defaults.string(forKey: AppSettingKey.serverAddress) ?? ""
        let savedPort = defaults.integer(forKey: AppSettingKey.port)
        let port = savedPort > 0 ? savedPort : 443
        let publicationName = defaults.string(forKey: AppSettingKey.publicationName) ?? ""
        let username = defaults.string(forKey: AppSettingKey.username) ?? ""
        let password = keychain[AppSettingKey.password] ?? ""
        let isFullSpecific = defaults.bool(forKey: AppSettingKey.isFullSpecific)
        let isCyclicScan = defaults.bool(forKey: AppSettingKey.isCyclicScanning)
        
        return ConnectionSettings(
            protocolSelection: protocolSelection,
            serverAddress: serverAddress,
            port: port,
            publicationName: publicationName,
            username: username,
            password: password,
            isFullSpecific: isFullSpecific,
            isCyclicScan: isCyclicScan
        )
    }
    
    // Логика обработки результата со сканера
    func handleScanResult(result: Result<String, MLKitScannerViewController.ScannerError>) {
        guard !isSearching else { return }
        
        // Закрываем окно сканера
        self.isScanning = false
        
        switch result {
        case .success(let code):
            self.barcode = code
            // Ждем завершения анимации закрытия sheet перед стартом запроса и перехода
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.findProduct()
            }
            
        case .failure(let error):
            let message: String
            switch error {
            case .barcodeNotFound:
                message = "Штрихкод не распознан. Попробуйте навести камеру ровнее и ближе."
            case .notAuthorized:
                message = "Нет доступа к камере. Включите разрешение в Настройках."
            case .inputDeviceError, .sessionFailed:
                message = "Ошибка камеры: \(error.localizedDescription)"
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.alertMessage = message
                self?.showingAlert = true
            }
        }
    }
    
    // Логика кнопки "Найти"
    func findProduct() {
        guard !isSearching else { return }
        
        guard !barcode.isEmpty else {
            self.alertMessage = "❌ Введите или отсканируйте штрихкод."
            self.showingAlert = true
            return
        }
        
        guard let url = buildSearchURL(barcode: barcode) else {
            self.alertMessage = "❌ Невозможно построить корректный URL."
            self.showingAlert = true
            return
        }
        
        self.statusMessage = "🔍 Поиск продукта \(barcode) на сервере..."
        
        // 1. Создание запроса с аутентификацией
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let authString = "\(connectionSettings.username):\(connectionSettings.password)"
        if let data = authString.data(using: .utf8) {
            let base64Auth = data.base64EncodedString()
            request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }
        
        // 2. Выполнение асинхронного запроса
        Task {
            await MainActor.run {
                self.isSearching = true
                self.showingAlert = false
                self.alertMessage = ""
            }
            
            defer {
                Task { @MainActor in self.isSearching = false }
            }

            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                guard let jsonString = String(data: data, encoding: .utf8) else {
                    await MainActor.run {
                        self.alertMessage = "❌ Ошибка: Не удалось прочитать ответ сервера как текст."
                        self.showingAlert = true
                    }
                    return
                }
                
                await MainActor.run {
                    if httpResponse.statusCode == 200 {
                        if let jsonData = jsonString.data(using: .utf8) {
                            do {
                                let decoder = JSONDecoder()
                                let productResponse = try decoder.decode(ProductResponse.self, from: jsonData)
                                if !productResponse.result {
                                    self.alertMessage = "Товар не найден."
                                    self.showingAlert = true
                                }
                            } catch {
                                self.alertMessage = "❌ Ошибка декодирования: \(error.localizedDescription)"
                                self.showingAlert = true
                            }
                        } else {
                            self.alertMessage = "Не удалось преобразовать данные."
                            self.showingAlert = true
                        }
                        
                        if self.showingAlert { return }
                        self.navigateToProductDetail(productString: jsonString)
                        
                    } else if httpResponse.statusCode == 401 {
                        self.alertMessage = "❌ Ошибка 401: Неверный пользователь/пароль. Проверьте настройки подключения."
                        self.showingAlert = true
                    } else {
                        self.alertMessage = "⚠️ Ошибка сервера: Код \(httpResponse.statusCode). Ответ: \(jsonString.prefix(100))..."
                        self.showingAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "❌ Ошибка сети: Не удалось подключиться к \(self.connectionSettings.serverAddress). Причина: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func buildSearchURL(barcode: String) -> URL? {
        let basePath = "/hs/ProductInformation/Info"
        
        var components = URLComponents()
        components.scheme = connectionSettings.protocolSelection.lowercased()
        components.host = connectionSettings.serverAddress
        components.port = connectionSettings.port
        components.path = "/\(connectionSettings.publicationName)\(basePath)"
        
        var queryItems = [
            URLQueryItem(name: "barcode", value: barcode)
        ]

        queryItems.append(
            URLQueryItem(name: "full", value: connectionSettings.isFullSpecific ? "true" : "false")
        )

        components.queryItems = queryItems
        return components.url
    }
    
    private func navigateToProductDetail(productString: String) {
        Task { @MainActor in
            self.productDetailJSONString = productString
            
            if #available(iOS 16.0, *) {
                if coordinatorPath.wrappedValue != nil {
                    let target = AppNavigationTarget(destinationID: "productDetail", productString: productString)
                    coordinatorPath.wrappedValue?.append(AppNavigation.view(target))
                }
            } else {
                isActiveLink = true
            }
        }
    }
}
