import SwiftUI
import AVFoundation
import AppKit

struct LiveCameraPreview: NSViewRepresentable {
    let camera: CameraController

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.wantsLayer = true
        view.layer?.backgroundColor = NSColor.black.cgColor
        let previewLayer = camera.makePreviewLayer()
        previewLayer.frame = view.bounds
        previewLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        previewLayer.videoGravity = .resizeAspectFill
        view.layer?.addSublayer(previewLayer)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.layer?.sublayers?.forEach { $0.frame = nsView.bounds }
    }
}

final class FloatingOverlayController {
    static let shared = FloatingOverlayController()
    private var panel: NSPanel?

    func show(camera: CameraController, controller: VirtualTouchController) {
        guard panel?.isVisible != true else { return }
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1200, height: 800)
        let width: CGFloat = 360
        let height: CGFloat = 300
        let panel = NSPanel(contentRect: NSRect(x: screen.maxX - width - 12,
                                               y: screen.minY + 12,
                                               width: width,
                                               height: height),
                            styleMask: [.borderless, .resizable, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.level = .floating
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.minSize = NSSize(width: 280, height: 220)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = NSHostingView(rootView: FloatingOverlayView()
            .environmentObject(camera)
            .environmentObject(controller))
        self.panel = panel
        panel.orderFrontRegardless()
    }

    func hide() {
        panel?.orderOut(nil)
        panel = nil
    }
}

struct FloatingOverlayView: View {
    @EnvironmentObject var camera: CameraController
    @EnvironmentObject var controller: VirtualTouchController

    var body: some View {
        VStack(spacing: 6) {
            MiniScreenView()
                .environmentObject(controller)
                .frame(height: 155)
            HStack(spacing: 8) {
                LiveCameraPreview(camera: camera)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(CameraTrackingOverlay().environmentObject(camera))
                    .frame(height: 125)
                VStack(alignment: .leading, spacing: 4) {
                    Label(controller.isTracking ? "Tracking" : "Stopped",
                          systemImage: controller.isTracking ? "checkmark.circle.fill" : "stop.circle")
                        .foregroundColor(controller.isTracking ? .green : .secondary)
                    Text(String(format: "%.0f%%", controller.confidence * 100)).font(.caption.bold())
                    Text(String(format: "%.1f FPS", camera.fps)).font(.caption2)
                    Text(controller.positionGuidance)
                        .font(.caption2)
                        .lineLimit(3)
                        .foregroundColor(.orange)
                }.frame(width: 78)
                VStack(alignment: .leading, spacing: 4) {
                    Text(controller.gestureName).font(.caption.bold())
                    Text(controller.swipeName).font(.caption2)
                    Button("End Session") { controller.endSession() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                }.frame(width: 110)
            }
        }
        .padding(8)
        .background(Color(NSColor.controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct CameraTrackingOverlay: View {
    @EnvironmentObject var camera: CameraController
    var body: some View {
        GeometryReader { geometry in
            if let wrist = camera.latestFrame.wrist {
                Circle().stroke(Color.green, lineWidth: 2)
                    .frame(width: 18, height: 18)
                    .position(x: wrist.x * geometry.size.width,
                              y: (1 - wrist.y) * geometry.size.height)
            }
        }
    }
}

struct MiniScreenView: View {
    @EnvironmentObject var controller: VirtualTouchController
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.88))
                Path { path in
                    for column in 1..<4 {
                        let x = geometry.size.width * CGFloat(column) / 4
                        path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    for row in 1..<4 {
                        let y = geometry.size.height * CGFloat(row) / 4
                        path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }.stroke(Color.white.opacity(0.14), lineWidth: 1)
                Circle()
                    .fill(controller.clickDetected ? Color.red : Color.blue)
                    .frame(width: controller.clickDetected ? 18 : 12, height: controller.clickDetected ? 18 : 12)
                    .position(miniScreenPosition(in: geometry.size))
            }
        }
    }

    private func miniScreenPosition(in size: CGSize) -> CGPoint {
        let screen = NSScreen.main?.frame ?? NSRect(x: 0, y: 0, width: 1920, height: 1080)
        let normalizedX = (controller.predictedPoint.x - screen.minX) / max(screen.width, 1)
        let normalizedY = (screen.maxY - controller.predictedPoint.y) / max(screen.height, 1)
        return CGPoint(x: min(max(normalizedX, 0), 1) * size.width,
                       y: min(max(normalizedY, 0), 1) * size.height)
    }
}

extension Notification.Name {
    static let calibrationDismiss = Notification.Name("VirtualTouchAI.calibration.dismiss")
}

final class FullScreenCalibrationController {
    static let shared = FullScreenCalibrationController()
    private var window: NSWindow?

    func show(camera: CameraController, controller: VirtualTouchController) {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let window = NSWindow(contentRect: screen.frame,
                              styleMask: [.borderless],
                              backing: .buffered,
                              defer: false)
        window.isOpaque = true
        window.backgroundColor = .windowBackgroundColor
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.hasShadow = false
        window.setFrame(screen.frame, display: true)
        window.contentView = NSHostingView(rootView: FullScreenCalibrationView()
            .environmentObject(camera)
            .environmentObject(controller))
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        self.window = window

        NotificationCenter.default.addObserver(forName: .calibrationDismiss, object: nil, queue: .main) { [weak self] _ in
            window.orderOut(nil)
            self?.window = nil
        }
    }
}

struct FullScreenCalibrationView: View {
    @EnvironmentObject var camera: CameraController
    @EnvironmentObject var controller: VirtualTouchController
    @State private var dismissed = false

    var body: some View {
        ZStack {
            CalibrationWizardView(isPresented: Binding(get: { !dismissed },
                                                       set: { dismissed = !$0 }))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}
