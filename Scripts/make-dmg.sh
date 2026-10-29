#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (C) 2026 FindFix contributors
#
# Builds FindFix (Release, arm64) and packages it as a styled drag-to-install DMG.
# Usage: Scripts/make-dmg.sh [output-dir]   (default: ./dist)
# Needs Xcode. Finder lays out the window, so the first run may ask to let
# Terminal control Finder.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/dist}"
# Work outside ~/Documents: iCloud adds extended attributes there that break codesign.
WORK="$(mktemp -d "${TMPDIR:-/tmp}/findfix-dmg.XXXXXX")"
trap 'hdiutil detach "$MOUNT" -quiet 2>/dev/null || true; rm -rf "$WORK"' EXIT

# The app ships the GPL text (shown from Settings › About); keep it identical.
cmp -s "$ROOT/LICENSE" "$ROOT/FindFix/Resources/LICENSE.txt" || {
    echo "FindFix/Resources/LICENSE.txt differs from LICENSE" >&2; exit 1; }

echo "▸ Building Release"
xcodebuild -project "$ROOT/FindFix.xcodeproj" -scheme FindFix -configuration Release \
    -derivedDataPath "$WORK/dd" build -quiet
APP="$WORK/dd/Build/Products/Release/FindFix.app"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' "$APP/Contents/Info.plist")"
VOLNAME="FindFix $VERSION-arm64"
DMG="$OUT/FindFix-$VERSION-arm64.dmg"
MOUNT="/Volumes/$VOLNAME"

echo "▸ Drawing background"
mkdir -p "$WORK/art"
sips -s format png -Z 256 "$APP/Contents/Resources/AppIcon.icns" --out "$WORK/art/icon.png" >/dev/null
swift "$ROOT/Scripts/make-dmg-background.swift" "$WORK/art/icon.png" "$WORK/art" >/dev/null
tiffutil -cathidpicheck "$WORK/art/background.png" "$WORK/art/background@2x.png" \
    -out "$WORK/art/background.tiff" 2>/dev/null

echo "▸ Staging"
STAGE="$WORK/stage"
mkdir -p "$STAGE/.background"
ditto "$APP" "$STAGE/FindFix.app"
ln -s /Applications "$STAGE/Applications"
cp "$WORK/art/background.tiff" "$STAGE/.background/background.tiff"

echo "▸ Laying out window"
hdiutil detach "$MOUNT" -quiet 2>/dev/null || true
hdiutil create -quiet -srcfolder "$STAGE" -volname "$VOLNAME" -fs HFS+ -format UDRW -ov "$WORK/rw.dmg"
hdiutil attach -quiet -readwrite -noverify -noautoopen "$WORK/rw.dmg"

# Window 640x420 content (bounds add the 28 pt title bar); icon centers must
# match make-dmg-background.swift.
osascript <<EOF
tell application "Finder"
    tell disk "$VOLNAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {200, 120, 840, 568}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set text size of viewOptions to 13
        set background picture of viewOptions to file ".background:background.tiff"
        set position of item "FindFix.app" of container window to {170, 200}
        set position of item "Applications" of container window to {470, 200}
        update without registering applications
        delay 1
        close
    end tell
end tell
EOF
# Volume icon last: Finder's layout pass above drops one added earlier.
cp "$APP/Contents/Resources/AppIcon.icns" "$MOUNT/.VolumeIcon.icns"
SetFile -a C "$MOUNT"
sync
hdiutil detach -quiet "$MOUNT"

echo "▸ Compressing"
mkdir -p "$OUT"
rm -f "$DMG"
hdiutil convert -quiet "$WORK/rw.dmg" -format ULFO -o "$DMG"
echo "✓ $DMG"
