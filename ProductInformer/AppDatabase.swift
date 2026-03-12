import Foundation
import GRDB

class AppDatabase {
    // Глобальная очередь для доступа к БД
    static let shared = try! AppDatabase()
    
    let dbQueue: DatabaseQueue

    private init() throws {

        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dbURL = appSupportURL.appendingPathComponent("db.sqlite")
        
        self.dbQueue = try DatabaseQueue(path: dbURL.path)
        
        try migrator.migrate(dbQueue)
        
        #if targetEnvironment(simulator)
        try dbQueue.write { db in
            let count = try BarcodeDoc.fetchCount(db)
            if count == 0 {
                try self.createTestData(in: db)
            }
        }
        #endif
    }

    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1_create_barcodes") { db in

            try db.create(table: "barcode", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("barcodeDocId") //
                t.column("status", .text).notNull() //
                t.column("uuid1C", .text).notNull() //
                t.column("creationTimestamp", .datetime).notNull() //
            }
            
            try db.create(table: "barcodeDetails", ifNotExists: true) { t in
                t.autoIncrementedPrimaryKey("barcodeDetailId") //
                t.column("barcode", .text).notNull() //
                t.column("productName", .text).notNull() //
                t.column("productSpecName", .text).notNull() //
                t.column("productUuid1C", .text).notNull() //
                t.column("productSpecUuid1C", .text).notNull() //
                t.column("quantity", .integer).notNull().defaults(to: 0) //
                
                t.column("barcodeDocId", .integer)
                    .notNull()
                    .indexed() //
                    .references("barcode", column: "barcodeDocId", onDelete: .cascade) //
            }
        }
        
        migrator.registerMigration("v2_add_comment_to_barcode") { db in
            try db.alter(table: "barcode") { t in
                t.add(column: "comment", .text).defaults(to: "")
            }
            
            try db.execute(sql: "UPDATE barcode SET comment = '' WHERE comment IS NULL")
        }
        
        return migrator
    }
    
    func createTestData(in db: Database) throws {
        var currentID: Int64
        
        var doc = BarcodeDoc(
            barcodeDocId: nil,
            status: "ACTIVE",
            uuid1C: "",
            creationTimestamp: Date(),
            comment: "Тестовый документ"
        )
        if let savedDoc = try doc.insertAndFetch(db) {
            guard let id = savedDoc.barcodeDocId else {
                throw DatabaseError.idGenerationFailed
            }
            currentID = id
        } else {
            throw DatabaseError.idGenerationFailed
        }
        
        if let docId = doc.barcodeDocId {
            let items = [
                BarcodeDocDetail(
                    barcodeDetailId: nil,
                    barcode: "2000000512518",
                    productName: "Тестовый товар 1",
                    productSpecName: "Красный",
                    productUuid1C: "a5ee9dfb-6cd5-11ee-80bd-94188200db37",
                    productSpecUuid1C: "a5ee9dfc-6cd5-11ee-80bd-94188200db37",
                    barcodeDocId: currentID,
                    quantity: 5
                ),
                BarcodeDocDetail(
                    barcodeDetailId: nil,
                    barcode: "2000000512532",
                    productName: "Тестовый товар 2",
                    productSpecName: "XL",
                    productUuid1C: "a5ee9dfb-6cd5-11ee-80bd-94188200db37",
                    productSpecUuid1C: "a5ee9e00-6cd5-11ee-80bd-94188200db37",
                    barcodeDocId: currentID,
                    quantity: 10
                )
            ]
            
            for var item in items {
                try item.insert(db)
            }
        }
    }

}
