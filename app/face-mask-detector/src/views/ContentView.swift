import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()

    var body: some View {
        ZStack {
            Group {
                if viewModel.hasAccess {
                    CameraPreviewView(session: viewModel.session)
                } else {
                    CameraAccessDeniedView()
                }
            }
            .overlay(
                CameraControlsView(
                    switchCameraAction: { viewModel.switchCamera() },
                    detectionStatus: viewModel.detectionStatus
                )
            )
        }
        .ignoresSafeArea()
        .onAppear { viewModel.configure() }
        .onDisappear { viewModel.stopSession() }
    }
}
