import Foundation
import GRDB
import Combine

class BarcodeRepository {
    private let dbQueue: DatabaseQueue

    init(dbQueue: DatabaseQueue = AppDatabase.shared.dbQueue) {
        self.dbQueue = dbQueue
    }

    // Получение списка документов (аналог Flow в Kotlin)
    func getBarcodeDocs() -> AnyPublisher<[BarcodeDoc], Error> {
        return ValueObservation
            .tracking { db in try BarcodeDoc.fetchAll(db) }
            .publisher(in: dbQueue)
            .eraseToAnyPublisher()
    }

    func deleteBarcodeDoc(_ doc: BarcodeDoc) throws {
        try dbQueue.write { db in
            _ = try doc.delete(db)
        }
    }
}
