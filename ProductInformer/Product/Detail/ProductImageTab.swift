import SwiftUI

struct ProductImageTab: View {
    let imageString: String?
    let productName: String
    
    @State private var uiImage: UIImage? = nil
    
    var body: some View {
        VStack {
            if let image = uiImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else if imageString == nil || imageString!.isEmpty {
                if #available(iOS 17.0, *){
                    ContentUnavailableView(
                        "Изображение отсутствует",
                        systemImage: "photo.slash",
                        description: Text("Данные об изображении не предоставлены сервером.")
                    )
                }
                else{
                    VStack(spacing: 10) {
                        Image(systemName: "photo.slash")
                            .font(.largeTitle)
                            .foregroundColor(.gray)
                        Text("Изображение отсутствует")
                            .font(.headline)
                        Text("Данные об изображении не предоставлены сервером.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }
            } else {
                ProgressView("Загрузка изображения...")
            }
        }
        .onAppear {
            loadImage()
        }
    }
    
    // Логика декодирования Base64
    private func loadImage() {
        guard let base64String = imageString, !base64String.isEmpty else { return }
        
        // В вашем примере JSON строка начинается с "/9j/...", что является началом
        // Base64-кодировки JPEG-изображения.
        
        // 1. Преобразование Base64 строки в Data
        if let data = Data(base64Encoded: base64String, options: .ignoreUnknownCharacters) {
            // 2. Создание UIImage из Data
            if let image = UIImage(data: data) {
                self.uiImage = image
                return
            }
        }
        
        print("Не удалось декодировать Base64-изображение.")
    }
}
