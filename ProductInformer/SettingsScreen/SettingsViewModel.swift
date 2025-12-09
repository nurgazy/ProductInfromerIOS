import Foundation
import SwiftUI
import SwiftKeychainWrapper

struct SettingKeys {
    static let protocolSelection = "protocolSelectionKey"
    static let serverAddress = "serverAddressKey"
    static let port = "portKey"
    static let publicationName = "publicationNameKey"
    static let username = "usernameKey"
    static let password = "passwordKey"
    static let isFullSpecific = "isFullSpecificKey"
}


// ViewModel для управления настройками и переходами
final class SettingsViewModel: ObservableObject {
    
    // @Published автоматически оповещает View об изменениях
    @Published var protocolSelection: String = "HTTPS"
    @Published var serverAddress: String = ""
    @Published var port: Int = 80
    @Published var publicationName: String = ""
    @Published var username: String = ""
    @Published var password: String = ""
    
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
    
    private var coordinatorPath: Binding<NavigationPath?>
    @Binding private var currentRoot: String
    
    init(coordinatorPath: Binding<NavigationPath?>, currentRoot: Binding<String>) {
        self.coordinatorPath = coordinatorPath
        self._currentRoot = currentRoot
        loadSettings()
    }
    
    func loadSettings() {
        let defaults = UserDefaults.standard
        
        // 1. Протокол (String)
        self.protocolSelection = defaults.string(forKey: SettingKeys.protocolSelection) ?? "HTTPS"
        
        // 2. Адрес сервера (String)
        self.serverAddress = defaults.string(forKey: SettingKeys.serverAddress) ?? ""
        
        // 3. Порт (Int - загружаем как Int, предоставляя дефолт 80)
        // .integer(forKey:) возвращает 0, если ключ не найден, поэтому нужна проверка
        let savedPort = defaults.integer(forKey: SettingKeys.port)
        self.port = savedPort > 0 ? savedPort : 443
        
        // 4. Имя публикации (String)
        self.publicationName = defaults.string(forKey: SettingKeys.publicationName) ?? ""
        
        // 5. Имя пользователя (String)
        self.username = defaults.string(forKey: SettingKeys.username) ?? ""
        self.password = KeychainWrapper.standard.string(forKey: SettingKeys.password) ?? ""
        
        self.isFullSpecific = defaults.bool(forKey: SettingKeys.isFullSpecific)
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
        // Условная логика навигации
        if #available(iOS 16.0, *) {
            coordinatorPath.wrappedValue = NavigationPath()
//            let target = AppNavigationTarget(destinationID: "barcodeInput", productString: "")
//            coordinatorPath.wrappedValue?.append(AppNavigation.view(target))
        } else {
            isActiveLink = true
        }
    }
    
    func saveSettings() {
        let defaults = UserDefaults.standard
        
        defaults.set(self.protocolSelection, forKey: SettingKeys.protocolSelection)
        defaults.set(self.serverAddress, forKey: SettingKeys.serverAddress)
        defaults.set(self.port, forKey: SettingKeys.port) // Сохраняем Int напрямую
        defaults.set(self.publicationName, forKey: SettingKeys.publicationName)
        defaults.set(self.username, forKey: SettingKeys.username)
        if self.password.isEmpty {
            // Если пароль пуст, удаляем старый из Keychain
            KeychainWrapper.standard.removeObject(forKey: SettingKeys.password)
        } else {
            // Сохраняем пароль. Результат (Bool) можно проверить, но обычно это не требуется.
            let _ = KeychainWrapper.standard.set(self.password, forKey: SettingKeys.password)
        }
        
        defaults.set(self.isFullSpecific, forKey: SettingKeys.isFullSpecific)
    }
    
    func checkConnection() {
        // Устанавливаем индикатор загрузки и сбрасываем статус
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
        
        // 3. Basic Authentication (имя пользователя:пароль -> Base64)
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
