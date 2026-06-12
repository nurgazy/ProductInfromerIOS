import Foundation
import UIKit

class AppUpdateManager {
    static let shared = AppUpdateManager()
    
    // Замените НА_ВАШ_APP_ID на реальный ID вашего приложения из App Store Connect
    private let appId = "6754254137"
    
    func checkForUpdate(completion: @escaping (Bool, URL?) -> Void) {
        // Получаем текущую версию приложения из Info.plist
        guard let info = Bundle.main.infoDictionary,
              let currentVersion = info["CFBundleShortVersionString"] as? String,
              let url = URL(string: "https://itunes.apple.com/lookup?id=\(appId)") else {
            completion(false, nil)
            return
        }
        
        // Запрос к API App Store
        URLSession.shared.dataTask(with: url) { data, _, error in
            guard let data = data, error == nil else {
                completion(false, nil)
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let results = json["results"] as? [[String: Any]],
                   let appStoreVersion = results.first?["version"] as? String {
                    
                    // Сравниваем версии (оптимизировано под текстовое сравнение "1.0.0")
                    let hasUpdate = appStoreVersion.compare(currentVersion, options: .numeric) == .orderedDescending
                    let appStoreUrl = URL(string: "itms-apps://itunes.apple.com/app/id\(self.appId)")
                    
                    DispatchQueue.main.async {
                        completion(hasUpdate, appStoreUrl)
                    }
                } else {
                    completion(false, nil)
                }
            } catch {
                completion(false, nil)
            }
        }.resume()
    }
}
