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
                List {
                    ForEach(Array(viewModel.barcodeList.enumerated()), id: \.element.barcodeDetailId) { index, item in
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
                        Label("Выгрузить", systemImage: "arrow.up.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isUploading || viewModel.barcodeList.isEmpty)
                }
                .padding()
            }
            
            // Overlay для диалога (Аналог if (showQuantityInputDialog))
            if viewModel.showQuantityDialog {
                Color.black.opacity(0.4).ignoresSafeArea()
                QuantityInputDialog(
                    barcode: viewModel.lastScannedBarcode,
                    quantity: $quantityText,
                    onConfirm: { qty in
                        viewModel.addProductWithQuantity(qty)
                    },
                    onDismiss: { viewModel.showQuantityDialog = false }
                )
            }
        }
        .navigationTitle("Документ №\(viewModel.curBarcodeDoc?.barcodeDocId ?? 0)")
        .alert("Статус выгрузки", isPresented: Binding(
            get: { viewModel.uploadStatusMessage != nil },
            set: { _ in viewModel.uploadStatusMessage = nil }
        )) {
            Button("ОК", role: .cancel) { }
        } message: {
            Text(viewModel.uploadStatusMessage ?? "")
        }
    }
}
