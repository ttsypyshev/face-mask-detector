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
                VStack {
                    HStack {
                        Spacer()
                        Button(action: {
                            viewModel.switchCamera()
                        }) {
                            Image(systemName: "arrow.triangle.2.circlepath.camera")
                                .resizable()
                                .frame(width: 30, height: 25)
                                .padding()
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                                .foregroundColor(.white)
                        }
                        .padding(.trailing, 16)
                        .padding(.top, 60)
                    }
                    Spacer()
                    StatusView(text: viewModel.detectionStatus)
                        .padding(.bottom)
                }
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
            .id(text)
            .font(.title2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding()
            .background(Color.black.opacity(0.6))
            .cornerRadius(10)
            .transition(.opacity.combined(with: .move(edge: .bottom)))
            .animation(.easeInOut, value: text)
            .padding(.bottom, 20)
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
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var currentInput: AVCaptureDeviceInput?

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
        session.inputs.forEach { session.removeInput($0) }
        configureInput()
        configureOutput()
        session.commitConfiguration()

        setupDetector()

        DispatchQueue.global(qos: .userInitiated).async {
            self.session.startRunning()
        }
    }

    private func configureInput() {
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: currentCameraPosition) else {
            logger.error("Камера не найдена")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
                currentInput = input
            }
        } catch {
            logger.error("Ошибка при создании входа камеры: \(error.localizedDescription)")
        }
    }

    private func configureOutput() {
        session.outputs.forEach { session.removeOutput($0) }

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

    // MARK: - Switch Camera

    func switchCamera() {
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        setupCamera()
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
