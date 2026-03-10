import Foundation
import SwiftUI
import KeychainAccess

final class SettingsViewModel: ObservableObject {

    @Published var protocolSelection: String = "HTTPS"
    @Published var serverAddress: String = ""
    @Published var port: Int = 80
    @Published var publicationName: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var isCyclicScanning: Bool = false
    
    @Published var isFullSpecific: Bool = false
    
    // Состояние для iOS 15- (управляется кодом)
    @Published var isActiveLink: Bool = false
    // Путь навигации для iOS 16+ (управляется кодом)
    @Published var navigationPath = [AppNavigation]()
    
    @Published var connectionStatus: String = "Ожидание проверки..."
    @Published var isChecking: Bool = false
    
    @Published var showingAlert: Bool = false
    @Published var alertMessage: String = ""
    @Published var alertTitle: String = ""
    
    let protocols = ["HTTP", "HTTPS"]
    
    private let keychain = Keychain(service: Bundle.main.bundleIdentifier ?? "ProductInformer.settings")
    
    private var coordinatorPath: Binding<NavigationPath?>
    @Binding private var currentRoot: String
    
    init(coordinatorPath: Binding<NavigationPath?>, currentRoot: Binding<String>) {
        self.coordinatorPath = coordinatorPath
        self._currentRoot = currentRoot
        loadSettings()
    }
    
    func loadSettings() {
        let defaults = UserDefaults.standard
        
        self.protocolSelection = defaults.string(forKey: AppSettingKey.protocolSelection) ?? "HTTPS"
        self.serverAddress = defaults.string(forKey: AppSettingKey.serverAddress) ?? ""
        let savedPort = defaults.integer(forKey: AppSettingKey.port)
        self.port = savedPort > 0 ? savedPort : 443
        self.publicationName = defaults.string(forKey: AppSettingKey.publicationName) ?? ""
        self.username = defaults.string(forKey: AppSettingKey.username) ?? ""
        self.password = keychain[AppSettingKey.password] ?? ""
        self.isFullSpecific = defaults.bool(forKey: AppSettingKey.isFullSpecific)
        self.isCyclicScanning = defaults.bool(forKey: AppSettingKey.isCyclicScanning)
    }
    
    func handleProtocolChange(newProtocol: String) {
        if newProtocol == "HTTPS" {
            self.port = 443
        } else {
            self.port = 80
        }
    }
    
    func saveAndNavigate() {
        saveSettings()
        
        currentRoot = "barcodeInput"
        if #available(iOS 16.0, *) {
            coordinatorPath.wrappedValue = NavigationPath()
        } else {
            isActiveLink = true
        }
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        
        defaults.set(self.protocolSelection, forKey: AppSettingKey.protocolSelection)
        defaults.set(self.serverAddress, forKey: AppSettingKey.serverAddress)
        defaults.set(self.port, forKey: AppSettingKey.port) // Сохраняем Int напрямую
        defaults.set(self.publicationName, forKey: AppSettingKey.publicationName)
        defaults.set(self.username, forKey: AppSettingKey.username)
        if self.password.isEmpty {
            try? keychain.remove(AppSettingKey.password)
        } else {
            keychain[AppSettingKey.password] = self.password
        }
        
        defaults.set(self.isFullSpecific, forKey: AppSettingKey.isFullSpecific)
        defaults.set(self.isCyclicScanning, forKey: AppSettingKey.isCyclicScanning)
    }
    
    func checkConnection() {
        Task { @MainActor in
            self.isChecking = true
            self.connectionStatus = "Подключение..."
        }

        // 1. Формирование URL
        guard let url = buildCheckURL() else {
            Task { @MainActor in
                self.connectionStatus = "Ошибка: Неверный URL."
                self.isChecking = false
            }
            return
        }

        // 2. Создание запроса
        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let authString = "\(username):\(password)"
        if let data = authString.data(using: .utf8) {
            let base64Auth = data.base64EncodedString()
            request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }

        // 4. Выполнение асинхронного запроса
        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                // Обновление UI должно происходить в главном потоке
                await MainActor.run {
                    self.isChecking = false
                    
                    if httpResponse.statusCode == 200 {
                        // Успех, 1С вернула OK
                        //self.connectionStatus = "✅ Соединение установлено! (Код 200)"
                        self.alertTitle = "Успех!"
                        self.alertMessage = "✅ Соединение установлено!"
                    } else if httpResponse.statusCode == 401 {
                        // Ошибка аутентификации
                        //self.connectionStatus = "❌ Ошибка: Неверный пользователь/пароль (Код 401)"
                        self.alertTitle = "Ошибка!"
                        self.alertMessage = "❌ Ошибка: Неверный пользователь/пароль"
                    } else {
                        // Другие ошибки сервера
                        let responseBody = String(data: data, encoding: .utf8) ?? "Нет данных"
                        //self.connectionStatus = "⚠️ Ошибка сервера: Код \(httpResponse.statusCode). Ответ: \(responseBody.prefix(50))..."
                        self.alertTitle = "Ошибка!"
                        self.alertMessage = "⚠️ Ошибка сервера: Код \(httpResponse.statusCode). Ответ: \(responseBody.prefix(50))..."
                    }
                    self.showingAlert = true
                }
            } catch {
                // Ошибка сети (нет интернета, таймаут, неверный домен)
                await MainActor.run {
                    self.isChecking = false
                    //self.connectionStatus = "❌ Ошибка сети: \(error.localizedDescription)"
                    self.alertTitle = "Ошибка Сети"
                    self.alertMessage = "Не удалось подключиться к серверу. Проверьте интернет или адрес."
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func buildCheckURL() -> URL? {
        
        let path = "/\(publicationName)/hs/ProductInformation/Ping"
        
        var components = URLComponents()
        components.scheme = protocolSelection.lowercased()
        components.host = serverAddress
        
        if port > 0 {
            components.port = port
        }
        
        if !serverAddress.isEmpty {
            components.path = path
        }
        
        return components.url
    }
}
