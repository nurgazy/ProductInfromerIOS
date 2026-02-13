import Foundation
import GRDB

class AppDatabase {
    // Глобальная очередь для доступа к БД
    static let shared = try! AppDatabase()
    
    let dbQueue: DatabaseQueue

    private init() throws {
        // 1. Определяем путь к файлу БД
        let fileManager = FileManager.default
        let appSupportURL = try fileManager.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dbURL = appSupportURL.appendingPathComponent("db.sqlite")
        
        // 2. Инициализируем очередь (если файла нет, он будет создан)
        self.dbQueue = try DatabaseQueue(path: dbURL.path)
        
        // 3. Запускаем миграции (создание таблиц)
        try migrator.migrate(dbQueue)
    }

    // Настройка миграций
    private var migrator: DatabaseMigrator {
        var migrator = DatabaseMigrator()
        
        migrator.registerMigration("v1_create_users") { db in
            // Создание таблицы, если она не существует
            try db.create(table: "barcode") { t in
                t.autoIncrementedPrimaryKey("barcodeDocId") //
                t.column("status", .text).notNull() //
                t.column("uuid1C", .text).notNull() //
                t.column("creationTimestamp", .datetime).notNull() //
            }
            
            // Создание таблицы barcodeDetails
            try db.create(table: "barcodeDetails") { t in
                t.autoIncrementedPrimaryKey("barcodeDetailId") //
                t.column("barcode", .text).notNull() //
                t.column("productName", .text).notNull() //
                t.column("productSpecName", .text).notNull() //
                t.column("productUuid1C", .text).notNull() //
                t.column("productSpecUuid1C", .text).notNull() //
                t.column("quantity", .integer).notNull().defaults(to: 0) //
                
                // Внешний ключ на таблицу barcode
                t.column("barcodeDocId", .integer)
                    .notNull()
                    .indexed() // Создание индекса
                    .references("barcode", column: "barcodeDocId", onDelete: .cascade) //
            }
        }
        
        return migrator
    }
}
