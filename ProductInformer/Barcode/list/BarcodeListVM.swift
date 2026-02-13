import Foundation
import Combine

class BarcodeListViewModel: ObservableObject {
    @Published var barcodeDocs: [BarcodeDoc] = []
    
    private let repository: BarcodeRepository
    private var cancellables = Set<AnyCancellable>()

    init(repository: BarcodeRepository = BarcodeRepository()) {
        self.repository = repository
    }

    func refreshBarcodeDocList() {
        repository.getBarcodeDocs()
            .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] docs in
                self?.barcodeDocs = docs
            })
            .store(in: &cancellables)
    }

    func onDeleteDoc(_ doc: BarcodeDoc) {
        try? repository.deleteBarcodeDoc(doc)
    }
}
