import Foundation
import AVFoundation
import SwiftUI

@MainActor
final class CameraViewModel: NSObject, ObservableObject {
    @Published var detectionStatus: String = "Ожидание..."
    @Published var hasAccess: Bool = true

    let session: AVCaptureSession
    private let sessionManager: CameraSessionManager
    private let frameProcessor: FrameProcessor

    init(
        sessionManager: CameraSessionManager = CameraSessionManager(),
        frameProcessor: FrameProcessor = FrameProcessor()
    ) {
        self.sessionManager = sessionManager
        self.frameProcessor = frameProcessor
        self.session = sessionManager.session
        super.init()
        self.frameProcessor.delegate = self
    }

    func configure() {
        requestCameraAccess { granted in
            if granted {
                self.setupCameraSession()
            } else {
                self.handleAccessDenied()
            }
        }
    }

    private func requestCameraAccess(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.hasAccess = granted
                completion(granted)
            }
        }
    }

    private func setupCameraSession() {
        sessionManager.setupSession(delegate: frameProcessor)
    }

    private func handleAccessDenied() {
        detectionStatus = "Нет доступа к камере"
    }

    func stopSession() {
        sessionManager.stopSession()
    }

    func switchCamera() {
        sessionManager.switchCamera()
    }
}

extension CameraViewModel: FrameProcessorDelegate {
    func didUpdateStatus(_ status: String) {
        detectionStatus = status
    }
}
