import Foundation
import GRDB

struct BarcodeDocDetail: Codable, FetchableRecord, PersistableRecord {
    var barcodeDetailId: Int64?
    var barcode: String
    var productName: String
    var productSpecName: String
    var productUuid1C: String
    var productSpecUuid1C: String
    var barcodeDocId: Int64
    var quantity: Int
    
    enum Columns {
        static let barcodeDetailId = Column(CodingKeys.barcodeDetailId)
        static let barcode = Column(CodingKeys.barcode)
        static let productName = Column(CodingKeys.productName)
        static let productSpecName = Column(CodingKeys.productSpecName)
        static let productUuid1C = Column(CodingKeys.productUuid1C)
        static let productSpecUuid1C = Column(CodingKeys.productSpecUuid1C)
        static let barcodeDocId = Column(CodingKeys.barcodeDocId)
        static let quantity = Column(CodingKeys.quantity)
    }
    
    static var databaseTableName = "barcodeDetails"
    
    mutating func didInsert(with rowID: Int64, for column: String?) {
        barcodeDetailId = rowID
    }
}
