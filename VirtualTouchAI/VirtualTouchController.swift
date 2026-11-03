import Foundation
import CoreGraphics
import Combine
import AppKit

final class VirtualTouchController: ObservableObject {
    @Published var isTracking = false
    @Published var confidence: Double = 0
    @Published var predictedPoint: CGPoint = .zero
    @Published var clickDetected = false
    @Published var clickSensitivity = 0.55
    @Published var clickCooldown: TimeInterval = 1.0
    @Published var smoothing: Double = 0.72
    @Published var calibrationSampleCount = 0
    @Published var calibrationStatus = "No calibration samples"
    @Published var dwellClickEnabled = false
    @Published var accessibilityStatus = "Checking..."
    @Published var voiceClickEnabled = false
    @Published var voiceClickStatus = "Voice click is off"
    @Published var mirrorCameraX: Bool = UserDefaults.standard.object(forKey: "MirrorCameraX") as? Bool ?? true {
        didSet { UserDefaults.standard.set(mirrorCameraX, forKey: "MirrorCameraX") }
    }
    @Published var positionGuidance = "Position guidance will appear when tracking starts"
    @Published var gestureName = "Point"
    @Published var dragActive = false
    @Published var swipeName = "None"
    let gestureCatalog = [
        "Point", "Open Palm", "Fist", "Thumb Up", "Thumb Down",
        "Peace Sign", "Pinch", "Three Fingers", "Four Fingers", "L Shape",
        "Call Me", "OK Sign", "Finger Gun", "Wave", "Swipe Left",
        "Swipe Right", "Swipe Up", "Swipe Down", "Clap", "Stop Hand"
    ]

    let prediction = PredictionEngine()
    private let input = InputController()
    private var cancellables = Set<AnyCancellable>()
    private var lastClick = Date(timeIntervalSince1970: 0)
    private var previousWrist: CGPoint?
    private var previousTime: Date?
    private var previousVelocity: CGFloat = 0
    private var dwellStart: Date?
    private var dwellPoint: CGPoint?
    private var wristHistory: [CGPoint] = []
    private var targetHistory: [CGPoint] = []
    private var armExtensionHistory: [CGFloat] = []
    private let voice = VoiceClickRecognizer()
    private var pinchHistory: [Bool] = []
    private var gestureHistory: [String] = []
    private var lastSwipeTime = Date(timeIntervalSince1970: 0)
    private var flickCandidates: [CGFloat] = []

    init() {
        loadSamples()
        refreshAccessibilityStatus()
        voice.onClick = { [weak self] in
            guard let self, self.isTracking, Date().timeIntervalSince(self.lastClick) >= self.clickCooldown else { return }
            guard self.accessibilityTrusted else {
                self.voiceClickStatus = "Click voice command received, but Accessibility permission is required"
                self.requestAccessibility()
                return
            }
            self.performVoiceClick()
        }
        voice.onStop = { [weak self] in
            guard let self else { return }
            self.stop()
            FloatingOverlayController.shared.hide()
            NSApp.activate(ignoringOtherApps: true)
            self.voiceClickStatus = "Stopped by voice"
        }
    }

    func start() { isTracking = true }
    func stop() { isTracking = false }
    func endSession() {
        stop()
        voice.stop()
        FloatingOverlayController.shared.hide()
        NSApp.activate(ignoringOtherApps: true)
        positionGuidance = "Session ended — start VirtualTouch when ready"
    }

    func process(_ frame: PoseFrame) {
        guard isTracking else { return }
        guard let point = prediction.predict(frame: frame) else { confidence = 0; return }
        confidence = prediction.confidence
        updatePositionGuidance(frame)
        let boundedPoint = Self.boundsPoint(point)
        predictedPoint = boundedPoint
        input.move(to: boundedPoint)
        detectGesture(frame)
        detectClick(frame)
    }

