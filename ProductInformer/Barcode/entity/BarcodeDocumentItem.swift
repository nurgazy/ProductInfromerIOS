// Предполагаемая структура BarcodeDocumentItem
struct BarcodeDocumentItem {
    let name: String
    let barcode: String
    let productUuid1C: String
    let productSpecUuid1C: String
    let quantity: Int
}

extension BarcodeDocDetail {
    func toBarcodeDocumentItem() -> BarcodeDocumentItem {
        return BarcodeDocumentItem(
            name: "\(self.productName); \(self.productSpecName)",
            barcode: self.barcode,
            productUuid1C: self.productUuid1C,
            productSpecUuid1C: self.productSpecUuid1C,
            quantity: self.quantity
        )
    }
}
