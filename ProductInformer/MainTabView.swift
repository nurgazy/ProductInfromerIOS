import SwiftUI

struct MainTabView: View {
    // Состояния для координации навигации (из вашего SettingsViewModel)
    @State private var selectedTab: Int = 0
    @Binding var coordinatorPath: NavigationPath?
    
    @State private var isUpdateAvailable = false
    @State private var appStoreURL: URL? = nil
    
    var body: some View {
        TabView(selection: $selectedTab) {
            BarcodeInputView(coordinatorPath: $coordinatorPath)
            .tabItem {
                Label("Поиск", systemImage: "magnifyingglass")
            }
            .tag(0)
            
            BarcodeListScreen(coordinatorPath: $coordinatorPath)
            .tabItem {
                Label("Сбор", systemImage: "barcode.viewfinder")
            }
            .tag(1)
            
        }
        .accentColor(.blue)
        .navigationTitle(selectedTab == 0 ? "Ввод штрихкода" : "Список документов")
        .navigationBarTitleDisplayMode(.inline)
        .alert(isPresented: $isUpdateAvailable) {
            Alert(
                title: Text("Доступно обновление"),
                message: Text("Пожалуйста, обновите приложение до последней версии для стабильной работы и новых функций."),
                primaryButton: .default(Text("Обновить"), action: {
                    openAppStore()
                }),
                secondaryButton: .cancel(Text("Позже"))
            )
        }
        // Проверяем наличие обновлений при парсинге/запуске этого экрана
        .onAppear {
            checkAppVersion()
        }
    }
    
    private func checkAppVersion() {
        AppUpdateManager.shared.checkForUpdate { hasUpdate, url in
            self.isUpdateAvailable = hasUpdate
            self.appStoreURL = url
        }
    }
    
    // Функция открытия App Store
    private func openAppStore() {
        if let url = appStoreURL, UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
