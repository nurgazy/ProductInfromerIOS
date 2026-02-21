import SwiftUI

struct MainTabView: View {
    // Состояния для координации навигации (из вашего SettingsViewModel)
    @State private var selectedTab: Int = 0
    @Binding var coordinatorPath: NavigationPath?
    
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
    }
}
