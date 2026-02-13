import Foundation
import GRDB

struct BarcodeDoc: Codable, FetchableRecord, PersistableRecord {
    var barcodeDocId: Int64?
    var status: String // В Swift обычно используется String или Enum для статусов
    var uuid1C: String
    var creationTimestamp: Date
    
    // Определение названий столбцов для удобства запросов
    enum Columns {
        static let barcodeDocId = Column(CodingKeys.barcodeDocId)
        static let status = Column(CodingKeys.status)
        static let uuid1C = Column(CodingKeys.uuid1C)
        static let creationTimestamp = Column(CodingKeys.creationTimestamp)
    }
    
    // Имя таблицы в БД
    static var databaseTableName = "barcode"
    
    // Указываем GRDB, какой столбец является первичным ключом и должен обновляться после вставки
    mutating func didInsert(with rowID: Int64, for column: String?) {
        barcodeDocId = rowID
    }
}
