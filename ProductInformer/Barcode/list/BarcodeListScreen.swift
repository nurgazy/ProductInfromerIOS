import SwiftUI

struct BarcodeListScreen: View {
    @Binding var coordinatorPath: NavigationPath?
    @StateObject private var viewModel: BarcodeListViewModel
    
    @State private var selectedDocId: Int64?
    @State private var navigateToDetail = false
    
    init(coordinatorPath: Binding<NavigationPath?>) {
        self._coordinatorPath = coordinatorPath
        self._viewModel = StateObject(wrappedValue: BarcodeListViewModel(coordinatorPath: coordinatorPath))
    }
    
    var body: some View {
        VStack {
            List {
                ForEach(viewModel.barcodeDocs, id: \.barcodeDocId) { doc in
                    BarcodeDocItem(
                        document: doc,
                        onEditClick: {
                            let target = AppNavigationTarget(
                                destinationID: "barcodeDetail",
                                productString: String(doc.barcodeDocId ?? 0)
                            )
                            coordinatorPath?.append(AppNavigation.view(target))
                        }
                    )
                    .buttonStyle(BorderlessButtonStyle())
                    .padding(.vertical, 4)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets())
                }
                .onDelete { indexSet in
                    indexSet.map { viewModel.barcodeDocs[$0] }.forEach { doc in
                        viewModel.onDeleteDoc(doc)
                    }
                }
            }
            .listStyle(.plain)
            
            Button(action: viewModel.addNewDocument)
            {
                Text("Добавить")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            .padding()
        }
//        .navigationTitle("Список документов")
    }
}
