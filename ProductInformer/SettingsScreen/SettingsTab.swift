import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "Основные"
    case additional = "Дополнительные"
    
    var id: String { self.rawValue }
}
