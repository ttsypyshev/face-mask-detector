import AVFoundation
import os

final class CameraSessionManager {
    let session = AVCaptureSession()
    private let logger = Logger(subsystem: "CameraApp", category: "SessionManager")
    private var currentCameraPosition: AVCaptureDevice.Position = .back
    private var currentInput: AVCaptureDeviceInput?
    private var currentDelegate: AVCaptureVideoDataOutputSampleBufferDelegate?

    func setupSession(delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        currentDelegate = delegate

        session.beginConfiguration()
        clearSessionInputsAndOutputs()

        configureInput()
        configureOutput(delegate: delegate)

        session.commitConfiguration()

        session.startRunning()
    }

    func stopSession() {
        session.stopRunning()
    }

    func switchCamera() {
        currentCameraPosition = currentCameraPosition == .back ? .front : .back
        
        guard let delegate = currentDelegate else {
            logger.error("Попытка переключения камеры без установленного делегата")
            return
        }
        
        setupSession(delegate: delegate)
    }

    private func clearSessionInputsAndOutputs() {
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
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
            } else {
                logger.error("Не удалось добавить камеру как вход")
            }
        } catch {
            logger.error("Ошибка при создании входа камеры: \(error.localizedDescription)")
        }
    }

    private func configureOutput(delegate: AVCaptureVideoDataOutputSampleBufferDelegate) {
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        output.setSampleBufferDelegate(delegate, queue: DispatchQueue(label: "videoQueue"))
        
        if session.canAddOutput(output) {
            session.addOutput(output)
        } else {
            logger.error("Не удалось добавить видеовыход")
        }

        output.connection(with: .video)?.videoOrientation = .portrait
    }
}
