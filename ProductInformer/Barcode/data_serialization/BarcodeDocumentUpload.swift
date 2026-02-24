import Foundation

struct BarcodeDocumentUpload: Codable {
    let internalId: Int64?
    let uuid1C: String
    let username: String
    let items: [BarcodeDocumentItemUpload]
}

struct BarcodeDocumentItemUpload: Codable {
    let name: String
    let barcode: String
    let quantity: Int
    let productUuid1C: String
    let productSpecUuid1C: String
}
