import Foundation
import Combine
import SwiftUI

@MainActor
class BarcodeListViewModel: ObservableObject {
    @Published var barcodeDocs: [BarcodeDoc] = []
    
    private let repository: BarcodeRepository
    private var cancellables = Set<AnyCancellable>()
    private var coordinatorPath: Binding<NavigationPath?>

    init(repository: BarcodeRepository = BarcodeRepository(), coordinatorPath: Binding<NavigationPath?>) {
        self.coordinatorPath = coordinatorPath // Сохраняем привязку
        self.repository = repository
        observeDocuments()
    }
    
    func addNewDocument() {
        if coordinatorPath.wrappedValue != nil{
            let target = AppNavigationTarget(destinationID: "barcodeDetail", productString: "0")
            coordinatorPath.wrappedValue?.append(AppNavigation.view(target))
        }
    }
    
    private func observeDocuments() {
        cancellables.removeAll()
        
        repository.getBarcodeDocs()
            .receive(on: DispatchQueue.main)
            .sink(receiveCompletion: { completion in
                if case .failure(let error) = completion {
                    print("Error observing DB: \(error)")
                }
            }, receiveValue: { [weak self] docs in
                self?.barcodeDocs = docs
            })
            .store(in: &cancellables)
    }

    func refreshBarcodeDocList() {

    }

    func onDeleteDoc(_ doc: BarcodeDoc) {
        try? repository.deleteBarcodeDoc(doc)
    }
    
}
