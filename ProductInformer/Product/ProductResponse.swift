import Foundation

struct ProductResponse: Decodable, Hashable, Encodable {
    let result: Bool
    let nomenclature: Nomenclature
    let characteristics: [Characteristic]?
    let image: String?
    
    enum CodingKeys: String, CodingKey {
        case result = "Результат"
        case nomenclature = "Номенклатура"
        case characteristics = "Характеристики"
        case image = "Картинка"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(nomenclature.uuid1с)
    }
    
    static func == (lhs: ProductResponse, rhs: ProductResponse) -> Bool {
        return lhs.nomenclature.uuid1с == rhs.nomenclature.uuid1с
    }
}

struct Nomenclature: Decodable, Hashable, Encodable {
    let name: String
    let uuid1с: String
    let barcode: String
    let article: String?
    let manufacturer: String?
    let brand: String?
    let productCategory: String?
    let quantityPurchase: Int?
    let quantitySold: Int?
    let quantityBalance: Int?
    
    enum CodingKeys: String, CodingKey {
        case name = "Наименование"
        case uuid1с = "ГУИД1С"
        case barcode = "Штрихкод"
        case article = "Артикул"
        case manufacturer = "Производитель"
        case brand = "Марка"
        case productCategory = "ТоварнаяКатегория"
        case quantityPurchase = "КоличествоЗакупки"
        case quantitySold = "КоличествоПродажи"
        case quantityBalance = "КоличествоОстаток"
    }
}

struct Characteristic: Decodable, Hashable, Encodable {
    let name: String
    let uuid1C: String
    let barcode: String
    let stocks: [Stock]?
    let prices: [Price]?
    
    enum CodingKeys: String, CodingKey {
        case name = "Наименование"
        case uuid1C = "ГУИД1С"
        case barcode = "Штрихкод"
        case stocks = "Остатки"
        case prices = "Цены"
    }
    
    func hash(into hasher: inout Hasher) {
        // Если ГУИД пустой, объединяем со штрихкодом для уникальности
        hasher.combine(uuid1C.isEmpty ? barcode : uuid1C)
    }

    static func == (lhs: Characteristic, rhs: Characteristic) -> Bool {
        let lhsID = lhs.uuid1C.isEmpty ? lhs.barcode : lhs.uuid1C
        let rhsID = rhs.uuid1C.isEmpty ? rhs.barcode : rhs.uuid1C
        return lhsID == rhsID
    }
}

struct Stock: Decodable, Hashable, Encodable {
    let warehouse: String
    let inStock: Int
    let available: Int
    let unit: String?
    
    enum CodingKeys: String, CodingKey {
        case warehouse = "Склад"
        case inStock = "ВНаличии"
        case inStockAlt = "Вналичии"
        case available = "Доступно"
        case unit = "Единица"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.warehouse = try container.decodeIfPresent(String.self, forKey: .warehouse) ?? "Склад не указан"
        
        // Поддержка обоих вариантов написания ключа из 1С ("ВНаличии" и "Вналичии")
        if let stock = try? container.decode(Int.self, forKey: .inStock) {
            self.inStock = stock
        } else if let stockAlt = try? container.decode(Int.self, forKey: .inStockAlt) {
            self.inStock = stockAlt
        } else {
            self.inStock = 0
        }
        
        self.available = try container.decodeIfPresent(Int.self, forKey: .available) ?? 0
        self.unit = try container.decodeIfPresent(String.self, forKey: .unit)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(warehouse, forKey: .warehouse)
        try container.encode(inStock, forKey: .inStock)
        try container.encode(available, forKey: .available)
        try container.encodeIfPresent(unit, forKey: .unit)
    }
}

struct Price: Decodable, Hashable, Encodable {
    let priceType: String
    let price: Double
    let currency: String
    
    enum CodingKeys: String, CodingKey {
        case priceType = "ВидЦены"
        case price = "Цена"
        case currency = "Валюта"
    }
}
