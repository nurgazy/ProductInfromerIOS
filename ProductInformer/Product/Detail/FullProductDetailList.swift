import SwiftUI

struct FullProductDetailList: View {
    let product: ProductResponse
    
    var body: some View {
        List {
            if let characteristics = product.characteristics, !characteristics.isEmpty {
                ForEach(characteristics, id: \.uuid1C) { characteristic in
                    CharacteristicDetailSection(characteristic: characteristic)
                }
            } else {
                Text("Характеристики и цены не указаны")
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
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
    
    private var formattedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.groupingSeparator = " "
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        
        let number = NSNumber(value: price.price)
        return formatter.string(from: number) ?? String(format: "%.2f", price.price)
    }
    
    var body: some View {
        HStack {
            Text("\(price.priceType): ")
            Spacer()
            // Форматируем цену до двух знаков после запятой
            Text("\(formattedPrice) \(price.currency)")
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
        .padding(.vertical, 5)
    }
}

