import SwiftUI
import AVFoundation

struct ContentView: View {
    @EnvironmentObject var camera: CameraController
    @EnvironmentObject var controller: VirtualTouchController
    @State private var selection: SidebarItem = .dashboard
    @State private var showCalibration = false

    var body: some View {
        NavigationView {
            List {
                ForEach(SidebarItem.allCases) { item in
                    Button(action: { selection = item }) {
                        Label(item.title, systemImage: item.icon)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("VirtualTouch AI")
            .frame(minWidth: 190)

            detailView()
                .frame(minWidth: 640, minHeight: 500)
        }
        .overlay(
            Text("BETA 1.6.1 · BUILD 15")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.trailing, 12)
                .padding(.bottom, 10),
            alignment: .bottomTrailing
        )
        .onReceive(camera.$latestFrame) { frame in controller.process(frame) }
        .onAppear { camera.requestAccess() }
    }

    @ViewBuilder
    private func detailView() -> some View {
        switch selection {
        case .dashboard: DashboardView(showCalibration: $showCalibration)
        case .virtualTouch: VirtualTouchView()
        case .calibration: CalibrationView()
        case .model: ModelView()
        case .camera: CameraView()
        case .settings: SettingsView()
        case .diagnostics: DiagnosticsView()
        case .tutorial: TutorialView()
        case .about: AboutView()
        }
    }
}

enum SidebarItem: String, CaseIterable, Identifiable {
    case dashboard, virtualTouch, calibration, model, camera, settings, diagnostics, tutorial, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .dashboard: return "Dashboard"
        case .virtualTouch: return "Virtual Touch"
        case .calibration: return "Calibration"
        case .model: return "AI Model"
        case .camera: return "Camera"
        case .settings: return "Settings"
        case .diagnostics: return "Diagnostics"
        case .tutorial: return "Tutorial"
        case .about: return "About"
        }
    }
    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .virtualTouch: return "cursorarrow"
        case .calibration: return "scope"
        case .model: return "brain"
        case .camera: return "video"
        case .settings: return "gearshape"
        case .diagnostics: return "stethoscope"
        case .tutorial: return "graduationcap"
        case .about: return "info.circle"
        }
    }
}

struct DashboardView: View {
    @EnvironmentObject var camera: CameraController
    @EnvironmentObject var controller: VirtualTouchController
    @Binding var showCalibration: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("VirtualTouch AI") .font(.system(size: 28, weight: .semibold))
                StatusGrid(camera: camera, controller: controller)
                HStack(spacing: 12) {
                    Button(controller.isTracking ? "Stop VirtualTouch" : "Start VirtualTouch") {
                        controller.isTracking ? controller.stop() : controller.start()
                        camera.isRunning ? camera.stop() : camera.start()
                    }.buttonStyle(.bordered)
                    Button("Calibrate") { showCalibration = true }
                }
            }.padding(24)
        }
    }
}

struct StatusGrid: View {
    @ObservedObject var camera: CameraController
    @ObservedObject var controller: VirtualTouchController
    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 12) {
            StatusCard(title: "Camera", value: camera.status, color: camera.isRunning ? .green : .orange)
            StatusCard(title: "Tracking", value: controller.isTracking ? "Active" : "Stopped", color: controller.isTracking ? .green : .secondary)
            StatusCard(title: "Confidence", value: String(format: "%.0f%%", controller.confidence * 100), color: .blue)
            StatusCard(title: "Frame Rate", value: String(format: "%.1f FPS", camera.fps), color: .blue)
        }
    }
}

struct StatusCard: View {
    let title: String; let value: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption).foregroundColor(.secondary)
            Text(value).font(.headline).foregroundColor(color)
        }.frame(maxWidth: .infinity, minHeight: 76, alignment: .leading).padding(14)
            .background(Color(NSColor.controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct VirtualTouchView: View {
    @EnvironmentObject var camera: CameraController
    @EnvironmentObject var controller: VirtualTouchController
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Virtual Touch").font(.title2.bold())
            LiveCameraPreview(camera: camera)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(CameraTrackingOverlay().environmentObject(camera))
                .frame(height: 300)
            HStack {
                Toggle("Tracking", isOn: Binding(get: { controller.isTracking }, set: {
                    if $0 { camera.start(); controller.start() } else { controller.stop() }
                }))
                Spacer()
                Label(String(format: "%.0f%% confidence", controller.confidence * 100), systemImage: controller.clickDetected ? "hand.tap.fill" : "hand.point.up.fill")
            }
            Label(controller.positionGuidance, systemImage: "person.crop.circle.badge.questionmark")
                .font(.caption)
                .foregroundColor(.orange)
        }.padding(24)
    }
}

