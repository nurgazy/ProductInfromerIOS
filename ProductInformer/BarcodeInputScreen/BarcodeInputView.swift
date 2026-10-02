import SwiftUI

struct BarcodeInputView: View {

    @Binding var coordinatorPath: NavigationPath?
    @StateObject private var viewModel: BarcodeInputViewModel
    
    // Управление фокусом клавиатуры
    @FocusState private var isInputActive: Bool
    
    init(coordinatorPath: Binding<NavigationPath?> = .constant(nil)) {
        self._coordinatorPath = coordinatorPath
        self._viewModel = StateObject(wrappedValue: BarcodeInputViewModel(coordinatorPath: coordinatorPath))
    }
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 15) {
                
                TextField("Введите штрихкод", text: $viewModel.barcode)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled(true)
                    .focused($isInputActive) // Привязка фокуса
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Готово") {
                                isInputActive = false // Скрывает цифровую клавиатуру
                            }
                        }
                    }
                    .padding(.horizontal)
                
                HStack(spacing: 15) {
                    Button {
                        isInputActive = false // Скрываем клавиатуру перед открытием сканера
                        viewModel.isScanning = true
                    } label: {
                        Label("Сканировать", systemImage: "barcode.viewfinder")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(viewModel.isSearching)
                    
                    Button {
                        isInputActive = false // Скрываем клавиатуру при запуске поиска
                        viewModel.findProduct()
                    } label: {
                        Label("Найти", systemImage: "magnifyingglass")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(viewModel.isSearching)
                }
                .padding(.horizontal)
                
                if viewModel.isSearching {
                    ProgressView()
                }
                
            }
            .padding(.bottom, 40)
        }
        .padding(.top, 30)
        // Закрытие клавиатуры при тапе в любое пустое место экрана
        .contentShape(Rectangle())
        .onTapGesture {
            isInputActive = false
        }
        .modifier(ProductDetailNavigationModifier(viewModel: viewModel))
        .sheet(isPresented: $viewModel.isScanning) {
            MLKitScannerView { result in
                guard !viewModel.isSearching else { return }
                
                switch result {
                case .success(let code):
                    viewModel.barcode = code
                    viewModel.isScanning = false
                    viewModel.findProduct()
                case .failure(let error):
                    viewModel.isScanning = false
                    viewModel.alertMessage = "Ошибка сканера: \(error)"
                    viewModel.showingAlert = true
                }
            }
            .ignoresSafeArea()
        }
        .alert("Ошибка поиска продукта", isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .navigationTitle("Ввод штрихкода")
    }
}

private struct ProductDetailNavigationModifier: ViewModifier {
    @ObservedObject var viewModel: BarcodeInputViewModel

    func body(content: Content) -> some View {
        if #available(iOS 16.0, *) {
            content
                .navigationDestination(isPresented: $viewModel.isActiveLink) {
                    ProductDetailView(productString: viewModel.productDetailJSONString ?? "")
                }
        } else {
            content
                .background(
                    NavigationLink(
                        destination: ProductDetailView(productString: viewModel.productDetailJSONString ?? ""),
                        isActive: $viewModel.isActiveLink,
                        label: { EmptyView() }
                    )
                    .hidden()
                )
        }
    }
}

#Preview {
    BarcodeInputView()
}
