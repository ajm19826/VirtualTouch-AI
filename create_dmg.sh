#!/bin/zsh
set -e
PROJECT_DIR="/Volumes/Other Storage/GitHub Projects/VirtualTouch AI"
APP="$HOME/Library/Developer/Xcode/DerivedData/VirtualTouchAI-cnerafrqzbvejjblfvmswfpevffv/Build/Products/Release/VirtualTouch AI.app"
STAGING="$PROJECT_DIR/Release/DMG-Staging"
OUTPUT="$PROJECT_DIR/Release/VirtualTouch-AI-Beta-1.6.1-Build-15.dmg"

rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP" "$STAGING/"
ln -s /Applications "$STAGING/Applications"
rm -f "$OUTPUT"
hdiutil create -volname "VirtualTouch AI" -srcfolder "$STAGING" -ov -format UDZO "$OUTPUT"
echo "$OUTPUT"
