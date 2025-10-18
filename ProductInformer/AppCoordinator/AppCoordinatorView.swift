import SwiftUI

extension Binding where Value == NavigationPath {
    var optionalized: Binding<NavigationPath?> {
        return Binding<NavigationPath?>(
            get: { self.wrappedValue },
            set: { self.wrappedValue = $0 ?? NavigationPath() }
        )
    }
}

struct AppCoordinatorView: View {
    
    @StateObject private var coordinator = AppCoordinatorViewModel()
    @StateObject private var menuState = MenuStateViewModel()
    
    var body: some View {
        ZStack(alignment: .leading) {
            if #available(iOS 16.0, *) {
                NavigationStack(path: $coordinator.navigationPath) {
                    
                    Group {
                        if coordinator.currentRoot == "barcodeInput" {
                            BarcodeInputView(coordinatorPath: $coordinator.navigationPath.optionalized)
                        }
                        else if coordinator.currentRoot == "settings" {
                            // SettingsView без возможности "Назад"
                            SettingsView(coordinatorPath: $coordinator.navigationPath.optionalized,
                                         currentRoot: $coordinator.currentRoot)
                        }
                    }
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button {
                                menuState.toggleMenu()
                            } label: {
                                Image(systemName: "line.horizontal.3")
                            }
                        }
                    }
                    
                    // Определяем все возможные точки назначения в AppNavigation
                    .navigationDestination(for: AppNavigation.self) { destination in
                        switch destination {
                        case .view(let target):
                            if target.destinationID == "barcodeInput"
                            {
                                BarcodeInputView(coordinatorPath: $coordinator.navigationPath.optionalized)
                            }
                            else if target.destinationID == "settings"
                            {
                                SettingsView(coordinatorPath: $coordinator.navigationPath.optionalized,
                                             currentRoot: $coordinator.currentRoot)
                            }
                            else if target.destinationID == "productDetail"
                            {
                                ProductDetailView(productString: target.productString)
                            }
                        }
                    }
                }
                
                .offset(x: menuState.isMenuShowing ? menuState.menuWidth : 0)
                // 2. Деактивируем взаимодействие
                .disabled(menuState.isMenuShowing)
                // 3. Добавляем анимацию
                .animation(.easeOut(duration: 0.3), value: menuState.isMenuShowing)
                // 4. Игнорируем безопасные области, чтобы контент полностью сдвигался
                .ignoresSafeArea(.all, edges: .leading)

            } else {
                // Для iOS 15- используем старый NavigationView
                NavigationView {
                    // На iOS 15- SettingsView управляет навигацией через isActiveLink
                    SettingsView(coordinatorPath: .constant(nil), currentRoot: $coordinator.currentRoot)
                }
            }
            
            CustomSideMenuView(
                menuState: menuState,
                coordinatorPath: $coordinator.navigationPath.optionalized,
                currentRoot: $coordinator.currentRoot
            )
            .frame(width: menuState.menuWidth, alignment: .leading)
            .offset(x: menuState.isMenuShowing ? 0 : -menuState.menuWidth)
            // This is critical for the "drawer" animation
            .animation(.easeOut(duration: 0.3), value: menuState.isMenuShowing)
        }
        
    }
}

#Preview {
    AppCoordinatorView()
}
