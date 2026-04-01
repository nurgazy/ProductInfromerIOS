import SwiftUI

struct ProductsTabView: View {
    @ObservedObject var viewModel: BarcodeDetailVM
    
    var body: some View {
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
    }
}
