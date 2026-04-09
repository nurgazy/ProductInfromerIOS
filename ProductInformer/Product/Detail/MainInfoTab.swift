import SwiftUI

struct MainInfoTab: View {
    let nomenclature: Nomenclature
    
    var body: some View {
        List {
            Section(header: Text("Основные").font(.headline)) {
                DetailRow(label: "Штрихкод", value: nomenclature.barcode)
                DetailRow(label: "Производитель", value: nomenclature.manufacturer ?? "—")
                DetailRow(label: "Марка", value: nomenclature.brand ?? "—")
                DetailRow(label: "Категория", value: nomenclature.productCategory ?? "—")
            }

            Section(header: Text("Статистика").font(.headline)) {
                StatRow(label: "Кол-во закупки", value: nomenclature.quantityPurchase)
                StatRow(label: "Кол-во продажи", value: nomenclature.quantitySold)
                StatRow(label: "Текущий остаток", value: nomenclature.quantityBalance)
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
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
        }
    }
}

struct StatRow: View {
    let label: String
    let value: Int
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.gray)
            Spacer()
            Text("\(value)")
                .multilineTextAlignment(.trailing)
        }
    }
}
