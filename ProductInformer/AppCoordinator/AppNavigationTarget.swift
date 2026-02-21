import Foundation

// ProductModels.swift or AppNavigation.swift
struct AppNavigationTarget: Hashable, Equatable {
    let destinationID: String
    let productString: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(destinationID)
        hasher.combine(productString)
    }
    
    static func == (lhs: AppNavigationTarget, rhs: AppNavigationTarget) -> Bool {
        return lhs.destinationID == rhs.destinationID && lhs.productString == rhs.productString
    }
}
