import SwiftUI

final class MenuStateViewModel: ObservableObject {
    @Published var isMenuShowing: Bool = false
    let menuWidth: CGFloat = UIScreen.main.bounds.width * 0.75 // Ширина меню: 75% экрана
    
    func toggleMenu() {
        withAnimation(.easeOut(duration: 0.3)) {
            isMenuShowing.toggle()
        }
    }
}
