import SwiftUI

struct SpecPickerSheet: View {
    let specs: [Characteristic]
    let onSelect: (Characteristic) -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List(specs, id: \.uuid1C) { spec in
                Button(action: { onSelect(spec) }) {
                    HStack {
                        Text(spec.name)
                            .foregroundColor(.primary)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.footnote)
                            .foregroundColor(.gray)
                    }
                }
            }
            .navigationTitle("Выберите характеристику")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена") { onDismiss() }
                }
            }
        }
    }
}
