import AppKit
import AVFoundation
import CoreImage

/// Owns only a local camera preview. It never computes or emits vital signs.
final class CameraPreviewCapture: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, @unchecked Sendable {
    private let queue = DispatchQueue(label: "app.afterburn.camera-preview")
    private let context = CIContext(options: [.cacheIntermediates: false])
    private var session: AVCaptureSession?
    private var frameHandler: ((NSImage) -> Void)?
    private var frameCount = 0
    private let deliveryLock = NSLock()
    private var framePending = false

    static func cameras() -> [ABCamera] {
        AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
            mediaType: .video, position: .unspecified).devices.map { device in
                let camera = ABCamera()
                camera.identifier = device.uniqueID
                camera.name = device.localizedName
                return camera
            }
    }

    func start(cameraID: String, onFrame: @escaping (NSImage) -> Void) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async { [self] in
                do {
                    closeOnQueue()
                    let devices = AVCaptureDevice.DiscoverySession(
                        deviceTypes: [.builtInWideAngleCamera, .external, .continuityCamera],
                        mediaType: .video, position: .unspecified).devices
                    let device = cameraID.isEmpty ? (AVCaptureDevice.default(for: .video) ?? devices.first)
                        : devices.first { $0.uniqueID == cameraID }
                    guard let device else { throw CameraError.unavailable }
                    let capture = AVCaptureSession()
                    capture.beginConfiguration()
                    if capture.canSetSessionPreset(.hd1280x720) { capture.sessionPreset = .hd1280x720 }
                    let input = try AVCaptureDeviceInput(device: device)
                    guard capture.canAddInput(input) else { throw CameraError.unavailable }
                    capture.addInput(input)
                    let output = AVCaptureVideoDataOutput()
                    output.alwaysDiscardsLateVideoFrames = true
                    output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
                    output.setSampleBufferDelegate(self, queue: queue)
                    guard capture.canAddOutput(output) else { throw CameraError.unavailable }
                    capture.addOutput(output)
                    capture.commitConfiguration()
                    frameHandler = onFrame
                    session = capture
                    capture.startRunning()
                    guard capture.isRunning else { closeOnQueue(); throw CameraError.unavailable }
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }

    func stop() { queue.async { [self] in closeOnQueue() } }

    func stopAndWait() async {
        await withCheckedContinuation { continuation in
            queue.async { [self] in closeOnQueue(); continuation.resume() }
        }
    }

    private func closeOnQueue() {
        session?.stopRunning()
        session = nil
        frameHandler = nil
        frameCount = 0
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        frameCount += 1
        guard frameCount.isMultiple(of: 2), let handler = frameHandler,
              let pixels = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        deliveryLock.lock()
        guard !framePending else { deliveryLock.unlock(); return }
        framePending = true
        deliveryLock.unlock()
        let source = CIImage(cvPixelBuffer: pixels)
        guard let image = context.createCGImage(source, from: source.extent) else {
            deliveryLock.lock(); framePending = false; deliveryLock.unlock()
            return
        }
        let preview = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
        DispatchQueue.main.async { [self] in
            handler(preview)
            deliveryLock.lock(); framePending = false; deliveryLock.unlock()
        }
    }

    enum CameraError: LocalizedError {
        case unavailable
        var errorDescription: String? { "The selected camera could not be opened. Close other camera apps or choose a different camera, then try again." }
    }
}
