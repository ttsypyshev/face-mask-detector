import SwiftUI
import AVFoundation
import CoreImage
import os

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var viewModel = CameraViewModel()
    
    var body: some View {
        ZStack {
            Group {
                if viewModel.hasAccess {
                    CameraPreviewView(session: viewModel.session)
                } else {
                    VStack {
                        Spacer()
                        Text("Пожалуйста, разрешите доступ к камере в настройках")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding()
                        Spacer()
                    }
                    .background(Color.black)
                }
            }
            .overlay(
                StatusView(text: viewModel.detectionStatus)
                    .padding(),
                alignment: .bottom
            )
        }
        .ignoresSafeArea()
        .onAppear { viewModel.configure() }
        .onDisappear { viewModel.stopSession() }
    }
}

// MARK: - StatusView

struct StatusView: View {
    let text: String
    
    var body: some View {
        Text(text)
            .id(text) // Анимация при смене текста
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(10)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeInOut, value: text)
    }
}

// MARK: - CameraPreviewView

struct CameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession
    var videoGravity: AVLayerVideoGravity = .resizeAspectFill
    
    func makeUIView(context: Context) -> UIView {
        PreviewView(session: session, videoGravity: videoGravity)
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

final class PreviewView: UIView {
    private var previewLayer: AVCaptureVideoPreviewLayer

    init(session: AVCaptureSession, videoGravity: AVLayerVideoGravity) {
        self.previewLayer = AVCaptureVideoPreviewLayer(session: session)
        self.previewLayer.videoGravity = videoGravity
        super.init(frame: .zero)
        layer.addSublayer(previewLayer)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer.frame = bounds
    }
}

// MARK: - CameraViewModel

@MainActor
final class CameraViewModel: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var detectionStatus: String = "Ожидание..."
    @Published var hasAccess: Bool = true

    let session = AVCaptureSession()
    private static let ciContext = CIContext()
    private let logger = Logger(subsystem: "CameraApp", category: "CameraViewModel")
    private var detector: MaskDetectionVideoHelper?
    private var lastUpdate = Date()

    func configure() {
        AVCaptureDevice.requestAccess(for: .video) { granted in
            DispatchQueue.main.async {
                self.hasAccess = granted
                if granted {
                    self.setupCamera()
                } else {
                    self.detectionStatus = "Нет доступа к камере"
                }
            }
        }
    }

    func stopSession() {
        session.stopRunning()
    }

    // MARK: - Camera Setup

    private func setupCamera() {
        session.beginConfiguration()
        configureInput()
        configureOutput()
        session.commitConfiguration()

        setupDetector()

        // Call startRunning on a background thread to avoid UI unresponsiveness
        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    private func configureInput() {
        guard let camera = AVCaptureDevice.default(for: .video) else {
            logger.error("Камера не найдена")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        } catch {
            logger.error("Ошибка при создании входа камеры: \(error.localizedDescription)")
        }
    }

    private func configureOutput() {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "videoQueue"))
        if session.canAddOutput(output) {
            session.addOutput(output)
        }
        output.connection(with: .video)?.videoOrientation = .portrait
    }

    private func setupDetector() {
        let detector = MaskDetector(minConfidence: 0.8)
        self.detector = MaskDetectionVideoHelper(maskDetector: detector, resizeMode: .centerCrop)
    }

    // MARK: - Frame Processing

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let detector = detector else { return }

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let results = try detector.detectInFrame(sampleBuffer)
                let now = Date()

                if now.timeIntervalSince(self.lastUpdate) > 0.5 {
                    let newStatus: String

                    if results.isEmpty {
                        newStatus = "Лицо не найдено"
                    } else {
                        let statusText = results.map { result -> String in
                            switch result.status {
                            case .mask:
                                return "В маске 😷"
                            case .noMask:
                                return "Без маски ❌"
                            }
                        }.joined(separator: ", ")
                        newStatus = "\(results.count) лиц(а): \(statusText)"
                    }

                    if newStatus != self.detectionStatus {
                        DispatchQueue.main.async {
                            self.detectionStatus = newStatus
                            self.lastUpdate = now
                        }
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.detectionStatus = "Ошибка анализа"
                }
                self.logger.error("Ошибка детекции: \(error.localizedDescription)")
            }
        }
    }
}
