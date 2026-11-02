# VirtualTouch AI

VirtualTouch AI is a native macOS utility that uses a webcam, Apple Vision landmarks, local prediction, and Core Graphics to control the cursor with finger and arm movement.

## Download

**Current beta: Build 14 (`BETA 1.6`)**

- [Download VirtualTouch AI Build 14 DMG](Release/VirtualTouch-AI-Beta-1.6-Build-14.dmg)

Previous release: [Build 13](Release/VirtualTouch-AI-Beta-1.5.4-Build-13.dmg)

Open the DMG and drag `VirtualTouch AI.app` into `Applications`. On first launch, grant Camera and Accessibility access.

## Requirements

- macOS 12.0 or later
- Intel or Apple Silicon Mac
- Built-in or external webcam
- Camera permission
- Accessibility permission for cursor movement and clicks

Apple's hand and body pose APIs are unavailable on older macOS releases. Build 13 targets macOS 12 and later.

## Features

- Direct index-finger cursor tracking
- 35 FPS Vision hand-processing target
- Wrist, arm, and trajectory click estimation
- Flick, pinch-to-drag, swipe, dwell, and voice click/left commands
- Voice Stop command
- Full-screen nine-target calibration
- Bottom-right draggable/resizable session overlay
- End Session control
- Tutorial and diagnostics pages
- Local calibration storage; no network or telemetry

## Setup Guides

- [Installation and first launch](docs/INSTALLATION.md)
- [Camera and Accessibility setup](docs/PERMISSIONS.md)
- [Calibration guide](docs/CALIBRATION.md)
- [Gesture and click guide](docs/GESTURES.md)
- [Troubleshooting](docs/TROUBLESHOOTING.md)
- [Build and release guide](docs/BUILD.md)

## Build from Source

```sh
ruby generate_project.rb
DEVELOPER_DIR='/Volumes/Other Storage/Xcode.app/Contents/Developer' xcodebuild \
  -project VirtualTouchAI.xcodeproj \
  -scheme VirtualTouchAI \
  -configuration Release \
  build CODE_SIGNING_ALLOWED=NO
```

Package the app:

```sh
./create_dmg.sh
```

## Privacy

Camera frames, pose landmarks, calibration samples, and voice processing remain on the user's computer. The app does not upload personal data or use cloud AI services.
