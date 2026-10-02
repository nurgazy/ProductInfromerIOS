import Foundation
import SwiftUI
import KeychainAccess

final class SettingsViewModel: ObservableObject {

    @Published var protocolSelection: String = "HTTPS"
    @Published var serverAddress: String = ""
    @Published var port: Int = 80
    @Published var publicationName: String = ""
    @Published var username: String = ""
    
    // Хранит реальный пароль из Keychain (не показывается в UI)
    private var storedPassword: String = ""
    // Поле ввода нового пароля
    @Published var newPasswordInput: String = ""
    // Флаг: сохранен ли уже пароль в Keychain
    @Published var hasSavedPassword: Bool = false
    
    @Published var isCyclicScanning: Bool = false
    @Published var isFullSpecific: Bool = false
    
    // Плейсхолдер фиксированной длины (8 точек), скрывающий реальное количество символов
    let dummyMask = "••••••••"
    
    @Published var isActiveLink: Bool = false
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
    
    // Эффективный пароль для сетевых запросов
    var currentPassword: String {
        if !newPasswordInput.isEmpty {
            return newPasswordInput
        }
        return storedPassword
    }
    
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
        
        let loadedPassword = keychain[AppSettingKey.password] ?? ""
        self.storedPassword = loadedPassword
        self.hasSavedPassword = !loadedPassword.isEmpty
        self.newPasswordInput = ""
        
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
        defaults.set(self.port, forKey: AppSettingKey.port)
        defaults.set(self.publicationName, forKey: AppSettingKey.publicationName)
        defaults.set(self.username, forKey: AppSettingKey.username)
        
        // Если пользователь ввел новый пароль — сохраняем его в Keychain
        if !newPasswordInput.isEmpty {
            keychain[AppSettingKey.password] = newPasswordInput
            self.storedPassword = newPasswordInput
            self.hasSavedPassword = true
            self.newPasswordInput = ""
        }
        
        defaults.set(self.isFullSpecific, forKey: AppSettingKey.isFullSpecific)
        defaults.set(self.isCyclicScanning, forKey: AppSettingKey.isCyclicScanning)
    }
    
    func clearSavedPassword() {
        try? keychain.remove(AppSettingKey.password)
        self.storedPassword = ""
        self.hasSavedPassword = false
        self.newPasswordInput = ""
    }
    
    func checkConnection() {
        Task { @MainActor in
            self.isChecking = true
            self.connectionStatus = "Подключение..."
        }

        guard let url = buildCheckURL() else {
            Task { @MainActor in
                self.connectionStatus = "Ошибка: Неверный URL."
                self.isChecking = false
            }
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let authString = "\(username):\(currentPassword)"
        if let data = authString.data(using: .utf8) {
            let base64Auth = data.base64EncodedString()
            request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                await MainActor.run {
                    self.isChecking = false
                    
                    if httpResponse.statusCode == 200 {
                        self.alertTitle = "Успех!"
                        self.alertMessage = "✅ Соединение установлено!"
                    } else if httpResponse.statusCode == 401 {
                        self.alertTitle = "Ошибка!"
                        self.alertMessage = "❌ Ошибка: Неверный пользователь/пароль"
                    } else {
                        let responseBody = String(data: data, encoding: .utf8) ?? "Нет данных"
                        self.alertTitle = "Ошибка!"
                        self.alertMessage = "⚠️ Ошибка сервера: Код \(httpResponse.statusCode). Ответ: \(responseBody.prefix(50))..."
                    }
                    self.showingAlert = true
                }
            } catch {
                await MainActor.run {
                    self.isChecking = false
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
