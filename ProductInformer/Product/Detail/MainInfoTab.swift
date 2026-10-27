import SwiftUI

struct MainInfoTab: View {
    let nomenclature: Nomenclature
    
    var body: some View {
        List {
            Section(header: Text("Основные").font(.headline)) {
                DetailRow(label: "Штрихкод", value: nomenclature.barcode)
                DetailRow(
                    label: "Производитель",
                    value: (nomenclature.manufacturer?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                        ? "—"
                        : nomenclature.manufacturer!
                )
                DetailRow(
                    label: "Марка",
                    value: (nomenclature.brand?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                        ? "—"
                        : nomenclature.brand!
                )
                DetailRow(
                    label: "Категория",
                    value: (nomenclature.productCategory?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
                        ? "—"
                        : nomenclature.productCategory!
                )
            }

            Section(header: Text("Статистика").font(.headline)) {
                StatRow(label: "Кол-во закупки", value: nomenclature.quantityPurchase ?? 0)
                StatRow(label: "Кол-во продажи", value: nomenclature.quantitySold ?? 0)
                StatRow(
                    label: "Текущий остаток",
                    value: nomenclature.quantityBalance ?? 0,
                    highlightZero: true
                )
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: Int
    var highlightZero: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            if highlightZero && value <= 0 {
                Text("0 шт (нет в наличии)")
                    .foregroundColor(.red)
                    .fontWeight(.medium)
            } else {
                Text("\(value)")
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
