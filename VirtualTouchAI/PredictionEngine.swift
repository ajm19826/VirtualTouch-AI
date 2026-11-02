import Foundation
import CoreGraphics
import AppKit

struct CalibrationSample: Codable {
    var features: [Double]
    var targetX: Double
    var targetY: Double
}

final class PredictionEngine {
    private(set) var samples: [CalibrationSample] = []
    private(set) var confidence: Double = 0
    private var previous: CGPoint = .zero
    private var history: [CGPoint] = []
    var sampleCount: Int { samples.count }

    func clear() { samples.removeAll(keepingCapacity: true); confidence = 0; history.removeAll() }

    func replaceSamples(_ newSamples: [CalibrationSample]) {
        samples = newSamples
        confidence = min(1, Double(samples.count) / 45)
    }

    @discardableResult
    func addSample(frame: PoseFrame, screenPoint: CGPoint) -> Bool {
        guard let features = makeFeatures(frame), frame.confidence > 0.1 else { return false }
        let frameRect = NSScreen.main?.visibleFrame ?? NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
        let targetX = (screenPoint.x - frameRect.minX) / frameRect.width
        let targetY = (frameRect.maxY - screenPoint.y) / frameRect.height
        samples.append(CalibrationSample(features: features,
                                          targetX: Double(targetX.clamped(to: 0...1)),
                                          targetY: Double(targetY.clamped(to: 0...1))))
        confidence = min(1, Double(samples.count) / 45)
        return true
    }

    func predict(frame: PoseFrame) -> CGPoint? {
        if let finger = frame.indexTip {
            let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
            let point = CGPoint(x: screenFrame.minX + finger.x * screenFrame.width,
                                y: screenFrame.minY + finger.y * screenFrame.height)
            confidence = max(frame.confidence, 0.85)
            history.append(point)
            if history.count > 5 { history.removeFirst() }
            let distance = previous == .zero ? 1000 : hypot(point.x - previous.x, point.y - previous.y)
            let alpha: CGFloat = distance > 180 ? 0.82 : (distance > 45 ? 0.68 : 0.52)
            let pointer = CGPoint(x: previous == .zero ? point.x : previous.x + (point.x - previous.x) * alpha,
                                  y: previous == .zero ? point.y : previous.y + (point.y - previous.y) * alpha)
            previous = pointer
            return pointer
        }
        guard let features = makeFeatures(frame) else { confidence = 0; return nil }
        let firstPoint: CGPoint
        if samples.isEmpty {
            guard let wrist = frame.wrist ?? frame.indexTip else { return nil }
            let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
            let elbow = frame.leftElbow ?? frame.rightElbow ?? frame.leftShoulder ?? frame.rightShoulder ?? wrist
            let forearmDx = wrist.x - elbow.x
            let forearmDy = wrist.y - elbow.y
            let finger = frame.indexTip ?? wrist
            let rayPoint = CGPoint(x: wrist.x + forearmDx * 1.35, y: wrist.y + forearmDy * 1.35)
            let blend = frame.indexTip == nil ? 0.12 : 0.92
            let estimatedX = finger.x * blend + rayPoint.x * (1 - blend)
            let estimatedY = finger.y * blend + rayPoint.y * (1 - blend)
            firstPoint = CGPoint(x: screenFrame.minX + estimatedX * screenFrame.width,
                                 y: screenFrame.minY + estimatedY * screenFrame.height)
            confidence = Double(frame.confidence) * 0.5
        } else {
            var weightedX = 0.0
            var weightedY = 0.0
            var totalWeight = 0.0
            for sample in samples {
                let distance = zip(features, sample.features).reduce(0) { result, pair in
                    let delta = pair.0 - pair.1
                    return result + delta * delta
                }
                let weight = 1 / (0.08 + sqrt(distance))
                weightedX += sample.targetX * weight
                weightedY += sample.targetY * weight
                totalWeight += weight
            }
            let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1920, height: 1080)
            firstPoint = CGPoint(x: screenFrame.minX + weightedX / totalWeight * screenFrame.width,
                                 y: screenFrame.maxY - weightedY / totalWeight * screenFrame.height)
            confidence = min(1, Double(samples.count) / 45) * frame.confidence
        }

        history.append(firstPoint)
        if history.count > 5 { history.removeFirst() }
        let weights = history.indices.map { Double($0 + 1) }
        let totalWeight = weights.reduce(0, +)
        let smoothed = history.enumerated().reduce(CGPoint.zero) { result, item in
            result + (item.element * CGFloat(weights[item.offset] / totalWeight))
        }
        let fingerConfidence = frame.indexTip == nil ? 0.0 : 0.18
        confidence = min(1, confidence + fingerConfidence)
        let delta = smoothed - previous
        let maxStep: CGFloat = frame.indexTip == nil ? 90 : 240
        let length = hypot(delta.x, delta.y)
        let bounded = length > maxStep ? previous + delta / length * maxStep : smoothed
        previous = bounded
        return bounded
    }

    private func makeFeatures(_ frame: PoseFrame) -> [Double]? {
        guard let wrist = frame.wrist ?? frame.indexTip else { return nil }
        let shoulder = frame.leftShoulder ?? frame.rightShoulder ?? CGPoint(x: 0.5, y: 0.5)
        let elbow = frame.leftElbow ?? frame.rightElbow ?? shoulder
        let forearmDx = wrist.x - elbow.x
        let forearmDy = wrist.y - elbow.y
        let armDx = wrist.x - shoulder.x
        let armDy = wrist.y - shoulder.y
        let finger = frame.indexTip ?? wrist
        return [
            Double(wrist.x), Double(wrist.y), Double(shoulder.x), Double(shoulder.y),
            Double(elbow.x), Double(elbow.y), Double(forearmDx), Double(forearmDy),
            Double(armDx), Double(armDy), Double(finger.x), Double(finger.y),
            Double(hypot(forearmDx, forearmDy)), frame.confidence, 1
        ]
    }
}

private func +(lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
private func -(lhs: CGPoint, rhs: CGPoint) -> CGPoint { CGPoint(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
private func /(lhs: CGPoint, rhs: CGFloat) -> CGPoint { CGPoint(x: lhs.x / rhs, y: lhs.y / rhs) }
private func *(lhs: CGPoint, rhs: CGFloat) -> CGPoint { CGPoint(x: lhs.x * rhs, y: lhs.y * rhs) }
private func /(lhs: CGPoint, rhs: CGPoint) -> CGPoint { lhs }

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
