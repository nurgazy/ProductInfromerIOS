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
            
            TextField("Количество", text: $quantity)
                .keyboardType(.numberPad)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
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
}
