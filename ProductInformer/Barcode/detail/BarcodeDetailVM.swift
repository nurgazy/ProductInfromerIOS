import Foundation
import SwiftUI
import Combine
import GRDB

@MainActor
class BarcodeDetailVM: ObservableObject {
    @Published var barcodeList: [BarcodeDocDetail] = []
    @Published var curBarcodeDoc: BarcodeDoc?
    @Published var showQuantityDialog = false
    @Published var uploadStatusMessage: String?
    @Published var showScanner = false
    @Published var isUploading = false
    
    private let dbQueue: DatabaseQueue = AppDatabase.shared.dbQueue
    private var cancellables = Set<AnyCancellable>()
    private var barcodeDocId: Int64?
    private var coordinatorPath: Binding<NavigationPath?>
    
    // Временные данные для диалога
    var lastScannedBarcode: String = ""

    init(barcodeDocId: Int64?, coordinatorPath: Binding<NavigationPath?>) {
        self.coordinatorPath = coordinatorPath
        self.barcodeDocId = (barcodeDocId == 0) ? nil : barcodeDocId
        
        if self.barcodeDocId != nil {
            loadData()
        }
        
    }

    func loadData() {
        guard let id = barcodeDocId else { return }
        
        try? dbQueue.read { db in
            self.curBarcodeDoc = try BarcodeDoc.fetchOne(db, key: id)
        }
        
        ValueObservation.tracking { db in
            try BarcodeDocDetail.filter(Column("barcodeDocId") == id).fetchAll(db)
        }.publisher(in: dbQueue)
        .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] items in
            self?.barcodeList = items
        })
        .store(in: &cancellables)
    }

    func saveDoc() {
        guard barcodeDocId == nil else { return }
        var newDoc = BarcodeDoc(barcodeDocId: nil, status: "ACTIVE", uuid1C: UUID().uuidString, creationTimestamp: Date())
        try? dbQueue.write { db in
            try newDoc.insert(db)
            self.barcodeDocId = newDoc.barcodeDocId
            loadData()
        }
    }

    func deleteItem(_ item: BarcodeDocDetail) {
        try? dbQueue.write { db in
            _ = try item.delete(db)
        }
    }

    func uploadTo1C() {
        guard let doc = curBarcodeDoc, !barcodeList.isEmpty else { return }
        isUploading = true
    }
    
    func handleScanResult(barcode: String) {
        self.lastScannedBarcode = barcode
        self.showScanner = false
        self.showQuantityDialog = true
    }
    
    func addProductWithQuantity(_ qty: Int) {
        // Логика добавления товара в базу (аналог vm.addToBarcodeList(quantity))
        self.showQuantityDialog = false
    }
}
