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
    
    enum CodingKeys: String, CodingKey {
        case name = "Наименование"
        case uuid1с = "ГУИД1С"
        case barcode = "Штрихкод"
        case article = "Артикул"
        case manufacturer = "Производитель"
        case brand = "Марка"
        case productCategory = "ТоварнаяКатегория"
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
        hasher.combine(uuid1C)
    }

    static func == (lhs: Characteristic, rhs: Characteristic) -> Bool {
        return lhs.uuid1C == rhs.uuid1C
    }
}

struct Stock: Decodable, Hashable, Encodable {
    let warehouse: String
    let inStock: Int
    let available: Int
    let unit: String
    
    enum CodingKeys: String, CodingKey {
        case warehouse = "Склад"
        case inStock = "ВНаличии"
        case available = "Доступно"
        case unit = "Единица"
    }
}

struct Price: Decodable, Hashable, Encodable {
    let priceType: String
    let price: Double // Используем Double, так как цена может быть с копейками
    let currency: String
    
    enum CodingKeys: String, CodingKey {
        case priceType = "ВидЦены"
        case price = "Цена"
        case currency = "Валюта"
    }
}
