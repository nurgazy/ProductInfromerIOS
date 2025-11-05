import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    
    @StateObject private var viewModel: SettingsViewModel
    
    @Binding var coordinatorPath: NavigationPath?
    @Binding var currentRoot: String
    @State private var selectedTab: SettingsTab = .general
    
    init(coordinatorPath: Binding<NavigationPath?> = .constant(nil), currentRoot: Binding<String>) {
        self._coordinatorPath = coordinatorPath
        self._currentRoot = currentRoot
        self._viewModel = StateObject(wrappedValue: SettingsViewModel(coordinatorPath:coordinatorPath, currentRoot: currentRoot))
    }
    
    var body: some View {
        // ⭐ Единый ZStack для закрепления кнопок внизу
        ZStack(alignment: .bottom) {
            
            // ⭐ 1. Основное прокручиваемое содержимое
            VStack(spacing: 0) {
                
                // ⭐ 2. Вкладки сверху (Picker в стиле Segmented)
                Picker("Настройки", selection: $selectedTab) {
                    ForEach(SettingsTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)

                contentForSelectedTab()
            }
            
            BottomButtons(saveAction: viewModel.saveAndNavigate, checkAction: viewModel.checkConnection)
        }
        .alert(viewModel.alertTitle, isPresented: $viewModel.showingAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(viewModel.alertMessage)
        }
        .navigationTitle("Настройки")
    }
    
    @ViewBuilder
    func contentForSelectedTab() -> some View {
        switch selectedTab {
        case .general:
            GeneralSettingsTab()
        case .additional:
            AdditionalSettingsTab()
        }
    }
    
    @ViewBuilder
    func GeneralSettingsTab() -> some View {
        Form{
            Group{
                HStack{
                    Text("Протокол")
                    Spacer()
                    Picker("", selection: $viewModel.protocolSelection) {
                        ForEach(viewModel.protocols, id: \.self) { Text($0) }
                    }
                    .onChange(of: viewModel.protocolSelection) { newProtocol in
                        viewModel.handleProtocolChange(newProtocol: newProtocol)
                    }
                }
                
                HStack{
                    Text("Сервер")
                    Spacer()
                    TextField("Сервер", text: $viewModel.serverAddress).autocapitalization(.none).keyboardType(.URL).multilineTextAlignment(.trailing)
                }
                
                HStack{
                    Text("Порт")
                    Spacer()
                    TextField("Порт", text:
                                Binding(
                                    get: { String(viewModel.port) }, set: {
                                        if let newPort = Int($0), newPort > 0, newPort <= 65535 { viewModel.port = newPort }
                                    }
                                ))
                    .keyboardType(.numberPad).multilineTextAlignment(.trailing)
                }
                
                HStack{
                    Text("Имя публикации")
                    Spacer()
                    TextField("Имя публикации", text: $viewModel.publicationName).autocapitalization(.none).multilineTextAlignment(.trailing)
                }
                
                // ⭐ Исправлено название поля: "Публикации" -> "Пользователь"
                HStack{
                    Text("Пользователь")
                    Spacer()
                    TextField("Пользователь", text: $viewModel.username).autocapitalization(.none).multilineTextAlignment(.trailing)
                }
                
                HStack{
                    Text("Пароль")
                    Spacer()
                    SecureField("Пароль", text: $viewModel.password).multilineTextAlignment(.trailing)
                }
            }
        }
    }
    
    @ViewBuilder
    func AdditionalSettingsTab() -> some View {
        Form {
            VStack{
                Toggle("Все характеристики", isOn: $viewModel.isFullSpecific)
            }
        }
    }
    
    @ViewBuilder
    func BottomButtons(saveAction: @escaping () -> Void, checkAction: @escaping () -> Void) -> some View {
        // ⭐ Убрали лишний Spacer() из VStack, который мешал ZStack
        VStack(spacing: 0) {
            Divider()
            HStack {
                Button("Проверить", action: checkAction).font(.headline)
                Spacer()
                Button("Готово", action: saveAction).font(.headline).bold()
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            .background(.ultraThinMaterial)
        }
    }
}

#Preview {
    struct SettingsViewPreview: View {
            // Создаем состояние для имитации внешних зависимостей
        @State private var mockCurrentRoot: String = "settings"
        @State private var mockNavigationPath: NavigationPath? = nil
        
        var body: some View {
            NavigationView {
                SettingsView(coordinatorPath: $mockNavigationPath, currentRoot: $mockCurrentRoot)
            }
        }
    }
    return SettingsViewPreview()
}
