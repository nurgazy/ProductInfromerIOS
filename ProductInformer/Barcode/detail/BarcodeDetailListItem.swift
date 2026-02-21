import SwiftUI

struct BarcodeDetailListItem: View {
    let itemNumber: Int
    let item: BarcodeDocDetail
    var onDeleteClick: () -> Void
    
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Номер позиции
            Text("\(itemNumber)")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 25, alignment: .leading)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.barcode)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("\(item.productName) \(item.productSpecName)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            Spacer()
            
            // Количество
            Text("\(item.quantity)")
                .font(.title3.bold())
                .foregroundColor(.blue)
                .padding(.horizontal, 8)
            
            // Кнопка удаления
            Button(action: onDeleteClick) {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 8)
    }
}
