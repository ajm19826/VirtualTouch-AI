import SwiftUI
import AppKit

@main
struct VirtualTouchAIApp: App {
    @StateObject private var camera = CameraController()
    @StateObject private var controller = VirtualTouchController()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(camera)
                .environmentObject(controller)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }
        .onChange(of: controller.isTracking) { tracking in
            if tracking {
                FloatingOverlayController.shared.show(camera: camera, controller: controller)
            } else {
                FloatingOverlayController.shared.hide()
            }
        }
    }
}
