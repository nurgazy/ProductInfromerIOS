import SwiftUI

// 💡 Предполагается, что все структуры данных (ProductResponse, Nomenclature, Characteristic, Stock, Price) доступны в этом файле или импортированы.

struct ProductDetailView: View {
    
    // 1. Вход: Принимает сырую строку JSON, переданную через навигацию
    let productString: String
    
    // 2. Состояние: Для хранения результата декодирования
    @State private var decodedProduct: ProductResponse?
    @State private var decodingError: String?
    
    var body: some View {
        Group {
            if let product = decodedProduct {
                TabView {
                    FullProductDetailList(product: product)
                        .tabItem {
                            Label("Детали", systemImage: "list.bullet")
                        }
                    
                    ProductImageTab(imageString: product.image, productName: product.nomenclature.name)
                        .tabItem {
                            Label("Картинка", systemImage: "photo")
                        }
                }
            } else if let error = decodingError {
                // ❌ Ошибка: Отображение ошибки декодирования
                ErrorView(error: error, rawData: productString)
            } else {
                // ⏳ Ожидание: Запуск декодирования при первом появлении
                ProgressView("Обработка данных...")
            }
        }
        .onAppear {
            // Запуск логики декодирования при загрузке представления
            decodeProductData()
        }
    }
    
    // 3. Логика декодирования
    private func decodeProductData() {
        // Защита от повторного декодирования
        guard decodedProduct == nil && decodingError == nil else { return }

        guard let data = productString.data(using: .utf8) else {
            decodingError = "Не удалось преобразовать строку в Data."
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(ProductResponse.self, from: data)
            
            if response.result {
                self.decodedProduct = response
            } else {
                // Сервер 1С вернул result: false
                self.decodingError = "Сервер 1С: Продукт не найден (result: false)."
            }
        } catch {
            // Ошибка синтаксического анализа JSON или несоответствие типов
            self.decodingError = "Ошибка декодирования JSON: \(error.localizedDescription).\nПроверьте, соответствуют ли модели данным."
            print("Ошибка декодирования: \(error)")
        }
    }
}

// Основное представление с List
struct FullProductDetailList: View {
    
    let product: ProductResponse
    
    var body: some View {
        List {
            nomenclatureSection
            characteristicsSection
        }
        .listStyle(.insetGrouped)
    }
    
    var nomenclatureSection: some View {
        Section(header: Text(product.nomenclature.name).font(.headline)) {
            DetailRow(label: "Штрихкод", value: product.nomenclature.barcode)
            DetailRow(label: "Артикул", value: product.nomenclature.article ?? "Нет данных")
            DetailRow(label: "Производитель", value: product.nomenclature.manufacturer ?? "Нет данных")
            DetailRow(label: "Марка", value: product.nomenclature.brand ?? "Нет данных")
            DetailRow(label: "Категория", value: product.nomenclature.productCategory ?? "Нет данных")
        }
    }
    
    var characteristicsSection: some View {
        // Безопасный перебор опционального массива
        ForEach(product.characteristics ?? [], id: \.uuid1C) { characteristic in
            CharacteristicDetailSection(characteristic: characteristic)
        }
    }
}

struct ProductImageTab: View {
    let imageString: String?
    let productName: String
    
    @State private var uiImage: UIImage? = nil
    
    var body: some View {
        VStack {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else if imageString == nil || imageString!.isEmpty {
                if #available(iOS 17.0, *){
                    ContentUnavailableView(
                        "Изображение отсутствует",
                        systemImage: "photo.slash",
                        description: Text("Данные об изображении не предоставлены сервером.")
                    )
                }
                else{
                    VStack(spacing: 10) {
                        Image(systemName: "photo.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Изображение отсутствует")
                            .font(.headline)
                        Text("Данные об изображении не предоставлены сервером.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            } else {
                ProgressView("Загрузка изображения...")
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    // Логика декодирования Base64
    private func loadImage() {
        guard let base64String = imageString, !base64String.isEmpty else { return }
        
        // В вашем примере JSON строка начинается с "/9j/...", что является началом
        // Base64-кодировки JPEG-изображения.
        
        // 1. Преобразование Base64 строки в Data
        if let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) {
            // 2. Создание UIImage из Data
            if let image = UIImage(data: data) {
                self.uiImage = image
                return
            }
        }
        
        // Если декодирование не удалось (например, если строка была путём, а не Base64)
        print("Не удалось декодировать Base64-изображение.")
    }
}

// Представление для отображения ошибок
struct ErrorView: View {
    let error: String
    let rawData: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Произошла ошибка обработки данных")
                    .font(.title2)
                    .foregroundColor(.red)
                
                Text(error)
                    .font(.body)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                
                Text("Сырые данные (JSON):")
                    .font(.headline)
                
                Text(rawData)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                
                Spacer()
            }
            .padding()
        }
    }
}

// Вспомогательные структуры для деталей
struct CharacteristicDetailSection: View {
    let characteristic: Characteristic
    
    @State private var isStocksExpanded: Bool = true // По умолчанию открыто для демонстрации
    @State private var isPricesExpanded: Bool = true
    
    var body: some View {
        Section(header: Text("\(characteristic.name)").font(.headline)) {

            DisclosureGroup("Остатки (В наличии/Доступно)", isExpanded: $isStocksExpanded) {
                ForEach(characteristic.stocks ?? [], id: \.warehouse) { stock in
                    StockDetailRow(stock: stock)
                }
                if ((characteristic.stocks?.isEmpty) == nil) {
                    Text("Нет данных об остатках.").foregroundColor(.gray)
                }
            }
            
            DisclosureGroup("Цены", isExpanded: $isPricesExpanded) {
                ForEach(characteristic.prices ?? [], id: \.priceType) { price in
                    PriceDetailRow(price: price)
                }
                if ((characteristic.prices?.isEmpty) == nil) {
                    Text("Нет данных о ценах.").foregroundColor(.gray)
                }
            }
        }
    }
}

struct StockDetailRow: View {
    let stock: Stock
    
    var body: some View {
        HStack(spacing: 5) {
            Text("Склад: \(stock.warehouse)").font(.subheadline).bold()
            Spacer()
            Text("\(stock.inStock) / \(stock.available)")
        }
        .padding(.vertical, 5)
    }
}

struct PriceDetailRow: View {
    let price: Price
    
    var body: some View {
        HStack {
            Text("\(price.priceType): ")
            Spacer()
            // Форматируем цену до двух знаков после запятой
            Text(String(format: "%.2f %@", price.price, price.currency))
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
        .padding(.vertical, 5)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}
