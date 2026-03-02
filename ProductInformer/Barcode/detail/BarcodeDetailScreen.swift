import SwiftUI

struct BarcodeDetailScreen: View {
    @Binding var coordinatorPath: NavigationPath?
    @StateObject var viewModel: BarcodeDetailVM
    @State private var quantityText = "1"
    
    init(barcodeDocId: Int64?, coordinatorPath: Binding<NavigationPath?>) {
        self._coordinatorPath = coordinatorPath
        self._viewModel = StateObject(wrappedValue: BarcodeDetailVM(
            barcodeDocId: barcodeDocId,
            coordinatorPath: coordinatorPath
        ))
    }
    
    var body: some View {
        ZStack {
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
                
                // Панель кнопок (Аналог нижнего Column в Kotlin)
                VStack(spacing: 12) {
                    HStack(spacing: 16) {
                        Button(action: {
                            viewModel.saveDoc()
                        }) {
                            Label("Сохранить", systemImage: "checkmark.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.blue)
                        
                        Button(action: { viewModel.showScanner = true }) {
                            Label("Сканер", systemImage: "barcode.viewfinder")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                    
                    Button(action: { viewModel.uploadTo1C() }) {
                        if viewModel.isUploading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Label(viewModel.isUploaded ? "Выгружено" : "Выгрузить",
                                  systemImage: viewModel.isUploaded ? "checkmark.seal.fill" : "arrow.up.doc")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isUploaded || viewModel.barcodeList.isEmpty)
                    .tint(viewModel.isUploaded ? .gray : .blue)
                }
                .padding()
            }
            
            if viewModel.showQuantityDialog, let item = viewModel.curBarcodeDocDetail {
                Color.black.opacity(0.4).ignoresSafeArea()
                QuantityInputDialog(
                    barcode: viewModel.lastScannedBarcode,
                    productName: item.productName,
                    quantity: $quantityText,
                    onConfirm: { qty in
                        viewModel.addProductWithQuantity(qty)
                    },
                    onDismiss: { viewModel.showQuantityDialog = false }
                )
            }
        }
        .sheet(isPresented: $viewModel.showScanner) {
            CodeScannerView { result in
                viewModel.handleScanResult(result: result)
            }
            .onDisappear {
                viewModel.showScanner = false
            }
            .ignoresSafeArea()
        }
        .alert("Внимание", isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .navigationTitle("Документ №\(viewModel.curBarcodeDoc?.barcodeDocId ?? 0)")
    }
}
