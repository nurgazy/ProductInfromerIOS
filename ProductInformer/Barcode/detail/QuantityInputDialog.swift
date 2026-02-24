import SwiftUI

struct QuantityInputDialog: View {
    let barcode: String
    @Binding var quantity: String
    var onConfirm: (Int) -> Void
    var onDismiss: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Введите количество")
                .font(.headline)
            
            Text("Штрихкод: \(barcode)")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            // Стэк управления количеством
            HStack(spacing: 20) {
                // Кнопка Минус
                Button(action: { changeQuantity(by: -1) }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundColor(.red)
                }
                
                TextField("0", text: $quantity)
                    .keyboardType(.numberPad)
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.center)
                    .frame(width: 80) // Ограничиваем ширину для компактности
                
                // Кнопка Плюс
                Button(action: { changeQuantity(by: 1) }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal)
            
            HStack(spacing: 16) {
                Button("Отмена", action: onDismiss)
                    .foregroundColor(.red)
                
                Spacer()
                
                Button("Подтвердить") {
                    if let val = Int(quantity), val > 0 {
                        onConfirm(val)
                    }
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
        .frame(width: 300)
    }
    
    // Вспомогательная функция для инкремента/декремента
    private func changeQuantity(by amount: Int) {
        let currentVal = Int(quantity) ?? 0
        let newVal = max(1, currentVal + amount) // Не позволяем опускаться ниже 1
        quantity = String(newVal)
    }
}
