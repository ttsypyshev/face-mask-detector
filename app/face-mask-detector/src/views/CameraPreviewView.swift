import SwiftUI
import AVFoundation

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill

    func makeUIView(context: Context) -> UIView {
        PreviewView(session: session, videoGravity: videoGravity)
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewView = uiView as? PreviewView {
            previewView.avLayer.videoGravity = videoGravity
        }
    }
}

final class PreviewView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var avLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }

    init(session: AVCaptureSession, videoGravity: AVLayerVideoGravity) {
        super.init(frame: .zero)
        avLayer.session = session
        avLayer.videoGravity = videoGravity
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
