import AVFoundation
import os

protocol FrameProcessorDelegate: AnyObject {
    func didUpdateStatus(_ status: String)
}

final class FrameProcessor: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    private let detector = MaskDetectionVideoHelper(maskDetector: MaskDetector(minConfidence: 0.8), resizeMode: .centerCrop)
    private let logger = Logger(subsystem: "CameraApp", category: "FrameProcessor")
    private var lastUpdate = Date()

    weak var delegate: FrameProcessorDelegate?

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let results = try self.detector.detectInFrame(sampleBuffer)
                let now = Date()

                if now.timeIntervalSince(self.lastUpdate) > 0.5 {
                    let newStatus: String

                    if results.isEmpty {
                        newStatus = "Лицо не найдено"
                    } else {
                        let statusText = results.map { result -> String in
                            switch result.status {
                            case .mask: return "В маске 😷"
                            case .noMask: return "Без маски ❌"
                            }
                        }.joined(separator: ", ")
                        newStatus = "\(results.count) лиц(а): \(statusText)"
                    }

                    DispatchQueue.main.async {
                        self.delegate?.didUpdateStatus(newStatus)
                        self.lastUpdate = now
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.delegate?.didUpdateStatus("Ошибка анализа")
                }
                self.logger.error("Ошибка детекции: \(error.localizedDescription)")
            }
        }
    }
}
