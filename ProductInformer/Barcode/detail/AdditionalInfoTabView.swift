import SwiftUI

struct AdditionalInfoTabView: View {
    @ObservedObject var viewModel: BarcodeDetailVM
    
    var body: some View {
        VStack(spacing: 0) {
            Text("Комментарий к документу")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding([.horizontal, .top])

            TextEditor(text: $viewModel.commentText)
            .padding(4)
            .background(Color(.systemBackground))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .padding()
            
            Spacer()
        }
    }
}
