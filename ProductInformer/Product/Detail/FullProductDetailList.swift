import SwiftUI

struct FullProductDetailList: View {
    let product: ProductResponse
    
    var body: some View {
        List {
            if let characteristics = product.characteristics, !characteristics.isEmpty {
                ForEach(Array(characteristics.enumerated()), id: \.offset) { _, characteristic in
                    CharacteristicDetailSection(characteristic: characteristic)
                }
            } else {
                Text("Характеристики не указаны")
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct CharacteristicDetailSection: View {
    let characteristic: Characteristic
    
    @State private var isAllCharacteristicsExpanded: Bool = true
    @State private var isStocksExpanded: Bool = true
    @State private var isPricesExpanded: Bool = true
    
    private var title: String {
        let trimmed = characteristic.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Основная характеристика" : trimmed
    }
    
    var body: some View {
        DisclosureGroup(title, isExpanded: $isAllCharacteristicsExpanded) {
            DisclosureGroup("Остатки (В наличии / Доступно)", isExpanded: $isStocksExpanded) {
                if let stocks = characteristic.stocks, !stocks.isEmpty {
                    ForEach(Array(stocks.enumerated()), id: \.offset) { _, stock in
                        StockDetailRow(stock: stock)
                    }
                } else {
                    HStack {
                        Text("Нет на складе")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("0 шт")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                    .padding(.vertical, 4)
                }
            }
            
            DisclosureGroup("Цены", isExpanded: $isPricesExpanded) {
                if let prices = characteristic.prices, !prices.isEmpty {
                    ForEach(Array(prices.enumerated()), id: \.offset) { _, price in
                        PriceDetailRow(price: price)
                    }
                } else {
                    Text("Цены не указаны")
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct StockDetailRow: View {
    let stock: Stock
    
    private var isOutOfStock: Bool {
        stock.inStock <= 0 || stock.warehouse.localizedCaseInsensitiveContains("нет в наличии")
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(stock.warehouse)
                .font(.subheadline)
                .fontWeight(.medium)
            
            Spacer()
            
            if isOutOfStock {
                Text("Нет в наличии")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.12))
                    .cornerRadius(6)
            } else {
                Text("\(stock.inStock) / \(stock.available) \(stock.unit ?? "шт")")
                    .font(.subheadline)
                    .foregroundColor(.primary)
            }
        }
        .padding(.vertical, 4)
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
            Text("\(price.priceType):")
            Spacer()
            Text("\(formattedPrice) \(price.currency)")
                .fontWeight(.medium)
                .foregroundColor(.green)
        }
        .padding(.vertical, 4)
    }
}
