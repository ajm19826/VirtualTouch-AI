# VirtualTouch AI

A native macOS virtual-touchscreen application using AVFoundation, Vision, local lightweight prediction, Core Graphics input simulation, and SwiftUI.

## Requirements

- macOS 12.0 or later
- Intel or Apple Silicon Mac
- Built-in or external webcam
- Accessibility permission for cursor and mouse control
- Camera permission for pose tracking

## Build

```sh
DEVELOPER_DIR='/Volumes/Other Storage/Xcode.app/Contents/Developer' ruby generate_project.rb
DEVELOPER_DIR='/Volumes/Other Storage/Xcode.app/Contents/Developer' xcodebuild -project VirtualTouchAI.xcodeproj -scheme VirtualTouchAI -configuration Release build
```

## Privacy

Camera frames, poses, calibration samples, and models remain on-device. The app does not use analytics or network services.

## Current implementation

- Five-frame pose and click-history estimation
- 25 FPS camera processing target
- Finger-tip priority when visible
- Arm direction and body pose fallback
- Wrist jolt, arm-extension, dwell, and voice "Click" triggers
- Bottom-right live camera and predicted-screen overlay

- Native SwiftUI window and navigation
- AVCapture camera frame processing
- Vision human body pose landmark detection
- Temporal frame and FPS reporting
- Local calibration sample storage
- Lightweight personalized nearest-feature prediction
- Cursor smoothing and bounded movement
- Multi-signal jolt detection with cooldown
- Core Graphics mouse movement and click simulation
- Accessibility and camera diagnostics
- Calibration target workflow