struct CalibrationView: View {
    @EnvironmentObject var camera: CameraController
    @EnvironmentObject var controller: VirtualTouchController
    var body: some View {
        Form {
            Section(header: Text("Profiles")) {
                Text("Default profile")
                Text(controller.calibrationStatus)
            }
            Section(header: Text("Actions")) {
                Button("Start or Recalibrate") {
                    FullScreenCalibrationController.shared.show(camera: camera, controller: controller)
                }
                    .buttonStyle(.bordered)
                Button("Reset Calibration") { controller.resetCalibration() }
                Button("Request Accessibility Permission") { controller.requestAccessibility() }
            }
        }.padding(24)
    }
}

struct CalibrationWizardView: View {
    @EnvironmentObject var camera: CameraController
    @EnvironmentObject var controller: VirtualTouchController
    @Binding var isPresented: Bool
    @State private var index = 0
    @State private var targetSamples = 0
    let targets: [(String, UnitPoint)] = [("Top left", .topLeading), ("Top center", .top), ("Top right", .topTrailing), ("Middle left", .leading), ("Center", .center), ("Middle right", .trailing), ("Bottom left", .bottomLeading), ("Bottom center", .bottom), ("Bottom right", .bottomTrailing)]
    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.08).edgesIgnoringSafeArea(.all)
            GeometryReader { geometry in
                Circle().fill(.blue).frame(width: 44, height: 44)
                    .position(x: geometry.size.width * targets[index].1.x, y: geometry.size.height * targets[index].1.y)

                MiniScreenView()
                    .environmentObject(controller)
                    .frame(width: 220, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.white.opacity(0.18), lineWidth: 1))
                    .position(
                        x: targets[index].1.x > 0.5 ? 118 : geometry.size.width - 118,
                        y: targets[index].1.y < 0.5 ? geometry.size.height - 78 : 78
                    )
            }
            VStack {
                Text("Calibrating: \(targets[index].0)").font(.headline)
                Text("Point toward the target and hold briefly.").foregroundColor(.secondary)
                Text("Samples for this target: \(targetSamples)/5").font(.caption).foregroundColor(targetSamples >= 5 ? .green : .secondary)
                Text(controller.calibrationStatus).font(.caption).foregroundColor(.secondary)
                Label(camera.latestFrame.wrist == nil ? "No usable wrist/arm landmarks" : "Arm direction detected",
                      systemImage: camera.latestFrame.wrist == nil ? "exclamationmark.triangle" : "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(camera.latestFrame.wrist == nil ? .orange : .green)
                HStack {
                    Button("Capture 5 samples") {
                        for offset in 0..<5 {
                            DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + Double(offset) * 0.12) {
                                if controller.addCalibrationSample(camera.latestFrame, target: screenPoint(in: NSScreen.main?.frame ?? .zero, unit: targets[index].1)) {
                                    targetSamples += 1
                                }
                            }
                        }
                    }
                    Button(index == targets.count - 1 ? "Finish" : "Next") {
                        guard targetSamples >= 5 else { controller.calibrationStatus = "Capture 5 valid samples for this target before continuing."; return }
                        if index == targets.count - 1 {
                            if controller.saveCalibration() {
                                isPresented = false
                                NotificationCenter.default.post(name: .calibrationDismiss, object: nil)
                            }
                        } else {
                            index += 1
                            targetSamples = 0
                        }
                    }.buttonStyle(.bordered)
                    Button("Cancel") {
                        isPresented = false
                        NotificationCenter.default.post(name: .calibrationDismiss, object: nil)
                    }
                }.padding(.top, 8)
            }.padding().frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            if !camera.isRunning { camera.start() }
        }
    }
    private func screenPoint(in frame: CGRect, unit: UnitPoint) -> CGPoint {
        CGPoint(x: frame.minX + frame.width * unit.x,
                y: frame.maxY - frame.height * unit.y)
    }
}

struct ModelView: View {
    @EnvironmentObject var controller: VirtualTouchController
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("AI Model").font(.title2.bold())
            StatusCard(title: "Active model", value: "VirtualTouch Local v1", color: .blue)
            StatusCard(title: "Training status", value: "Ready", color: .green)
            StatusCard(title: "Calibration samples", value: "\(controller.calibrationSampleCount) stored locally", color: .blue)
            Text(controller.calibrationStatus).font(.caption).foregroundColor(.secondary)
            Button("Reset and retrain") { controller.resetCalibration() }
        }.padding(24)
    }
}

