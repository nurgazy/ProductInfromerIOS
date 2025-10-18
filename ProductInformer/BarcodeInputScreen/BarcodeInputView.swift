import SwiftUI

struct BarcodeInputView: View {

    @Binding var coordinatorPath: NavigationPath?
    @StateObject private var viewModel: BarcodeInputViewModel
    
    init(coordinatorPath: Binding<NavigationPath?> = .constant(nil)) {
        self._coordinatorPath = coordinatorPath
        self._viewModel = StateObject(wrappedValue: BarcodeInputViewModel(coordinatorPath: coordinatorPath))
    }
    
    var body: some View {
        // Обернем в NavigationStack, чтобы видеть заголовок
        
        VStack {
            
            Spacer()
            
            VStack(spacing: 15) {
                
                // 1. Поле для ввода штрихкода
                TextField("Введите штрихкод", text: $viewModel.barcode)
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    .keyboardType(.numberPad)
                    .autocorrectionDisabled(true)
                    .padding(.horizontal)
                
                // Горизонтальный стек для кнопок
                HStack(spacing: 15) {
                    
                    // 2. Кнопка "Сканировать"
                    Button {
                        viewModel.isScanning = true
                    } label: {
                        Label("Сканировать", systemImage: "barcode.viewfinder")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    // 3. Кнопка "Найти" (Обработать)
                    Button {
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
                
                if(viewModel.isSearching) {
                    ProgressView()
                }
                
            }
            .padding(.bottom, 40) // Отступ между кнопками и нижним краем
        }
        .padding(.top, 30)
        
        .alert("Ошибка поиска продукта", isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.alertMessage)
        }
        .navigationTitle("Ввод штрихкода")
    }

}

// Предпросмотр (Preview)
#Preview {
    BarcodeInputView()
}
