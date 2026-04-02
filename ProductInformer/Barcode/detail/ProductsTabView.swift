import SwiftUI

struct ProductsTabView: View {
    @ObservedObject var viewModel: BarcodeDetailVM
    @State private var manualBarcode = ""
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack {
                TextField("Поиск по названию или штрихкоду", text: $viewModel.searchText)
                    .padding(10)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                    .padding(.horizontal)
                    .padding(.top, 5)
                
                List {
                    ForEach(Array(viewModel.filteredBarcodeList.enumerated()), id: \.offset) { index, item in
                        BarcodeDetailListItem(itemNumber: index + 1, item: item) {
                            viewModel.deleteItem(item)
                        }
                    }
                }
                .listStyle(.plain)
            }
            
            Button(action: {
                manualBarcode = "" // Сброс поля
                viewModel.showManualInput = true
            }) {
                Image(systemName: "plus")
                    .font(.title.bold())
                    .foregroundColor(.white)
                    .frame(width: 56, height: 56)
                    .background(Color.blue)
                    .clipShape(Circle())
                    .shadow(radius: 4)
            }
            .padding(.trailing, 20)
            .padding(.bottom, 20)
        }
        .alert("Введите штрихкод", isPresented: $viewModel.showManualInput) {
            TextField("Штрихкод", text: $manualBarcode)
                .keyboardType(.numberPad) // Оптимально для штрихкодов
            
            Button("Поиск") {
                viewModel.processManualBarcode(manualBarcode)
            }
            Button("Отмена", role: .cancel) { }
        } message: {
            Text("Введите штрихкод.")
        }
        
    }
}