struct CameraView: View {
    @EnvironmentObject var camera: CameraController
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Camera").font(.title2.bold())
            StatusCard(title: "Connection", value: camera.status, color: camera.isRunning ? .green : .orange)
            StatusCard(title: "Processing frame rate", value: String(format: "%.1f FPS", camera.fps), color: .blue)
            Button(camera.isRunning ? "Stop camera" : "Start camera") { camera.isRunning ? camera.stop() : camera.start() }
        }.padding(24)
    }
}

struct SettingsView: View {
    @EnvironmentObject var controller: VirtualTouchController
    var body: some View {
        Form {
            Slider(value: $controller.clickSensitivity, in: 0.2...0.95) { Text("Click sensitivity") }
            Slider(value: $controller.clickCooldown, in: 0.4...3) { Text("Click cooldown") }
            Slider(value: $controller.smoothing, in: 0.0...0.95) { Text("Cursor smoothing") }
            Toggle("Dwell-to-click", isOn: $controller.dwellClickEnabled)
            Toggle("Mirror camera horizontally", isOn: $controller.mirrorCameraX)
            Toggle("Say 'Click'", isOn: Binding(get: { controller.voiceClickEnabled }, set: { controller.setVoiceClick($0) }))
            Text(controller.voiceClickStatus).font(.caption).foregroundColor(.secondary)
        }.padding(24)
    }
}

struct DiagnosticsView: View {
    @EnvironmentObject var camera: CameraController
    @EnvironmentObject var controller: VirtualTouchController
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Diagnostics").font(.title2.bold())
            StatusCard(title: "Camera permission", value: camera.permissionGranted ? "Granted" : "Not granted", color: camera.permissionGranted ? .green : .orange)
            StatusCard(title: "Accessibility permission", value: controller.accessibilityTrusted ? "Granted" : "Not granted", color: controller.accessibilityTrusted ? .green : .orange)
            StatusCard(title: "Input simulation", value: controller.accessibilityTrusted ? "Available" : "Requires permission", color: controller.accessibilityTrusted ? .green : .orange)
            Text(controller.accessibilityStatus).font(.caption).foregroundColor(.secondary)
            HStack {
                Button("Request Accessibility Permission") { controller.requestAccessibility() }
                Button("Test left click") { controller.testClick() }
                Button("Test right click") { controller.rightClick() }
                Button("Test double click") { controller.doubleClick() }
                Button("Test cursor movement") { controller.testCursor() }
            }
        }.padding(24)
        .onAppear { controller.refreshAccessibilityStatus() }
    }
}

struct TutorialView: View {
    @EnvironmentObject var controller: VirtualTouchController
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("VirtualTouch Tutorial").font(.title2.bold())
                TutorialStep(number: "1", title: "Position yourself", text: "Sit facing the camera with shoulders visible. Follow the distance and height guidance.")
                TutorialStep(number: "2", title: "Calibrate", text: "Point at all nine targets across the full screen and capture five samples per target.")
                TutorialStep(number: "3", title: "Move", text: "Move your visible index fingertip or arm direction. The cursor follows finger tracking first.")
                TutorialStep(number: "4", title: "Click", text: "Use a wrist jolt, arm stop/reversal, pinch, dwell, or say Click.")
                TutorialStep(number: "5", title: "Drag and swipe", text: "Pinch and hold to drag. Move your wrist across five frames for directional swipe actions.")
                Text("Supported gestures").font(.headline)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 8) {
                    ForEach(controller.gestureCatalog, id: \.self) { gesture in
                        Text(gesture).padding(8).frame(maxWidth: .infinity).background(Color(NSColor.controlBackgroundColor)).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }.padding(24)
        }
    }
}

struct TutorialStep: View {
    let number: String
    let title: String
    let text: String
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number).font(.headline).frame(width: 30, height: 30).background(Color.accentColor).foregroundColor(.white).clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) { Text(title).font(.headline); Text(text).foregroundColor(.secondary) }
        }
    }
}

struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("VirtualTouch AI") .font(.title.bold())
            Text("Local, privacy-first virtual touchscreen for macOS").foregroundColor(.secondary)
            Text("All camera processing and calibration stay on this computer.")
        }.padding(24)
    }
}
