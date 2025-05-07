import SwiftUI

struct CameraAccessDeniedView: View {
    var body: some View {
        VStack {
            Spacer()

            // Иконка с текстом
            Image(systemName: "camera.fill")
                .resizable()
                .frame(width: 50, height: 50)
                .foregroundColor(.white)
                .padding(.bottom, 20)

            Text("Пожалуйста, разрешите доступ к камере в настройках")
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .padding()

            Spacer()
        }
        .background(Color.black)
        .cornerRadius(15)
        .padding(16)
        .transition(.opacity)
        .animation(.easeInOut, value: UUID())
        .accessibilityLabel("Доступ к камере не предоставлен")
    }
}
