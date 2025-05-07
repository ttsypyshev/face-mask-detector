import SwiftUI

struct CameraControlsView: View {
    var switchCameraAction: () -> Void
    var detectionStatus: String

    var body: some View {
        VStack {
            HStack {
                Spacer()
                switchCameraButton
            }
            Spacer()
            StatusView(text: detectionStatus)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: detectionStatus)
                .padding(.bottom)
        }
    }

    private var switchCameraButton: some View {
        Button(action: switchCameraAction) {
            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .resizable()
                .frame(width: 30, height: 25)
                .padding()
                .background(Color.black.opacity(0.5))
                .clipShape(Circle())
                .foregroundColor(.white)
                .accessibilityLabel("Switch Camera")
        }
        .padding(.trailing, 16)
        .padding(.top, 60)
    }
}
