import Foundation
import SwiftUI
import Combine
import GRDB
import KeychainAccess

@MainActor
class BarcodeDetailVM: ObservableObject {
    @Published var barcodeList: [BarcodeDocDetail] = []
    @Published var curBarcodeDoc: BarcodeDoc?
    @Published var curBarcodeDocDetail: BarcodeDocDetail?
    @Published var showQuantityDialog = false
    @Published var showScanner = false
    @Published var isUploading = false
    @Published var alertMessage: String = ""
    @Published var showingAlert: Bool = false
    @Published var isSearching: Bool = false
    @Published var searchText: String = ""
    
    private let dbQueue: DatabaseQueue = AppDatabase.shared.dbQueue
    private var cancellables = Set<AnyCancellable>()
    private var barcodeDocId: Int64?
    private var coordinatorPath: Binding<NavigationPath?>
    private var connectionSettings: ConnectionSettings
    
    var lastScannedBarcode: String = ""

    // Вычисляемое свойство для фильтрации списка
    var filteredBarcodeList: [BarcodeDocDetail] {
        if searchText.isEmpty {
            return barcodeList
        } else {
            return barcodeList.filter { item in
                item.productName.localizedCaseInsensitiveContains(searchText) ||
                item.barcode.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var isUploaded: Bool {
        return curBarcodeDoc?.status == "UPLOADED"
    }

    init(barcodeDocId: Int64?, coordinatorPath: Binding<NavigationPath?>) {
        self.coordinatorPath = coordinatorPath
        self.barcodeDocId = (barcodeDocId == 0) ? nil : barcodeDocId
        self.connectionSettings = BarcodeDetailVM.loadConnectionSettings()
        if self.barcodeDocId != nil {
            loadData()
        }
        
    }
    
    private static func loadConnectionSettings() -> ConnectionSettings {
        let defaults = UserDefaults.standard
        let keychain = Keychain(service: Bundle.main.bundleIdentifier ?? "com.productinformer.keys")
        
        let protocolSelection = defaults.string(forKey: SettingKeys.protocolSelection) ?? "HTTPS"
        let serverAddress = defaults.string(forKey: SettingKeys.serverAddress) ?? ""
        let savedPort = defaults.integer(forKey: SettingKeys.port)
        let port = savedPort > 0 ? savedPort : 443
        let publicationName = defaults.string(forKey: SettingKeys.publicationName) ?? ""
        let username = defaults.string(forKey: SettingKeys.username) ?? ""
        let password = keychain[SettingKeys.password] ?? ""
        let isFullSpecific = defaults.bool(forKey: SettingKeys.isFullSpecific)
        
        return ConnectionSettings(
            protocolSelection: protocolSelection,
            serverAddress: serverAddress,
            port: port,
            publicationName: publicationName,
            username: username,
            password: password,
            isFullSpecific: isFullSpecific
        )
    }

    func loadData() {
        guard let id = barcodeDocId else { return }
        
        try? dbQueue.read { db in
            self.curBarcodeDoc = try BarcodeDoc.fetchOne(db, key: id)
        }
        
        ValueObservation.tracking { db in
            try BarcodeDocDetail.filter(Column("barcodeDocId") == id).fetchAll(db)
        }.publisher(in: dbQueue)
        .sink(receiveCompletion: { _ in }, receiveValue: { [weak self] items in
            self?.barcodeList = items
        })
        .store(in: &cancellables)
    }

    func saveDoc() {
        do {
            try dbQueue.write { db in
                var currentID: Int64
                var doc: BarcodeDoc
                
                if let existingDoc = self.curBarcodeDoc {
                    doc = existingDoc
                    doc.creationTimestamp = Date()
                    try doc.save(db)
                    guard let id = doc.barcodeDocId else {
                        throw DatabaseError.idGenerationFailed
                    }
                    currentID = id
                } else {
                    doc = BarcodeDoc(
                        barcodeDocId: nil,
                        status: "ACTIVE",
                        uuid1C: "",
                        creationTimestamp: Date()
                    )
                    
                    if let savedDoc = try doc.insertAndFetch(db) {
                        guard let id = savedDoc.barcodeDocId else {
                            throw DatabaseError.idGenerationFailed
                        }
                        currentID = id
                    } else {
                        throw DatabaseError.idGenerationFailed
                    }
                }

                try BarcodeDocDetail.filter(Column("barcodeDocId") == currentID).deleteAll(db)

                for var item in barcodeList {
                    item.barcodeDocId = currentID
                    item.barcodeDetailId = nil
                    try item.insert(db)
                }

                // 3. Обновляем UI в главном потоке
                Task { @MainActor in
                    self.barcodeDocId = currentID
                    self.curBarcodeDoc = doc
                    self.loadData()
                }
            }
        } catch {
            Task { @MainActor in
                self.alertMessage = "Ошибка БД: \(error.localizedDescription)"
                self.showingAlert = true
            }
        }
    }

    func deleteItem(_ item: BarcodeDocDetail) {
        barcodeList.removeAll { $0.barcode == item.barcode && $0.barcodeDetailId == item.barcodeDetailId }
    }
    
    func handleScanResult(result: Result<String, CodeScannerView.ScannerError>) {
        DispatchQueue.main.async{
            self.showScanner = false
            
            switch result {
            case .success(let code):
                self.lastScannedBarcode = code
                self.findProduct(barcode: code)
            case .failure(let error):
                if error == .simulatedError {
                    return
                }
                self.alertMessage = "Сканирование: \(error.localizedDescription)"
                self.showingAlert = true
            }
        }
    }
    
    func findProduct(barcode: String) {
        
        self.curBarcodeDocDetail = nil
        
        guard !barcode.isEmpty else {
            self.alertMessage =  "❌ Введите или отсканируйте штрихкод."
            self.showingAlert = true
            return
        }
        
        self.lastScannedBarcode = barcode
        
        guard let url = buildSearchURL(barcode: barcode) else {
            self.alertMessage =  "❌ Невозможно построить корректный URL."
            self.showingAlert = true
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let authString = "\(connectionSettings.username):\(connectionSettings.password)"
        if let data = authString.data(using: .utf8) {
            let base64Auth = data.base64EncodedString()
            request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
        }

        Task {
            await MainActor.run {
                self.isSearching = true
                self.showingAlert = false
                self.alertMessage = ""
            }
            
            defer {
                Task { @MainActor in self.isSearching = false } // 🟢 END LOADING
            }
            
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw URLError(.badServerResponse)
                }
                
                guard let jsonString = String(data: data, encoding: .utf8) else {
                    await MainActor.run {
                        self.alertMessage = "❌ Ошибка: Не удалось прочитать ответ сервера как тек."
                        self.showingAlert = true
                    }
                    return
                }
                
                await MainActor.run {
                    if httpResponse.statusCode == 200 {
                        
                        if let jsonData = jsonString.data(using: .utf8) {
                            do {
                                let decoder = JSONDecoder()
                                let productResponse = try decoder.decode(ProductResponse.self, from: jsonData)
                                if !productResponse.result{
                                    self.alertMessage = "Товар не найден."
                                    self.showingAlert = true
                                }else{
                                    let newDetail = self.getBarcodeDocDetail(productData: productResponse)
                                    if var finalDetail = newDetail {
                                        finalDetail.barcode = barcode
                                        self.curBarcodeDocDetail = finalDetail
                                    }
                                    self.showQuantityDialog = true
                                }
                            } catch {
                                self.alertMessage = "❌ Ошибка декодирования: \(error.localizedDescription)"
                                self.showingAlert = true
                            }
                        } else {
                            self.alertMessage = "Не удалось преобразовать данные."
                            self.showingAlert = true
                        }
                        
                        if self.showingAlert { return }
                        
                    } else if httpResponse.statusCode == 401 {
                        self.alertMessage = "❌ Ошибка 401: Неверный пользователь/пароль. Проверьте настройки подключения."
                        self.showingAlert = true
                    } else {
                        self.alertMessage = "⚠️ Ошибка сервера: Код \(httpResponse.statusCode). Ответ: \(jsonString.prefix(100))..."
                        self.showingAlert = true
                    }
                }
            } catch {
                await MainActor.run {
                    self.alertMessage = "❌ Не удалось подключиться к \(self.connectionSettings.serverAddress). Причина: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }
    
    private func buildSearchURL(barcode: String) -> URL? {
        // Базовый путь остается прежним
        let basePath = "/hs/ProductInformation/Info"
        
        var components = URLComponents()
        components.scheme = connectionSettings.protocolSelection.lowercased()
        components.host = connectionSettings.serverAddress
        components.port = connectionSettings.port
        components.path = "/\(connectionSettings.publicationName)\(basePath)"
        
        var queryItems = [
            URLQueryItem(name: "barcode", value: barcode)
        ]
        queryItems.append(
            URLQueryItem(name: "full", value: "false")
        )

        components.queryItems = queryItems

        return components.url
    }
    
    func addProductWithQuantity(_ qty: Int) {
        guard var itemToSave = self.curBarcodeDocDetail else { return }
        if let index = barcodeList.firstIndex(where: {
            $0.barcode == itemToSave.barcode &&
            $0.productSpecUuid1C == itemToSave.productSpecUuid1C
        }) {
            barcodeList[index].quantity += qty
        } else {
            itemToSave.quantity = qty
            self.barcodeList.append(itemToSave)
        }
        
        self.curBarcodeDocDetail = nil
        self.showQuantityDialog = false
    }
    
    private func getBarcodeDocDetail(productData: ProductResponse?) -> BarcodeDocDetail? {
        guard let product = productData else { return nil }
        
        let firstChar = product.characteristics?.first
        let nomenclature = product.nomenclature
        let barcodeDocDetail = BarcodeDocDetail(
            barcodeDetailId: nil,
            barcode: nomenclature.barcode,
            productName: nomenclature.name,
            productSpecName: firstChar?.name ?? "",
            productUuid1C: nomenclature.uuid1с,
            productSpecUuid1C: firstChar?.uuid1C ?? "",
            barcodeDocId: self.barcodeDocId ?? 0,
            quantity: 1
        )
        
        return barcodeDocDetail
    }
    
    func uploadTo1C() {
        // 1. Проверки перед отправкой
        guard let docId = self.barcodeDocId, !barcodeList.isEmpty else {
            self.alertMessage = "Документ не сохранен или список товаров пуст"
            self.showingAlert = true
            return
        }

        self.isUploading = true
        
        let uploadItems = barcodeList.map { item in
            BarcodeDocumentItemUpload(
                name: item.productName,
                barcode: item.barcode,
                quantity: item.quantity,
                productUuid1C: item.productUuid1C,
                productSpecUuid1C: item.productSpecUuid1C
            )
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss" // Формат, который 1С воспринимает идеально
        formatter.locale = Locale(identifier: "en_US_POSIX") // Чтобы избежать проблем с 12/24 часовым форматом

        let dateStringFor1C = formatter.string(from: curBarcodeDoc?.creationTimestamp ?? Date())
        
        let uploadData = BarcodeDocumentUpload(
            internalId: docId,
            uuid1C: curBarcodeDoc?.uuid1C ?? "",
            username: connectionSettings.username,
            docDate: dateStringFor1C,
            items: uploadItems
        )

        Task {
            do {
                // 2. Формируем URL (базовый путь из вашего VM)
                guard let url = constructUploadURL() else { return }
                
                var request = URLRequest(url: url)
                request.httpMethod = "POST"
                request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                
                let authString = "\(connectionSettings.username):\(connectionSettings.password)"
                if let data = authString.data(using: .utf8) {
                    let base64Auth = data.base64EncodedString()
                    request.setValue("Basic \(base64Auth)", forHTTPHeaderField: "Authorization")
                }
                
                request.httpBody = try JSONEncoder().encode(uploadData)

                // 3. Отправка
                let (_, response) = try await URLSession.shared.data(for: request)
                
                if let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) {
                    // 4. Успех: Обновляем статус в локальной БД
                    try await dbQueue.write { db in
                        if var doc = try BarcodeDoc.fetchOne(db, key: docId) {
                            doc.status = "UPLOADED"
                            try doc.update(db)
                            
                        }
                    }
                    
                    await MainActor.run {
                        self.isUploading = false
                        self.curBarcodeDoc?.status = "UPLOADED"
                    }
                    
                } else {
                    throw URLError(.badServerResponse)
                }
            } catch {
                await MainActor.run {
                    self.isUploading = false
                    self.alertMessage = "Ошибка выгрузки: \(error.localizedDescription)"
                    self.showingAlert = true
                }
            }
        }
    }

    // Вспомогательный метод для URL
    private func constructUploadURL() -> URL? {
        
        let basePath = "/hs/ProductInformation/Document"
        
        var components = URLComponents()
        components.scheme = connectionSettings.protocolSelection.lowercased()
        components.host = connectionSettings.serverAddress
        components.port = connectionSettings.port
        components.path = "/\(connectionSettings.publicationName)\(basePath)"

        return components.url
    }
    
}

enum DatabaseError: Error {
    case idGenerationFailed
}
