import SwiftUI

struct BarcodeDocItem: View {
    let document: BarcodeDoc
    let onEditClick: () -> Void
    let onDeleteClick: () -> Void

    // Форматирование даты
    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        return formatter.string(from: document.creationTimestamp)
    }

    // Перевод статуса
    private var statusText: String {
        switch document.status {
        case "ACTIVE": return "Активный"
        case "COMPLETED": return "Завершен"
        case "UPLOADED": return "Выгружен"
        default: return document.status
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading) {
                    Text("\(document.barcodeDocId ?? 0). Статус: \(statusText)")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Дата: \(formattedDate)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onEditClick) {
                    Image(systemName: "pencil")
                        .foregroundColor(.blue)
                }
                .padding(.trailing, 8)

                Button(action: onDeleteClick) {
                    Image(systemName: "trash")
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 2)
        .padding(.horizontal)
    }
}
