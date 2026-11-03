# Build and Release Guide

## Environment

- macOS 11 or later for the hand-pose implementation
- Xcode with macOS SDK support
- Ruby and xcodeproj gem
- External `Other Storage` Xcode path is optional; set `DEVELOPER_DIR` for the desired installation

## Generate the Xcode Project

```sh
ruby generate_project.rb
```

## Build Release

```sh
DEVELOPER_DIR='/Volumes/Other Storage/Xcode.app/Contents/Developer' \
  xcodebuild -project VirtualTouchAI.xcodeproj \
  -scheme VirtualTouchAI \
  -configuration Release \
  clean build CODE_SIGNING_ALLOWED=NO
```

## Create DMG

```sh
./create_dmg.sh
```

Build 13 output:

```text
Release/VirtualTouch-AI-Beta-1.5.4-Build-13.dmg
```

## Before Publishing

1. Run a Debug build and a Release build.
2. Test Camera permission, Accessibility permission, and cursor movement.
3. Test pinch drag, flick click, voice click, and voice Stop.
4. Test the DMG by mounting it and verifying `Applications` is linked.
5. Verify the app displays its Build 13 corner version badge.
