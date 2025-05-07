import SwiftUI

struct StatusView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(10)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeInOut, value: text)
            .padding(.bottom, 20)
            .accessibilityLabel(Text("Status: \(text)"))
    }
}
