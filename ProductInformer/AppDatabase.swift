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
            try db.create(table: "users") { t in
                t.autoIncrementedPrimaryKey("id")
                t.column("name", .text).notNull()
                t.column("email", .text).unique().notNull()
            }
        }
        
        return migrator
    }
}