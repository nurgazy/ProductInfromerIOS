import SwiftUI

struct BarcodeListScreen: View {
    @StateObject private var viewModel = BarcodeListViewModel()
    
    var body: some View {
        NavigationView {
            VStack {
                List {
                    ForEach(viewModel.barcodeDocs, id: \.barcodeDocId) { doc in
                        BarcodeDocItem(
                            document: doc,
                            onEditClick: {
                                // Логика перехода на редактирование
                                print("Edit: \(doc.barcodeDocId ?? 0)")
                            },
                            onDeleteClick: {
                                viewModel.onDeleteDoc(doc)
                            }
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                    }
                }
                .listStyle(.plain)
                
                Button(action: {
                    // Логика добавления нового документа
                }) {
                    Text("Добавить")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .padding()
            }
            .navigationTitle("Список штрихкодов")
            .onAppear {
                viewModel.refreshBarcodeDocList()
            }
        }
    }
}