    @discardableResult
    func addCalibrationSample(_ frame: PoseFrame, target: CGPoint) -> Bool {
        let added = prediction.addSample(frame: frame, screenPoint: target)
        if added {
            calibrationSampleCount = prediction.sampleCount
            calibrationStatus = "\(calibrationSampleCount) valid calibration samples"
        } else {
            calibrationStatus = "No usable wrist/arm landmarks detected. Hold still and try again."
        }
        return added
    }

    @discardableResult
    func saveCalibration() -> Bool {
        guard prediction.sampleCount >= 45 else {
            calibrationStatus = "Calibration needs at least 45 valid samples (5 per target)."
            return false
        }
        guard let data = try? JSONEncoder().encode(prediction.samples) else {
            calibrationStatus = "Calibration could not be encoded."
            return false
        }
        do {
            try data.write(to: calibrationURL, options: .atomic)
            calibrationStatus = "Calibration saved with \(prediction.sampleCount) samples"
            return true
        } catch {
            calibrationStatus = "Calibration could not be saved: \(error.localizedDescription)"
            return false
        }
    }

    func resetCalibration() {
        prediction.clear()
        calibrationSampleCount = 0
        calibrationStatus = "No calibration samples"
        try? FileManager.default.removeItem(at: calibrationURL)
    }

    var accessibilityTrusted: Bool { input.isAccessibilityTrusted() }
    func requestAccessibility() {
        input.requestAccessibility()
        refreshAccessibilityStatus()
    }
    func refreshAccessibilityStatus() {
        accessibilityStatus = input.isAccessibilityTrusted() ? "Accessibility permission granted" : "Accessibility permission required"
    }
    func testClick() { input.leftClick(at: predictedPoint == .zero ? CGPoint(x: NSScreen.main?.frame.midX ?? 100, y: NSScreen.main?.frame.midY ?? 100) : predictedPoint) }
    func testCursor() {
        guard accessibilityTrusted else { requestAccessibility(); return }
        let screen = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        input.move(to: CGPoint(x: screen.midX, y: screen.midY))
        predictedPoint = CGPoint(x: screen.midX, y: screen.midY)
        positionGuidance = "Cursor test moved the mouse to screen center"
    }
    func rightClick() { input.rightClick(at: predictedPoint) }
    func doubleClick() { input.doubleClick(at: predictedPoint) }

    func setVoiceClick(_ enabled: Bool) {
        voiceClickEnabled = enabled
        if enabled {
            voice.start { [weak self] allowed, status in
                self?.voiceClickStatus = status
                if !allowed { self?.voiceClickEnabled = false }
            }
        } else {
            voice.stop()
            voiceClickStatus = "Voice click is off"
        }
    }

    private func updatePositionGuidance(_ frame: PoseFrame) {
        guard let left = frame.leftShoulder, let right = frame.rightShoulder else {
            positionGuidance = "Move fully into frame and face the camera"
            return
        }
        let shoulderWidth = abs(left.x - right.x)
        let shoulderCenterX = (left.x + right.x) / 2
        let shoulderCenterY = (left.y + right.y) / 2
        var guidance: String
        if shoulderWidth < 0.16 {
            guidance = "Move closer to the camera"
        } else if shoulderWidth > 0.58 {
            guidance = "Move farther from the camera"
        } else if abs(shoulderCenterX - 0.5) > 0.12 {
            guidance = shoulderCenterX < 0.5 ? "Move slightly right to center your shoulders" : "Move slightly left to center your shoulders"
        } else if shoulderCenterY > 0.72 {
            guidance = "Lower your seating position or lower the camera"
        } else if shoulderCenterY < 0.24 {
            guidance = "Sit higher or raise the camera position"
        } else {
            guidance = "Position is good — keep your shoulders centered"
        }
        if frame.leftElbow == nil && frame.rightElbow == nil {
            guidance += "; raise an arm into view"
        } else if frame.indexTip == nil {
            guidance += "; finger optional, arm direction is active"
        }
        positionGuidance = guidance
    }

    private var calibrationURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("VirtualTouchAI", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("calibration.json")
    }

