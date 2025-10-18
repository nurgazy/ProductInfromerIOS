//
//  ProductNavigationTarget.swift
//  ProductInformer
//
//  Created by Nurgazy on 14/10/25.
//

import Foundation

// ProductModels.swift or AppNavigation.swift
struct AppNavigationTarget: Hashable, Equatable {
    let destinationID: String
    let productString: String

    func hash(into hasher: inout Hasher) {
        hasher.combine(destinationID)
    }
    
    static func == (lhs: AppNavigationTarget, rhs: AppNavigationTarget) -> Bool {
        return lhs.destinationID == rhs.destinationID
    }
}
