import CoreGraphics
import AppKit
import Foundation

final class InputController {
    func isAccessibilityTrusted() -> Bool {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        return AXIsProcessTrustedWithOptions([promptKey: false] as CFDictionary)
    }

    func requestAccessibility() {
        let promptKey = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([promptKey: true] as CFDictionary)
    }

    func currentMousePoint() -> CGPoint {
        CGEvent(source: nil)?.location ?? CGPoint(x: NSScreen.main?.frame.midX ?? 100, y: NSScreen.main?.frame.midY ?? 100)
    }

    func move(to point: CGPoint) {
        guard isAccessibilityTrusted() else { return }
        if let event = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left) {
            event.post(tap: .cghidEventTap)
        }
    }

    func leftClick(at point: CGPoint) {
        guard isAccessibilityTrusted() else { return }
        postMouse(.leftMouseDown, .leftMouseUp, at: point, button: .left)
    }

    func doubleClick(at point: CGPoint) {
        guard isAccessibilityTrusted() else { return }
        for _ in 0..<2 { postMouse(.leftMouseDown, .leftMouseUp, at: point, button: .left) }
    }

    func rightClick(at point: CGPoint) {
        guard isAccessibilityTrusted() else { return }
        postMouse(.rightMouseDown, .rightMouseUp, at: point, button: .right)
    }

    private func postMouse(_ downType: CGEventType, _ upType: CGEventType, at point: CGPoint, button: CGMouseButton) {
        if let down = CGEvent(mouseEventSource: nil, mouseType: downType, mouseCursorPosition: point, mouseButton: button),
           let up = CGEvent(mouseEventSource: nil, mouseType: upType, mouseCursorPosition: point, mouseButton: button) {
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }

    func dragDown(at point: CGPoint) {
        guard isAccessibilityTrusted(), let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: point, mouseButton: .left) else { return }
        event.post(tap: .cghidEventTap)
    }

    func dragMove(to point: CGPoint) {
        guard isAccessibilityTrusted(), let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDragged, mouseCursorPosition: point, mouseButton: .left) else { return }
        event.post(tap: .cghidEventTap)
    }

    func dragUp(at point: CGPoint) {
        guard isAccessibilityTrusted(), let event = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: point, mouseButton: .left) else { return }
        event.post(tap: .cghidEventTap)
    }

    func scroll(vertical: Int32) {
        guard isAccessibilityTrusted(), let event = CGEvent(scrollWheelEvent2Source: nil, units: .line, wheelCount: 1, wheel1: vertical, wheel2: 0, wheel3: 0) else { return }
        event.post(tap: .cghidEventTap)
    }
}