    private func loadSamples() {
        guard let data = try? Data(contentsOf: calibrationURL),
              let samples = try? JSONDecoder().decode([CalibrationSample].self, from: data) else { return }
        prediction.replaceSamples(samples)
        calibrationSampleCount = prediction.sampleCount
        calibrationStatus = "Calibration loaded with \(prediction.sampleCount) samples"
    }

    private static func boundsPoint(_ point: CGPoint) -> CGPoint {
        var bounds = CGRect.null
        for screen in NSScreen.screens {
            bounds = bounds.union(screen.frame)
        }
        if bounds == .null { bounds = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080) }
        return CGPoint(x: min(max(point.x, bounds.minX), bounds.maxX),
                       y: min(max(point.y, bounds.minY), bounds.maxY))
    }

    private func detectGesture(_ frame: PoseFrame) {
        wristHistory.append(frame.wrist ?? frame.indexTip ?? .zero)
        if wristHistory.count > 5 { wristHistory.removeFirst() }

        var pinchCandidate = false
        if let index = frame.indexTip, let thumb = frame.thumbTip {
            pinchCandidate = hypot(index.x - thumb.x, index.y - thumb.y) < 0.055
        }
        pinchHistory.append(pinchCandidate)
        if pinchHistory.count > 5 { pinchHistory.removeFirst() }
        let pinch = pinchHistory.count == 5 && pinchHistory.filter({ $0 }).count >= 4

        if pinch && confidence >= 0.90 && frame.indexTip != nil && frame.thumbTip != nil {
            gestureName = "Pinch / Drag"
            if !dragActive {
                input.dragDown(at: predictedPoint)
                dragActive = true
            } else {
                input.dragMove(to: predictedPoint)
            }
        } else if dragActive {
            input.dragUp(at: predictedPoint)
            dragActive = false
        }

        if wristHistory.count == 5 {
            let first = wristHistory.first ?? .zero
            let last = wristHistory.last ?? .zero
            let dx = last.x - first.x
            let dy = last.y - first.y
            let now = Date()
            if hypot(dx, dy) > 0.12 && now.timeIntervalSince(lastSwipeTime) > 0.8 && !pinch {
                lastSwipeTime = now
                if abs(dx) > abs(dy) {
                    swipeName = dx > 0 ? "Swipe Right" : "Swipe Left"
                    input.scroll(vertical: dx > 0 ? 3 : -3)
                } else {
                    swipeName = dy > 0 ? "Swipe Up" : "Swipe Down"
                    input.scroll(vertical: dy > 0 ? 3 : -3)
                }
            } else {
                swipeName = "None"
            }
        }

        if pinch {
            gestureName = "Pinch / Drag"
        } else if frame.indexTip != nil {
            gestureName = "Point"
        } else {
            gestureName = "Tracking Body"
        }
    }

    private func detectClick(_ frame: PoseFrame) {
        guard confidence >= clickSensitivity, let wrist = frame.wrist else {
            resetDwell(); return
        }
        let now = frame.timestamp

        if dwellClickEnabled {
            if let dwellPoint, hypot(predictedPoint.x - dwellPoint.x, predictedPoint.y - dwellPoint.y) < 24,
               let dwellStart, now.timeIntervalSince(dwellStart) >= 0.75,
               now.timeIntervalSince(lastClick) >= clickCooldown {
                performClick()
                resetDwell()
            } else if dwellPoint == nil || hypot(predictedPoint.x - dwellPoint!.x, predictedPoint.y - dwellPoint!.y) >= 24 {
                dwellPoint = predictedPoint
                dwellStart = now
            }
        } else {
            resetDwell()
        }

        wristHistory.append(wrist)
        targetHistory.append(predictedPoint)
        let shoulder = frame.leftShoulder ?? frame.rightShoulder
        let elbow = frame.leftElbow ?? frame.rightElbow
        let armExtension = shoulder == nil || elbow == nil ? CGFloat(0) : hypot(wrist.x - elbow!.x, wrist.y - elbow!.y)
        armExtensionHistory.append(armExtension)
        if wristHistory.count > 5 { wristHistory.removeFirst() }
        if targetHistory.count > 5 { targetHistory.removeFirst() }
        if armExtensionHistory.count > 5 { armExtensionHistory.removeFirst() }

        guard wristHistory.count >= 3 else {
            self.previousWrist = wrist; self.previousTime = now; return
        }
        let dt = CGFloat(max(0.02, now.timeIntervalSince(previousTime ?? now)))
        let speedValues = zip(wristHistory.dropFirst(), wristHistory).map { pair in
            CGFloat(hypot(pair.0.x - pair.1.x, pair.0.y - pair.1.y)) / max(dt, 0.02)
        }
        let peakSpeed = speedValues.max() ?? 0
        let accelerations = zip(speedValues.dropFirst(), speedValues).map { abs($0 - $1) }
        let peakAcceleration = accelerations.max() ?? 0
        let extensionChange = armExtensionHistory.count >= 2 ? abs((armExtensionHistory.last ?? 0) - (armExtensionHistory.first ?? 0)) : 0
        let targetMotion = targetHistory.count >= 2 ? hypot((targetHistory.last?.x ?? 0) - (targetHistory.first?.x ?? 0),
                                                              (targetHistory.last?.y ?? 0) - (targetHistory.first?.y ?? 0)) : 999

        let latestSpeed = speedValues.last ?? 0
        let previousSpeed = speedValues.count >= 2 ? speedValues[speedValues.count - 2] : latestSpeed
        let stoppingMotion = previousSpeed > latestSpeed * 1.35 && latestSpeed < 0.08
        let reversal = armExtensionHistory.count >= 3 &&
                       (armExtensionHistory.last ?? 0) < armExtensionHistory[armExtensionHistory.count - 2]
        let displacement = wristHistory.count >= 2 ?
            hypot((wristHistory.last?.x ?? 0) - (wristHistory.first?.x ?? 0),
                  (wristHistory.last?.y ?? 0) - (wristHistory.first?.y ?? 0)) : 0
        let pathBonus: CGFloat = stoppingMotion ? 0.12 : (displacement > 0.015 ? 0.06 : 0)
        let fingerBonus = frame.indexTip == nil ? 0.05 : 0.20
        let clickConfidence = confidence * 0.55 + fingerBonus * 0.45 + pathBonus
        let suddenJolt = peakSpeed > 0.10 && peakAcceleration > 0.10
        let potentialArmClick = (extensionChange > 0.018 || reversal) &&
                                (peakAcceleration > 0.055 || stoppingMotion)
        let stableTarget = targetMotion < 90
        let confidentClick = clickConfidence >= 0.90

        let latestFlickSpeed = speedValues.last ?? 0
        let priorFlickSpeed = speedValues.count >= 3 ? speedValues[speedValues.count - 3] : 0
        let flickAcceleration = latestFlickSpeed - priorFlickSpeed
        let velocityStopped = latestSpeed < 0.055 && previousSpeed > latestSpeed * 1.6
        flickCandidates.append(flickAcceleration)
        if flickCandidates.count > 5 { flickCandidates.removeFirst() }
        let flickPeak = flickCandidates.max() ?? 0
        let flickDetected = wristHistory.count == 5 && flickPeak > 0.075 &&
                            (stoppingMotion || velocityStopped) && displacement > 0.018 &&
                            stableTarget && confidentClick

        self.previousWrist = wrist
        self.previousTime = now
        self.previousVelocity = peakSpeed

        if (flickDetected || suddenJolt || (potentialArmClick && stableTarget)) && confidentClick &&
           now.timeIntervalSince(lastClick) >= clickCooldown {
            performClick()
        }
    }

    private func performVoiceClick() {
        lastClick = Date()
        clickDetected = true
        input.leftClick(at: input.currentMousePoint())
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.15) { self.clickDetected = false }
    }

    private func performClick() {
        lastClick = Date()
        clickDetected = true
        let clickPoint = predictedPoint == .zero ? input.currentMousePoint() : predictedPoint
        input.leftClick(at: clickPoint)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 0.15) { self.clickDetected = false }
    }

    private func resetDwell() { dwellStart = nil; dwellPoint = nil }
}
