import AVFoundation
import Vision
import Combine
import CoreGraphics
import AppKit

struct PoseFrame: Equatable {
    let leftShoulder: CGPoint?
    let rightShoulder: CGPoint?
    let leftElbow: CGPoint?
    let rightElbow: CGPoint?
    let leftWrist: CGPoint?
    let rightWrist: CGPoint?
    let indexTip: CGPoint?
    let thumbTip: CGPoint?
    let confidence: Double
    let timestamp: Date

    var wrist: CGPoint? {
        if let leftWrist, let rightWrist {
            return CGPoint(x: (leftWrist.x + rightWrist.x) / 2, y: (leftWrist.y + rightWrist.y) / 2)
        }
        return leftWrist ?? rightWrist
    }

    static let empty = PoseFrame(leftShoulder: nil, rightShoulder: nil, leftElbow: nil, rightElbow: nil, leftWrist: nil, rightWrist: nil, indexTip: nil, thumbTip: nil, confidence: 0, timestamp: Date())
}

final class CameraController: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    @Published var isRunning = false
    @Published var permissionGranted = false
    @Published var status = "Camera not started"
    @Published var latestFrame: PoseFrame = .empty
    @Published var fps: Double = 0

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "VirtualTouch.camera", qos: .userInitiated)
    private var frames = 0
    private var fpsStart = Date()
    private var lastProcessed = Date(timeIntervalSince1970: 0)
    private var previousIndexTip: CGPoint?
    let targetFPS = 35.0

    func makePreviewLayer() -> AVCaptureVideoPreviewLayer {
        precondition(Thread.isMainThread, "Camera preview must be created on the main thread")
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        return preview
    }

    override init() {
        super.init()
        output.alwaysDiscardsLateVideoFrames = true
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }

    func requestAccess() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            permissionGranted = true
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.permissionGranted = granted
                    if granted { self?.configureSession() }
                }
            }
        default:
            permissionGranted = false
            status = "Camera permission denied"
        }
    }

    func configureSession() {
        dispatchPrecondition(condition: .notOnQueue(queue))
        guard !session.inputs.isEmpty else {
            session.beginConfiguration()
            session.sessionPreset = .vga640x480
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device) else {
                session.commitConfiguration()
                DispatchQueue.main.async { self.status = "No camera found" }
                return
            }
            if session.canAddInput(input) { session.addInput(input) }
            if session.canAddOutput(output) {
                output.setSampleBufferDelegate(self, queue: queue)
                session.addOutput(output)
            }
            session.commitConfiguration()
            return
        }
    }

    func start() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.start() }
            return
        }
        guard permissionGranted else { requestAccess(); return }
        configureSession()
        guard !session.isRunning else { return }
        session.startRunning()
        DispatchQueue.main.async { self.isRunning = true; self.status = "Camera active" }
    }

    func stop() {
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in self?.stop() }
            return
        }
        guard session.isRunning else { return }
        session.stopRunning()
        DispatchQueue.main.async { self.isRunning = false; self.status = "Camera stopped" }
    }

    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessed) >= 1.0 / 35.0 else { return }
        lastProcessed = now
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let handRequest = VNDetectHumanHandPoseRequest()
        handRequest.maximumHandCount = 2
        let handler = VNImageRequestHandler(cvPixelBuffer: buffer, orientation: .up, options: [:])
        do {
            try handler.perform([handRequest])
            func point(_ value: VNRecognizedPoint?) -> CGPoint? {
                guard let value, value.confidence > 0.2 else { return nil }
                return CGPoint(x: value.x, y: value.y)
            }
            var indexTip: CGPoint?
            var thumbTip: CGPoint?
            if let hands = handRequest.results, !hands.isEmpty {
                let hand = hands.min { first, second in
                    func indexDistance(_ hand: VNHumanHandPoseObservation) -> CGFloat {
                        guard let tip = try? hand.recognizedPoint(.indexTip) else { return .greatestFiniteMagnitude }
                        let tipPoint = CGPoint(x: tip.location.x, y: tip.location.y)
                        guard let previousIndexTip else { return tip.confidence > 0.8 ? 0 : 999 }
                        return hypot(tipPoint.x - previousIndexTip.x, tipPoint.y - previousIndexTip.y)
                    }
                    return indexDistance(first) < indexDistance(second)
                }
                let index = try? hand?.recognizedPoint(.indexTip)
                let thumb = try? hand?.recognizedPoint(.thumbTip)
                if let index, index.confidence > 0.2 {
                    indexTip = CGPoint(x: index.location.x, y: index.location.y)
                    previousIndexTip = indexTip
                }
                if let thumb, thumb.confidence > 0.2 {
                    thumbTip = CGPoint(x: thumb.location.x, y: thumb.location.y)
                }
            }
            let fingerConfidence = indexTip == nil ? 0 : 0.85
            let frame = PoseFrame(leftShoulder: nil, rightShoulder: nil, leftElbow: nil, rightElbow: nil, leftWrist: indexTip, rightWrist: nil, indexTip: indexTip, thumbTip: thumbTip, confidence: fingerConfidence, timestamp: Date())
            DispatchQueue.main.async { self.latestFrame = frame }
            frames += 1
            if Date().timeIntervalSince(fpsStart) >= 1 {
                let currentFps = Double(frames) / Date().timeIntervalSince(fpsStart)
                frames = 0
                fpsStart = Date()
                DispatchQueue.main.async { self.fps = currentFps }
            }
        } catch {
            DispatchQueue.main.async { self.status = "Pose analysis failed: \(error.localizedDescription)" }
        }
    }
}
