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
                TabView {
                    ProductsTabView(viewModel: viewModel)
                        .tabItem {
                            Label("Товары", systemImage: "cart.fill")
                        }

                    AdditionalInfoTabView(viewModel: viewModel)
                        .tabItem {
                            Label("Доп. инфо", systemImage: "info.circle.fill")
                        }
                }
                
                Divider()
                actionButtons
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
        .sheet(isPresented: $viewModel.showSpecPicker) {
            SpecPickerSheet(
                specs: viewModel.availableSpecs,
                onSelect: { spec in
                    viewModel.selectCharacteristic(spec)
                },
                onDismiss: {
                    viewModel.showSpecPicker = false
                }
            )
            .presentationDetents([.medium, .large]) // Для iOS 16+ сделаем удобную шторку
        }
        .alert("Внимание", isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .navigationTitle("Документ №\(viewModel.curBarcodeDoc?.barcodeDocId ?? 0)")
    }
    
    private var actionButtons: some View {
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
            .disabled(viewModel.barcodeList.isEmpty || viewModel.isUploading)
            .tint(viewModel.isUploaded ? .gray : .blue)
        }
        .padding()
    }
}
