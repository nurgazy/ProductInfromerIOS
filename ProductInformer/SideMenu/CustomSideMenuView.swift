import SwiftUI

struct CustomSideMenuView: View {
    
    // Принимает состояние меню
    @ObservedObject var menuState: MenuStateViewModel
    
    // Привязка для навигации в корневом координаторе
    @Binding var coordinatorPath: NavigationPath?
    @Binding var currentRoot: String
    
    var body: some View {
        ZStack(alignment: .leading) {
            
            // Полупрозрачный фон-оверлей
            if menuState.isMenuShowing {
                Color.black.opacity(0.4)
                    .edgesIgnoringSafeArea(.all)
                    // Закрытие меню по тапу на оверлей
                    .onTapGesture {
                        menuState.toggleMenu()
                    }
            }
            
            // Основное меню
            HStack {
                VStack(alignment: .leading) {
                    Text("Меню")
                        .font(.largeTitle)
                        .padding(.top, 60)
                        .padding(.bottom, 20)
                        .padding(.leading)

                    // 1. Ссылка на Настройки
                    MenuLink(
                        title: "Настройки",
                        icon: "gear",
                        targetID: "settings",
                        menuState: menuState,
                        coordinatorPath: $coordinatorPath,
                        currentRoot: $currentRoot
                    )
                    
                    Spacer()
                }
                .frame(width: menuState.menuWidth)
                .background(Color(UIColor.systemBackground))
                
                Spacer() // Занимает оставшуюся часть экрана
            }
            
            // Смещение меню для анимации выезда
            .offset(x: menuState.isMenuShowing ? 0 : -menuState.menuWidth)
            .animation(.easeOut(duration: 0.3), value: menuState.isMenuShowing)
        }
    }
}

// Вспомогательная структура для кнопок меню
struct MenuLink: View {
    let title: String
    let icon: String
    let targetID: String
    
    @ObservedObject var menuState: MenuStateViewModel
    @Binding var coordinatorPath: NavigationPath?
    @Binding var currentRoot: String
    
    var body: some View {
        Button {
            menuState.toggleMenu()

            let target = AppNavigationTarget(destinationID: targetID, productString: "")
            if #available(iOS 16.0, *) {
                if targetID == "settings" || targetID == "barcodeInput" {
                    currentRoot = targetID // 'settings'
                    coordinatorPath = NavigationPath() // Убеждаемся, что нет других элементов
                } else {
                    // Для всех остальных (некорневых) переходов:
                    let target = AppNavigationTarget(destinationID: targetID, productString: "")
                    if #available(iOS 16.0, *) {
                        coordinatorPath?.append(AppNavigation.view(target))
                    }
                }
            }
            
        } label: {
            HStack {
                Image(systemName: icon)
                    .imageScale(.large)
                    .frame(width: 32)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            .padding(.vertical, 10)
            .padding(.horizontal)
            .contentShape(Rectangle())
        }
        .foregroundColor(.primary)
    }
}
