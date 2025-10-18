//
//  AppCoordinatorViewModel.swift
//  ProductInformer
//
//  Created by Nurgazy on 14/10/25.
//

import Foundation
import SwiftUI

final class AppCoordinatorViewModel: ObservableObject {
    @Published var navigationPath = NavigationPath()
    @Published var currentRoot: String = "barcodeInput"
    
    @available(iOS 16.0, *)
    func navigateToRoot(destination: AppNavigation) {
        navigationPath = NavigationPath()
        navigationPath.append(destination)
    }
}
