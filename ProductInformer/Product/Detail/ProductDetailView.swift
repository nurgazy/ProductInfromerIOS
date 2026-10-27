import SwiftUI

struct ProductDetailView: View {
    
    let productString: String
    
    @State private var decodedProduct: ProductResponse?
    @State private var decodingError: String?
    @State private var selectedTab: Int = 1
    
    var body: some View {
        Group {
            if let product = decodedProduct {
                VStack(spacing: 0) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(product.nomenclature.name)
                            .font(.headline)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        
                        if let article = product.nomenclature.article, !article.isEmpty {
                            Text("Артикул: \(article)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    
                    // Предупреждение об отсутствии на складе
                    if (product.nomenclature.quantityBalance ?? 0) <= 0 {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Товар отсутствует на остатках")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color.orange.opacity(0.15))
                    }
                    
                    Divider()
                    
                    TabView(selection: $selectedTab) {
                        MainInfoTab(nomenclature: product.nomenclature)
                            .tabItem {
                                Label("Основное", systemImage: "info.circle")
                            }.tag(0)
                        
                        FullProductDetailList(product: product)
                            .tabItem {
                                Label("Детали", systemImage: "list.bullet")
                            }.tag(1)
                        
                        ProductImageTab(imageString: product.image, productName: product.nomenclature.name)
                            .tabItem {
                                Label("Картинка", systemImage: "photo")
                            }.tag(2)
                    }
                }
            } else if let error = decodingError {
                ErrorView(error: error, rawData: productString)
            } else {
                ProgressView("Обработка данных...")
            }
        }
        .onAppear {
            decodeProductData()
        }
    }
    
    private func decodeProductData() {
        guard decodedProduct == nil && decodingError == nil else { return }

        guard let data = productString.data(using: .utf8) else {
            decodingError = "Не удалось преобразовать строку в Data."
            return
        }
        
        do {
            let decoder = JSONDecoder()
            let response = try decoder.decode(ProductResponse.self, from: data)
            
            if response.result {
                self.decodedProduct = response
            } else {
                self.decodingError = "Товар не найден."
            }
        } catch {
            self.decodingError = "Ошибка декодирования JSON: \(error.localizedDescription).\nПроверьте, соответствуют ли модели данным."
            print("Ошибка декодирования: \(error)")
        }
    }
}

struct ErrorView: View {
    let error: String
    let rawData: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Произошла ошибка обработки данных")
                    .font(.title2)
                    .foregroundColor(.red)
                
                Text(error)
                    .font(.body)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                
                Text("Сырые данные (JSON):")
                    .font(.headline)
                
                Text(rawData)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                
                Spacer()
            }
            .padding()
        }
    }
}
